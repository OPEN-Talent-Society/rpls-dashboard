#!/bin/bash
# ====================================================
# UNIFIED CONTENT INGESTION SCRIPT
# Smart ingestion pipeline for Qdrant with automatic
# type detection, chunking, deduplication, and routing
# ====================================================

set -euo pipefail

# Script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

# Load environment variables
ENV_FILE="$PROJECT_ROOT/.env"
if [[ -f "$ENV_FILE" ]]; then
  set -a
  source "$ENV_FILE"
  set +a
fi

# Configuration
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
GEMINI_API_KEY="${GEMINI_API_KEY:-}"
EMBEDDING_MODEL="gemini-embedding-001"

# Default values
CONTENT_TYPE=""
PROJECT_NAME=""
CATEGORY=""
SOURCE_PATH=""
STDIN_MODE=false
CHECK_DUPLICATES=true
VERBOSE=false
DRY_RUN=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TOTAL_CHUNKS=0
INDEXED_CHUNKS=0
SKIPPED_CHUNKS=0

# ====================================================
# USAGE AND HELP
# ====================================================

usage() {
  cat << EOF
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${CYAN}UNIFIED CONTENT INGESTION SCRIPT${NC}
${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${YELLOW}USAGE:${NC}
  $(basename "$0") [OPTIONS] [FILE_PATH]

${YELLOW}DESCRIPTION:${NC}
  Intelligent content ingestion pipeline that:
  - Auto-detects content type (code, markdown, transcript, text)
  - Uses smart-chunker.py for boundary-aware chunking
  - Uses content-hasher.sh for deduplication
  - Routes to appropriate Qdrant collection
  - Generates embeddings via Gemini API
  - Adds rich metadata (project, category, source)

${YELLOW}OPTIONS:${NC}
  --type TYPE           Force content type (code|markdown|transcript|text)
  --project NAME        Set project name (auto-detected from directory)
  --category CAT        Set category/tag (e.g., hooks, skills, agents)
  --source SRC          Set source identifier (e.g., github, manual)
  --stdin               Read content from stdin instead of file
  --no-dedup            Skip duplicate checking
  --verbose, -v         Verbose output
  --dry-run             Show what would be indexed without uploading
  --help, -h            Show this help message

${YELLOW}EXAMPLES:${NC}
  # Ingest a single file (auto-detect type)
  $(basename "$0") /path/to/file.md

  # Force content type
  $(basename "$0") --type code /path/to/script.py

  # Set project and category
  $(basename "$0") --project campfire --category hooks file.sh

  # Stdin mode
  cat content.txt | $(basename "$0") --stdin --type text

  # Dry run to preview
  $(basename "$0") --dry-run --verbose file.md

${YELLOW}CONTENT TYPES:${NC}
  code         - Source code (Python, JavaScript, TypeScript, Bash, etc.)
  markdown     - Markdown documentation
  transcript   - Audio/video transcriptions with timestamps
  text         - Generic text content

${YELLOW}ENVIRONMENT VARIABLES:${NC}
  QDRANT_URL           - Qdrant server URL (default: https://qdrant.harbor.fyi)
  QDRANT_API_KEY       - Qdrant API key (required)
  GEMINI_API_KEY       - Google Gemini API key (required)
  QDRANT_COLLECTION    - Target collection (default: agent_memory)

${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
  exit 0
}

# ====================================================
# LOGGING FUNCTIONS
# ====================================================

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "${CYAN}[VERBOSE]${NC} $*" >&2
  fi
}

# ====================================================
# ARGUMENT PARSING
# ====================================================

while [[ $# -gt 0 ]]; do
  case $1 in
    --type)
      CONTENT_TYPE="$2"
      shift 2
      ;;
    --project)
      PROJECT_NAME="$2"
      shift 2
      ;;
    --category)
      CATEGORY="$2"
      shift 2
      ;;
    --source)
      SOURCE_PATH="$2"
      shift 2
      ;;
    --stdin)
      STDIN_MODE=true
      shift
      ;;
    --no-dedup)
      CHECK_DUPLICATES=false
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      ;;
    -*)
      log_error "Unknown option: $1"
      usage
      ;;
    *)
      SOURCE_PATH="$1"
      shift
      ;;
  esac
done

# ====================================================
# VALIDATION
# ====================================================

# Check for required tools
for tool in jq python3 curl; do
  if ! command -v "$tool" &> /dev/null; then
    log_error "Required tool not found: $tool"
    exit 1
  fi
done

# Check for required scripts
CHUNKER_SCRIPT="$SCRIPT_DIR/smart-chunker.py"
HASHER_SCRIPT="$SCRIPT_DIR/content-hasher.sh"

if [[ ! -f "$CHUNKER_SCRIPT" ]]; then
  log_error "smart-chunker.py not found at: $CHUNKER_SCRIPT"
  exit 1
fi

if [[ ! -f "$HASHER_SCRIPT" ]]; then
  log_error "content-hasher.sh not found at: $HASHER_SCRIPT"
  exit 1
fi

# Validate API keys
if [[ -z "$QDRANT_API_KEY" ]]; then
  log_error "QDRANT_API_KEY not set in .env"
  exit 1
fi

if [[ -z "$GEMINI_API_KEY" ]]; then
  log_error "GEMINI_API_KEY not set in .env"
  exit 1
fi

# Determine Qdrant collection based on content type
QDRANT_COLLECTION="${QDRANT_COLLECTION:-agent_memory}"

# ====================================================
# CONTENT LOADING
# ====================================================

CONTENT=""

if [[ "$STDIN_MODE" == "true" ]]; then
  log_verbose "Reading content from stdin..."
  CONTENT=$(cat)

  if [[ -z "$SOURCE_PATH" ]]; then
    SOURCE_PATH="stdin-$(date +%s)"
  fi
else
  if [[ -z "$SOURCE_PATH" ]]; then
    log_error "No file path provided"
    usage
  fi

  if [[ ! -f "$SOURCE_PATH" ]]; then
    log_error "File not found: $SOURCE_PATH"
    exit 1
  fi

  log_verbose "Reading content from file: $SOURCE_PATH"
  CONTENT=$(cat "$SOURCE_PATH")
fi

# Auto-detect project name from directory if not specified
if [[ -z "$PROJECT_NAME" ]]; then
  PROJECT_NAME=$(basename "$PROJECT_ROOT")
  log_verbose "Auto-detected project: $PROJECT_NAME"
fi

# Auto-detect category from file path
if [[ -z "$CATEGORY" ]] && [[ "$STDIN_MODE" == "false" ]]; then
  if [[ "$SOURCE_PATH" == *"/.claude/hooks/"* ]]; then
    CATEGORY="hooks"
  elif [[ "$SOURCE_PATH" == *"/.claude/skills/"* ]]; then
    CATEGORY="skills"
  elif [[ "$SOURCE_PATH" == *"/.claude/agents/"* ]]; then
    CATEGORY="agents"
  elif [[ "$SOURCE_PATH" == *"/.claude/commands/"* ]]; then
    CATEGORY="commands"
  else
    CATEGORY="general"
  fi
  log_verbose "Auto-detected category: $CATEGORY"
fi

# Get relative path from project root
if [[ "$STDIN_MODE" == "false" ]]; then
  REL_PATH="${SOURCE_PATH#$PROJECT_ROOT/}"
else
  REL_PATH="$SOURCE_PATH"
fi

# ====================================================
# AUTO-DETECT FILE TYPE FROM EXTENSION
# ====================================================

detect_type_from_extension() {
  local file="$1"
  local ext="${file##*.}"

  case "$ext" in
    md|markdown) echo "markdown" ;;
    py|js|ts|tsx|jsx|sh|bash|zsh|c|cpp|go|java|rb|php) echo "code" ;;
    txt|srt|vtt) echo "transcript" ;;
    *) echo "text" ;;
  esac
}

# Set content type if not explicitly provided
if [[ -z "$CONTENT_TYPE" ]] && [[ "$STDIN_MODE" == "false" ]]; then
  CONTENT_TYPE=$(detect_type_from_extension "$SOURCE_PATH")
  log_verbose "Auto-detected content type from extension: $CONTENT_TYPE"
fi

# ====================================================
# CONTENT CHUNKING
# ====================================================

log_info "Chunking content using smart-chunker.py..."

# Prepare JSON input for chunker
CHUNKER_INPUT=$(jq -n \
  --arg content "$CONTENT" \
  --arg content_type "${CONTENT_TYPE:-}" \
  --argjson metadata "$(jq -n \
    --arg project "$PROJECT_NAME" \
    --arg category "$CATEGORY" \
    --arg source "$REL_PATH" \
    '{project: $project, category: $category, source: $source}')" \
  '{content: $content, content_type: $content_type, metadata: $metadata}')

# Run chunker
CHUNKER_OUTPUT=$(echo "$CHUNKER_INPUT" | python3 "$CHUNKER_SCRIPT")

# Check chunker success
if ! echo "$CHUNKER_OUTPUT" | jq -e '.success == true' > /dev/null 2>&1; then
  log_error "Chunking failed: $(echo "$CHUNKER_OUTPUT" | jq -r '.error // "unknown error"')"
  exit 1
fi

# Extract chunks and metadata
DETECTED_TYPE=$(echo "$CHUNKER_OUTPUT" | jq -r '.content_type')
CHUNK_COUNT=$(echo "$CHUNKER_OUTPUT" | jq -r '.chunk_count')
TOTAL_CHARS=$(echo "$CHUNKER_OUTPUT" | jq -r '.total_chars')

log_success "Chunked into $CHUNK_COUNT chunks (type: $DETECTED_TYPE, chars: $TOTAL_CHARS)"

# ====================================================
# EMBEDDING AND INDEXING
# ====================================================

generate_embedding() {
  local text="$1"

  # Escape text for JSON
  local escaped_text=$(echo "$text" | jq -Rs .)

  # Call Gemini API
  local response=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/$EMBEDDING_MODEL:embedContent?key=$GEMINI_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"content\": {\"parts\": [{\"text\": $escaped_text}]}, \"outputDimensionality\": 768}")

  # Extract embedding vector
  echo "$response" | jq -c '.embedding.values'
}

generate_deterministic_id() {
  local source_path="$1"
  local chunk_index="$2"
  local key="${source_path}:chunk${chunk_index}"

  # Generate MD5 hash and convert to numeric ID
  local hash=$(echo -n "$key" | md5 2>/dev/null || echo -n "$key" | md5sum | cut -d' ' -f1)
  local hex8="${hash:0:8}"
  printf "%lu" "0x$hex8"
}

log_info "Indexing chunks to Qdrant ($QDRANT_COLLECTION)..."

# Process each chunk
echo "$CHUNKER_OUTPUT" | jq -c '.chunks[]' | while read -r chunk; do
  CHUNK_TEXT=$(echo "$chunk" | jq -r '.text')
  CHUNK_INDEX=$(echo "$chunk" | jq -r '.index')
  CHUNK_TOTAL=$(echo "$chunk" | jq -r '.total')
  CHUNK_HASH=$(echo "$chunk" | jq -r '.hash')

  log_verbose "Processing chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL (hash: ${CHUNK_HASH:0:8}...)"

  # Check for duplicates using content-hasher.sh
  if [[ "$CHECK_DUPLICATES" == "true" ]]; then
    if echo "$CHUNK_TEXT" | bash "$HASHER_SCRIPT" --check > /dev/null 2>&1; then
      log_warning "Chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL is duplicate, skipping"
      SKIPPED_CHUNKS=$((SKIPPED_CHUNKS + 1))
      continue
    fi
  fi

  # Generate embedding
  log_verbose "Generating embedding for chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL..."
  EMBEDDING=$(generate_embedding "$CHUNK_TEXT")

  if [[ -z "$EMBEDDING" ]] || [[ "$EMBEDDING" == "null" ]]; then
    log_error "Failed to generate embedding for chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL"
    SKIPPED_CHUNKS=$((SKIPPED_CHUNKS + 1))
    continue
  fi

  # Generate deterministic ID
  POINT_ID=$(generate_deterministic_id "$REL_PATH" "$CHUNK_INDEX")

  # Create Qdrant payload
  PAYLOAD=$(jq -n \
    --argjson id "$POINT_ID" \
    --arg type "$DETECTED_TYPE" \
    --arg source "ingestion" \
    --arg project "$PROJECT_NAME" \
    --arg category "$CATEGORY" \
    --arg file_path "$REL_PATH" \
    --arg content "$CHUNK_TEXT" \
    --arg content_hash "$CHUNK_HASH" \
    --argjson chunk_index "$CHUNK_INDEX" \
    --argjson total_chunks "$CHUNK_TOTAL" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson vector "$EMBEDDING" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          type: $type,
          source: $source,
          project: $project,
          category: $category,
          file_path: $file_path,
          content: $content,
          content_hash: $content_hash,
          chunk_index: $chunk_index,
          total_chunks: $total_chunks,
          indexed_at: $timestamp
        }
      }]
    }')

  # Dry run - just show what would be uploaded
  if [[ "$DRY_RUN" == "true" ]]; then
    log_info "[DRY RUN] Would upload chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL (ID: $POINT_ID)"
    if [[ "$VERBOSE" == "true" ]]; then
      echo "$PAYLOAD" | jq '.'
    fi
    INDEXED_CHUNKS=$((INDEXED_CHUNKS + 1))
    continue
  fi

  # Upload to Qdrant
  RESPONSE=$(curl -s -X PUT \
    "$QDRANT_URL/collections/$QDRANT_COLLECTION/points" \
    -H "api-key: $QDRANT_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

  if echo "$RESPONSE" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    log_success "Indexed chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL (ID: $POINT_ID)"
    INDEXED_CHUNKS=$((INDEXED_CHUNKS + 1))
  else
    log_error "Failed to index chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL: $(echo "$RESPONSE" | jq -r '.status.error // "unknown error"')"
    SKIPPED_CHUNKS=$((SKIPPED_CHUNKS + 1))
  fi

  TOTAL_CHUNKS=$((TOTAL_CHUNKS + 1))
done

# ====================================================
# SUMMARY
# ====================================================

echo ""
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_success "Ingestion Complete!"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${YELLOW}Summary:${NC}"
echo -e "  Source: $REL_PATH"
echo -e "  Type: $DETECTED_TYPE"
echo -e "  Project: $PROJECT_NAME"
echo -e "  Category: $CATEGORY"
echo -e "  Total chunks: $TOTAL_CHUNKS"
echo -e "  Indexed: $INDEXED_CHUNKS"
echo -e "  Skipped: $SKIPPED_CHUNKS"
echo -e "  Collection: $QDRANT_COLLECTION"
log_info "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0
