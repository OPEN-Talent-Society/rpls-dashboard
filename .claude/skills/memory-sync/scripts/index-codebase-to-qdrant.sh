#!/bin/bash
# ====================================================
# CODEBASE INDEXER TO QDRANT
# Indexes important codebase files to Qdrant for semantic search
# Supports incremental indexing - only processes changed files
# ====================================================

set -e

# Parse command line arguments
PROJECT=""
FORCE_REINDEX=false
CLEANUP_DELETED=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --force)
      FORCE_REINDEX=true
      shift
      ;;
    --cleanup)
      CLEANUP_DELETED=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--project PROJECT_NAME] [--force] [--cleanup]"
      echo "  --force    Force re-index all files (ignore manifest)"
      echo "  --cleanup  Remove points for deleted/renamed files"
      exit 1
      ;;
  esac
done

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  export $(grep -v '^#' "$PROJECT_ROOT/.env" | grep -v '^$' | xargs)
fi

# Auto-detect project name from directory if not specified
if [ -z "$PROJECT" ]; then
  PROJECT=$(basename "$PROJECT_ROOT")
fi

# Configuration
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [ -z "$QDRANT_API_KEY" ]; then
    echo "Warning: QDRANT_API_KEY not set, requests may fail"
fi
# IMPORTANT: Always use "codebase" collection - dont rely on env var
QDRANT_COLLECTION="codebase"
GEMINI_API_KEY="${GEMINI_API_KEY}"
EMBEDDING_MODEL="gemini-embedding-001"
CHUNK_SIZE=1500
CHUNK_OVERLAP=200
MAX_FILE_SIZE=524288  # 512KB - chunking handles large files, so be generous

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_FILES=0
INDEXED_FILES=0
TOTAL_CHUNKS=0
SKIPPED_FILES=0
UNCHANGED_FILES=0
DELETED_FILES=0

# Manifest file for tracking indexed files
MANIFEST_DIR="$PROJECT_ROOT/.claude/skills/memory-sync/manifests"
mkdir -p "$MANIFEST_DIR"
MANIFEST_FILE="$MANIFEST_DIR/codebase-index-manifest.json"

# Initialize manifest if it doesn't exist
if [ ! -f "$MANIFEST_FILE" ]; then
  echo '{}' > "$MANIFEST_FILE"
fi

# Load existing manifest
MANIFEST=$(cat "$MANIFEST_FILE")

# Temporary file for tracking current run's files
CURRENT_RUN_FILES=$(mktemp)
trap "rm -f $CURRENT_RUN_FILES" EXIT

# Function to compute content hash (TRUE content-based, not mtime-based)
# This ensures files only reindex when ACTUAL CONTENT changes, not when touched
compute_file_hash() {
  local file="$1"
  local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)

  # For small files (<50KB), hash entire content for accuracy
  # For larger files, use sampling for speed: first 4KB + middle 4KB + last 4KB + size
  if [ "$size" -lt 51200 ]; then
    # Small file: hash entire content
    local hash=$(cat "$file" 2>/dev/null | md5 2>/dev/null || cat "$file" 2>/dev/null | md5sum | cut -d' ' -f1)
  else
    # Large file: sample-based hash (12KB sample + size for uniqueness)
    local first=$(head -c 4096 "$file" 2>/dev/null | base64)
    local last=$(tail -c 4096 "$file" 2>/dev/null | base64)
    # Middle: skip to 50% and read 4KB
    local mid_offset=$((size / 2))
    local middle=$(dd if="$file" bs=1 skip=$mid_offset count=4096 2>/dev/null | base64)
    local hash=$(echo -n "${size}:${first}:${middle}:${last}" | md5 2>/dev/null || echo -n "${size}:${first}:${middle}:${last}" | md5sum | cut -d' ' -f1)
  fi
  echo "$hash"
}

# Function to check if file needs indexing
needs_indexing() {
  local file_path="$1"
  local current_hash="$2"

  if [ "$FORCE_REINDEX" = true ]; then
    return 0  # Force re-index
  fi

  # Check manifest for previous hash
  local prev_hash=$(echo "$MANIFEST" | jq -r --arg fp "$file_path" '.[$fp].hash // ""')

  if [ "$prev_hash" = "$current_hash" ]; then
    return 1  # No change, skip
  fi

  return 0  # Changed or new, needs indexing
}

# Function to update manifest entry
update_manifest_entry() {
  local file_path="$1"
  local hash="$2"
  local chunks="$3"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  MANIFEST=$(echo "$MANIFEST" | jq --arg fp "$file_path" --arg h "$hash" --argjson c "$chunks" --arg ts "$timestamp" \
    '.[$fp] = {hash: $h, chunks: $c, indexed_at: $ts}')
}

# Function to save manifest
save_manifest() {
  echo "$MANIFEST" > "$MANIFEST_FILE"
}

echo -e "${BLUE}🔍 Starting Codebase Indexing to Qdrant${NC}"
if [ "$FORCE_REINDEX" = true ]; then
  echo -e "${YELLOW}⚠️  Force mode: Re-indexing all files${NC}"
fi
if [ "$CLEANUP_DELETED" = true ]; then
  echo -e "${YELLOW}🧹 Cleanup mode: Will remove deleted file points${NC}"
fi
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📦 Project: $PROJECT${NC}"

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo -e "${RED}❌ Error: jq is required but not installed${NC}"
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo -e "${RED}❌ Error: curl is required but not installed${NC}"
  exit 1
fi

# Verify Qdrant connection and check for collection reset
echo -e "${YELLOW}🔌 Checking Qdrant connection...${NC}"
COLLECTION_INFO=$(curl -s -H "api-key: ${QDRANT_API_KEY}" "$QDRANT_URL/collections/$QDRANT_COLLECTION" 2>/dev/null)
if ! echo "$COLLECTION_INFO" | jq -e '.result' > /dev/null 2>&1; then
  echo -e "${RED}❌ Error: Cannot connect to Qdrant at $QDRANT_URL${NC}"
  exit 1
fi
QDRANT_POINT_COUNT=$(echo "$COLLECTION_INFO" | jq -r '.result.points_count // 0')
MANIFEST_ENTRY_COUNT=$(echo "$MANIFEST" | jq 'length')

# Detect if collection was reset (manifest has entries but collection is empty/small)
if [ "$MANIFEST_ENTRY_COUNT" -gt 100 ] && [ "$QDRANT_POINT_COUNT" -lt 50 ]; then
  echo -e "${RED}⚠️  WARNING: Collection appears to have been reset!${NC}"
  echo -e "${RED}   Manifest has $MANIFEST_ENTRY_COUNT files tracked${NC}"
  echo -e "${RED}   But Qdrant only has $QDRANT_POINT_COUNT points${NC}"
  echo -e "${YELLOW}   Options:${NC}"
  echo -e "${YELLOW}   1. Run with --force to reindex everything${NC}"
  echo -e "${YELLOW}   2. Delete manifest: rm $MANIFEST_FILE${NC}"
  echo -e "${YELLOW}   Continuing will only index NEW files not in manifest...${NC}"
  echo ""
  read -t 5 -p "Continue anyway? [y/N] " -n 1 -r REPLY || REPLY="y"
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}Aborted. Fix manifest/collection sync first.${NC}"
    exit 1
  fi
fi
echo -e "${GREEN}✅ Connected to Qdrant ($QDRANT_POINT_COUNT points in collection)${NC}"

# Function to detect language from file extension
detect_language() {
  local file="$1"
  local ext="${file##*.}"

  case "$ext" in
    sh) echo "bash" ;;
    js) echo "javascript" ;;
    ts) echo "typescript" ;;
    py) echo "python" ;;
    md) echo "markdown" ;;
    json) echo "json" ;;
    yaml|yml) echo "yaml" ;;
    *) echo "text" ;;
  esac
}

# Function to extract function/class names from code
extract_symbols() {
  local file="$1"
  local lang="$2"
  local symbols=""

  case "$lang" in
    bash)
      # Extract function names from bash scripts
      symbols=$(grep -oP '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' "$file" 2>/dev/null | sed 's/\s*()//g' | tr '\n' ',' | sed 's/,$//' || echo "")
      ;;
    javascript|typescript)
      # Extract function/class names from JS/TS
      symbols=$(grep -oP '(function\s+[a-zA-Z_][a-zA-Z0-9_]*|class\s+[a-zA-Z_][a-zA-Z0-9_]*|const\s+[a-zA-Z_][a-zA-Z0-9_]*\s*=\s*\()' "$file" 2>/dev/null | sed 's/function\s*//; s/class\s*//; s/const\s*//; s/\s*=\s*($//' | tr '\n' ',' | sed 's/,$//' || echo "")
      ;;
  esac

  echo "$symbols"
}

# Function to generate Gemini embedding
generate_embedding() {
  local text="$1"

  # Escape text for JSON
  local escaped_text=$(echo "$text" | jq -Rs .)

  # Call Gemini API
  local response=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/$EMBEDDING_MODEL:embedContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/$EMBEDDING_MODEL\", \"content\": {\"parts\": [{\"text\": $escaped_text}]}, \"outputDimensionality\": 768}")

  # Extract embedding vector
  echo "$response" | jq -c '.embedding.values'
}

# Function to create chunk summary for breadcrumbs (first 80 chars)
create_chunk_summary() {
  local chunk="$1"
  # Take first 80 chars, replace newlines with spaces, trim
  echo "$chunk" | head -c 80 | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//'
}

# Function to chunk text with context breadcrumbs
# Each chunk knows about its neighbors for navigation and bigger-picture context
chunk_text() {
  local text="$1"
  local file_path="$2"
  local language="$3"
  local symbols="$4"

  local text_length=${#text}

  # If text is small enough, return as single chunk with no breadcrumbs
  if [ $text_length -le $CHUNK_SIZE ]; then
    index_chunk "$text" "$file_path" "$language" "$symbols" 0 1 "" ""
    return
  fi

  # Calculate number of chunks
  local num_chunks=$(( (text_length + CHUNK_SIZE - CHUNK_OVERLAP - 1) / (CHUNK_SIZE - CHUNK_OVERLAP) ))

  echo -e "${YELLOW}  📄 Chunking into $num_chunks parts with breadcrumbs...${NC}"

  # First pass: collect all chunks
  declare -a chunks
  local start=0
  while [ $start -lt $text_length ]; do
    local end=$((start + CHUNK_SIZE))
    if [ $end -gt $text_length ]; then
      end=$text_length
    fi
    chunks+=("${text:$start:$((end - start))}")
    start=$((end - CHUNK_OVERLAP))
    if [ $end -eq $text_length ]; then
      break
    fi
  done

  # Second pass: index each chunk with prev/next breadcrumbs
  local chunk_index=0
  local total=${#chunks[@]}
  for chunk in "${chunks[@]}"; do
    local prev_summary=""
    local next_summary=""

    # Get previous chunk summary (if not first)
    if [ $chunk_index -gt 0 ]; then
      prev_summary=$(create_chunk_summary "${chunks[$((chunk_index - 1))]}")
    fi

    # Get next chunk summary (if not last)
    if [ $chunk_index -lt $((total - 1)) ]; then
      next_summary=$(create_chunk_summary "${chunks[$((chunk_index + 1))]}")
    fi

    index_chunk "$chunk" "$file_path" "$language" "$symbols" "$chunk_index" "$total" "$prev_summary" "$next_summary"
    chunk_index=$((chunk_index + 1))
  done
}

# Function to generate deterministic ID from file path and chunk index
# This ensures idempotency - same file/chunk always gets same ID
# Using MD5 hash of filepath+chunk to create reproducible numeric ID
generate_deterministic_id() {
  local file_path="$1"
  local chunk_index="$2"
  local key="${file_path}:chunk${chunk_index}"

  # Generate MD5 hash and take first 8 hex chars (32 bits = always positive in unsigned)
  local hash=$(echo -n "$key" | md5 2>/dev/null || echo -n "$key" | md5sum | cut -d' ' -f1)
  local hex8="${hash:0:8}"
  # Convert to decimal - 8 hex chars = max 4294967295, always positive
  printf "%lu" "0x$hex8"
}

# Function to index a single chunk with breadcrumb context
index_chunk() {
  local content="$1"
  local file_path="$2"
  local language="$3"
  local symbols="$4"
  local chunk_index="$5"
  local total_chunks="$6"
  local prev_summary="${7:-}"  # Breadcrumb: what came before
  local next_summary="${8:-}"  # Breadcrumb: what comes after

  # Generate embedding
  local embedding=$(generate_embedding "$content")

  if [ -z "$embedding" ] || [ "$embedding" == "null" ]; then
    echo -e "${RED}  ❌ Failed to generate embedding${NC}"
    return 1
  fi

  # Generate deterministic point ID based on file path and chunk index
  # This ensures idempotency - running sync multiple times won't create duplicates
  local point_id=$(generate_deterministic_id "$file_path" "$chunk_index")

  # Calculate chunk position context for "bigger picture"
  local position_pct=$(( (chunk_index * 100) / total_chunks ))
  local position_desc="beginning"
  if [ $position_pct -gt 75 ]; then
    position_desc="end"
  elif [ $position_pct -gt 50 ]; then
    position_desc="latter half"
  elif [ $position_pct -gt 25 ]; then
    position_desc="middle"
  elif [ $position_pct -gt 0 ]; then
    position_desc="early"
  fi

  # Create payload with breadcrumbs for context-aware retrieval
  local payload=$(jq -n \
    --argjson id "$point_id" \
    --arg type "code" \
    --arg source "github" \
    --arg project "$PROJECT" \
    --arg file_path "$file_path" \
    --arg language "$language" \
    --arg content "$content" \
    --arg symbols "$symbols" \
    --argjson chunk_index "$chunk_index" \
    --argjson total_chunks "$total_chunks" \
    --arg prev_chunk_summary "$prev_summary" \
    --arg next_chunk_summary "$next_summary" \
    --arg position_in_file "$position_desc" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson vector "$embedding" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          type: $type,
          source: $source,
          project: $project,
          file_path: $file_path,
          language: $language,
          content: $content,
          symbols: $symbols,
          chunk_index: $chunk_index,
          total_chunks: $total_chunks,
          prev_chunk_summary: $prev_chunk_summary,
          next_chunk_summary: $next_chunk_summary,
          position_in_file: $position_in_file,
          indexed_at: $timestamp
        }
      }]
    }')

  # Upload to Qdrant
  local response=$(curl -s -X PUT \
    "$QDRANT_URL/collections/$QDRANT_COLLECTION/points" \
    -H "api-key: ${QDRANT_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    TOTAL_CHUNKS=$((TOTAL_CHUNKS + 1))
    echo -e "${GREEN}  ✅ Indexed chunk $((chunk_index + 1))/$total_chunks${NC}"
    return 0
  else
    echo -e "${RED}  ❌ Failed to index chunk: $(echo "$response" | jq -r '.status.error // "unknown error"')${NC}"
    return 1
  fi
}

# Function to index a single file
index_file() {
  local file="$1"

  TOTAL_FILES=$((TOTAL_FILES + 1))

  # Get relative path from project root
  local rel_path="${file#$PROJECT_ROOT/}"

  # Track this file for cleanup phase
  echo "$rel_path" >> "$CURRENT_RUN_FILES"

  # Compute content hash for incremental check
  local content_hash=$(compute_file_hash "$file")

  # Check if file needs indexing
  if ! needs_indexing "$rel_path" "$content_hash"; then
    UNCHANGED_FILES=$((UNCHANGED_FILES + 1))
    return 0
  fi

  echo -e "${BLUE}📝 Processing: $rel_path${NC}"

  # Check file size
  local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
  if [ "$file_size" -gt "$MAX_FILE_SIZE" ]; then
    echo -e "${YELLOW}  ⚠️  Skipped (file too large: $file_size bytes)${NC}"
    SKIPPED_FILES=$((SKIPPED_FILES + 1))
    return
  fi

  # Read file content
  local content=$(cat "$file")

  # Detect language
  local language=$(detect_language "$file")

  # Extract symbols
  local symbols=$(extract_symbols "$file" "$language")

  # Track chunks for this file
  local file_chunks_before=$TOTAL_CHUNKS

  # Chunk and index
  if chunk_text "$content" "$rel_path" "$language" "$symbols"; then
    INDEXED_FILES=$((INDEXED_FILES + 1))
    local file_chunks=$((TOTAL_CHUNKS - file_chunks_before))
    # Update manifest with new hash
    update_manifest_entry "$rel_path" "$content_hash" "$file_chunks"
  else
    SKIPPED_FILES=$((SKIPPED_FILES + 1))
  fi
}

# ==============================================
# MULTI-PROJECT CODEBASE INDEXING
# Scans all project subfolders in codebuild
# ==============================================

# Define which projects to index (actual coding projects)
PROJECTS=(
  "ai-enablement-academy-v2"
  "project-campfire"
  "rpls-dashboard"
  "taylormade"
  "ttf-web"
  "ttf-web-nextjs"
  "claude-flow"
  "infrastructure-ops"
  "mcp-servers"
  "frontend"
  "backend"
  "claude-zai"
  "claude-zai-flow"
  "claude-zai-agent-flow"
  "codex-sandbox"
  "codex-subagents-mcp"
  "openskills"
  "opentalent-skills-app"
  "universal-agents"
  "universal-skills"
  "skills-to-agents"
  "enablement-academy-face"
  "labor-market-pulse"
)

# File patterns to index (common source code extensions)
FILE_PATTERNS=(
  "*.ts"
  "*.tsx"
  "*.js"
  "*.jsx"
  "*.py"
  "*.sh"
  "*.md"
  "*.json"
  "*.yaml"
  "*.yml"
)

# INCLUSIVE APPROACH: Index EVERYTHING except known bad directories
# This catches specs, docs, architecture, and any custom directories

# Directories to SKIP (build artifacts, dependencies, caches)
SKIP_DIRS=(
  "node_modules"
  ".next"
  ".svelte-kit"
  "dist"
  "build"
  ".git"
  ".cache"
  "__pycache__"
  ".pytest_cache"
  "coverage"
  ".turbo"
  ".vercel"
  ".do"
  ".husky"
  ".vscode"
  ".idea"
  "vendor"
  "venv"
  ".venv"
  "env"
  ".env"
  "logs"
  "tmp"
  ".tmp"
  "temp"
  ".temp"
  "out"
  ".out"
  ".nyc_output"
  ".parcel-cache"
  ".webpack"
  ".rollup.cache"
  ".esbuild"
  "storybook-static"
  ".storybook"
  ".docusaurus"
  "public/build"
  ".expo"
  ".gradle"
  "Pods"
  "ios/Pods"
  "android/build"
  ".dart_tool"
  ".pub-cache"
)

# Function to check if a path should be skipped
should_skip() {
  local path="$1"
  for skip in "${SKIP_DIRS[@]}"; do
    if [[ "$path" == *"/$skip/"* ]] || [[ "$path" == *"/$skip" ]]; then
      return 0  # true, should skip
    fi
  done
  return 1  # false, don't skip
}

echo -e "${BLUE}📂 Indexing Project Codebases...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Projects to index: ${#PROJECTS[@]}${NC}"
echo ""

# If specific project specified, only index that one
if [ -n "$PROJECT" ] && [ "$PROJECT" != "codebuild" ]; then
  echo -e "${YELLOW}📦 Indexing single project: $PROJECT${NC}"
  PROJECTS=("$PROJECT")
fi

# Track per-project stats (simple approach for bash 3.x compatibility)
PROJECT_STATS_LOG="/tmp/codebase-index-stats.log"
echo "" > "$PROJECT_STATS_LOG"

for project in "${PROJECTS[@]}"; do
  PROJECT_DIR="$PROJECT_ROOT/$project"

  if [ ! -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}⚠️  Project not found: $project${NC}"
    continue
  fi

  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}📦 Project: $project${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  PROJECT_FILES=0

  # INCLUSIVE APPROACH: Scan entire project, skip only bad directories
  # This catches: src/, lib/, docs/, specs/, architecture/, and ANY custom directory
  echo -e "${YELLOW}📁 Scanning entire project (excluding build artifacts)...${NC}"

  for pattern in "${FILE_PATTERNS[@]}"; do
    while IFS= read -r -d '' file; do
      # Skip if in excluded directory
      if should_skip "$file"; then
        continue
      fi

      # Skip lock files, binaries, and other noise
      filename=$(basename "$file")
      case "$filename" in
        # Lock files
        package-lock.json|pnpm-lock.yaml|yarn.lock|composer.lock|Gemfile.lock|Pipfile.lock)
          continue
          ;;
        # Minified/bundled
        *.min.js|*.min.css|*.bundle.js|*.chunk.js)
          continue
          ;;
        # Binary/media files (these need specialized processing, not text embedding)
        *.pdf|*.doc|*.docx|*.xls|*.xlsx|*.ppt|*.pptx)
          continue
          ;;
        *.mp3|*.mp4|*.wav|*.ogg|*.flac|*.aac|*.m4a)
          continue
          ;;
        *.mov|*.avi|*.mkv|*.webm|*.wmv|*.flv)
          continue
          ;;
        *.png|*.jpg|*.jpeg|*.gif|*.webp|*.svg|*.ico|*.bmp|*.tiff)
          continue
          ;;
        *.zip|*.tar|*.gz|*.rar|*.7z|*.bz2)
          continue
          ;;
        *.exe|*.dll|*.so|*.dylib|*.bin|*.dat)
          continue
          ;;
        *.woff|*.woff2|*.ttf|*.otf|*.eot)
          continue
          ;;
        *.sqlite|*.db|*.db-shm|*.db-wal)
          continue
          ;;
      esac

      # Update PROJECT variable for metadata
      PROJECT="$project"
      index_file "$file"
      PROJECT_FILES=$((PROJECT_FILES + 1))

      # Rate limit to avoid API throttling
      sleep 0.2

    done < <(find "$PROJECT_DIR" -name "$pattern" -type f -print0 2>/dev/null)
  done

  echo "$project: $PROJECT_FILES" >> "$PROJECT_STATS_LOG"
  echo -e "${GREEN}✅ $project: $PROJECT_FILES files processed${NC}"
done

# Also index .claude/ directory (hooks, skills, commands, agents)
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📦 Claude Configuration (.claude/)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

for subdir in hooks skills commands agents; do
  CLAUDE_SUBDIR="$PROJECT_ROOT/.claude/$subdir"
  if [ -d "$CLAUDE_SUBDIR" ]; then
    echo -e "${YELLOW}📁 Scanning .claude/$subdir/...${NC}"

    while IFS= read -r -d '' file; do
      PROJECT="codebuild-claude"
      index_file "$file"
      sleep 0.2
    done < <(find "$CLAUDE_SUBDIR" -type f \( -name "*.sh" -o -name "*.md" -o -name "*.py" -o -name "*.js" -o -name "*.ts" \) -print0 2>/dev/null)
  fi
done

# ==============================================
# CLEANUP PHASE - Remove deleted files from Qdrant
# ==============================================
if [ "$CLEANUP_DELETED" = true ]; then
  echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}🧹 Cleanup Phase: Removing deleted files${NC}"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Get list of files in manifest that weren't seen this run
  for manifest_file in $(echo "$MANIFEST" | jq -r 'keys[]'); do
    if ! grep -qxF "$manifest_file" "$CURRENT_RUN_FILES"; then
      echo -e "${YELLOW}  🗑️  Removing: $manifest_file${NC}"

      # Get number of chunks for this file
      num_chunks=$(echo "$MANIFEST" | jq -r --arg fp "$manifest_file" '.[$fp].chunks // 1')

      # Delete each chunk's point from Qdrant
      for ((i=0; i<num_chunks; i++)); do
        point_id=$(generate_deterministic_id "$manifest_file" "$i")
        curl -s -X POST "$QDRANT_URL/collections/$QDRANT_COLLECTION/points/delete" \
          -H "api-key: ${QDRANT_API_KEY}" \
          -H "Content-Type: application/json" \
          -d "{\"points\": [$point_id]}" > /dev/null
      done

      # Remove from manifest
      MANIFEST=$(echo "$MANIFEST" | jq --arg fp "$manifest_file" 'del(.[$fp])')
      DELETED_FILES=$((DELETED_FILES + 1))
    fi
  done

  if [ $DELETED_FILES -eq 0 ]; then
    echo -e "${GREEN}  ✅ No deleted files to clean up${NC}"
  else
    echo -e "${GREEN}  ✅ Removed $DELETED_FILES deleted files${NC}"
  fi
fi

# Save updated manifest
save_manifest
echo -e "${GREEN}💾 Manifest saved to: $MANIFEST_FILE${NC}"

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Indexing Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📊 Summary:${NC}"
echo -e "  Total files scanned: $TOTAL_FILES"
echo -e "  Unchanged (skipped): $UNCHANGED_FILES"
echo -e "  Newly indexed: $INDEXED_FILES"
echo -e "  Skipped (errors): $SKIPPED_FILES"
echo -e "  Deleted files cleaned: $DELETED_FILES"
echo -e "  Total chunks created: $TOTAL_CHUNKS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Store metrics in memory
if command -v /opt/homebrew/bin/claude-flow &> /dev/null; then
  /opt/homebrew/bin/claude-flow hooks notification \
    --message "Indexed $INDEXED_FILES files ($TOTAL_CHUNKS chunks) to Qdrant, skipped $UNCHANGED_FILES unchanged" \
    --telemetry true
fi

exit 0
