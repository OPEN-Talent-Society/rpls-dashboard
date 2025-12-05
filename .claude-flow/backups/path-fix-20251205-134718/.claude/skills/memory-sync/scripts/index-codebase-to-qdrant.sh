#!/bin/bash
# ====================================================
# CODEBASE INDEXER TO QDRANT
# Indexes important codebase files to Qdrant for semantic search
# ====================================================

set -e

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
  export $(grep -v '^#' "$PROJECT_ROOT/.env" | grep -v '^$' | xargs)
fi

# Configuration
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [ -z "$QDRANT_API_KEY" ]; then
    echo "Warning: QDRANT_API_KEY not set, requests may fail"
fi
QDRANT_COLLECTION="${QDRANT_COLLECTION:-agent_memory}"
GEMINI_API_KEY="${GEMINI_API_KEY}"
EMBEDDING_MODEL="text-embedding-004"
CHUNK_SIZE=1500
CHUNK_OVERLAP=200
MAX_FILE_SIZE=51200  # 50KB in bytes

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

echo -e "${BLUE}🔍 Starting Codebase Indexing to Qdrant${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check for required tools
if ! command -v jq &> /dev/null; then
  echo -e "${RED}❌ Error: jq is required but not installed${NC}"
  exit 1
fi

if ! command -v curl &> /dev/null; then
  echo -e "${RED}❌ Error: curl is required but not installed${NC}"
  exit 1
fi

# Verify Qdrant connection
echo -e "${YELLOW}🔌 Checking Qdrant connection...${NC}"
if ! curl -s -f -H "api-key: ${QDRANT_API_KEY}" "$QDRANT_URL/collections/$QDRANT_COLLECTION" > /dev/null; then
  echo -e "${RED}❌ Error: Cannot connect to Qdrant at $QDRANT_URL${NC}"
  exit 1
fi
echo -e "${GREEN}✅ Connected to Qdrant${NC}"

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
    -d "{\"content\": {\"parts\": [{\"text\": $escaped_text}]}}")

  # Extract embedding vector
  echo "$response" | jq -c '.embedding.values'
}

# Function to chunk text
chunk_text() {
  local text="$1"
  local file_path="$2"
  local language="$3"
  local symbols="$4"

  local text_length=${#text}

  # If text is small enough, return as single chunk
  if [ $text_length -le $CHUNK_SIZE ]; then
    index_chunk "$text" "$file_path" "$language" "$symbols" 0 1
    return
  fi

  # Calculate number of chunks
  local num_chunks=$(( (text_length + CHUNK_SIZE - CHUNK_OVERLAP - 1) / (CHUNK_SIZE - CHUNK_OVERLAP) ))

  echo -e "${YELLOW}  📄 Chunking into $num_chunks parts...${NC}"

  # Split into chunks with overlap
  local start=0
  local chunk_index=0

  while [ $start -lt $text_length ]; do
    local end=$((start + CHUNK_SIZE))
    if [ $end -gt $text_length ]; then
      end=$text_length
    fi

    local chunk="${text:$start:$((end - start))}"

    index_chunk "$chunk" "$file_path" "$language" "$symbols" "$chunk_index" "$num_chunks"

    chunk_index=$((chunk_index + 1))
    start=$((end - CHUNK_OVERLAP))

    # Break if we're at the end
    if [ $end -eq $text_length ]; then
      break
    fi
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

# Function to index a single chunk
index_chunk() {
  local content="$1"
  local file_path="$2"
  local language="$3"
  local symbols="$4"
  local chunk_index="$5"
  local total_chunks="$6"

  # Generate embedding
  local embedding=$(generate_embedding "$content")

  if [ -z "$embedding" ] || [ "$embedding" == "null" ]; then
    echo -e "${RED}  ❌ Failed to generate embedding${NC}"
    return 1
  fi

  # Generate deterministic point ID based on file path and chunk index
  # This ensures idempotency - running sync multiple times won't create duplicates
  local point_id=$(generate_deterministic_id "$file_path" "$chunk_index")

  # Create payload (using --argjson for numeric ID to ensure Qdrant upsert works)
  local payload=$(jq -n \
    --argjson id "$point_id" \
    --arg type "code" \
    --arg source "github" \
    --arg file_path "$file_path" \
    --arg language "$language" \
    --arg content "$content" \
    --arg symbols "$symbols" \
    --argjson chunk_index "$chunk_index" \
    --argjson total_chunks "$total_chunks" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson vector "$embedding" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          type: $type,
          source: $source,
          file_path: $file_path,
          language: $language,
          content: $content,
          symbols: $symbols,
          chunk_index: $chunk_index,
          total_chunks: $total_chunks,
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

  # Chunk and index
  if chunk_text "$content" "$rel_path" "$language" "$symbols"; then
    INDEXED_FILES=$((INDEXED_FILES + 1))
  else
    SKIPPED_FILES=$((SKIPPED_FILES + 1))
  fi
}

# Index .claude/hooks/*.sh files
echo -e "${BLUE}📂 Indexing .claude/hooks/*.sh files...${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"

# Optional: Limit to specific files for testing
TEST_MODE="${TEST_MODE:-false}"
TEST_FILES=(
  "memory-search.sh"
  "memory-store.sh"
  "log-action.sh"
)

if [ -d "$HOOKS_DIR" ]; then
  if [ "$TEST_MODE" == "true" ]; then
    echo -e "${YELLOW}🧪 TEST MODE: Indexing only selected files${NC}"
    for filename in "${TEST_FILES[@]}"; do
      file="$HOOKS_DIR/$filename"
      if [ -f "$file" ]; then
        index_file "$file"
      fi
    done
  else
    for file in "$HOOKS_DIR"/*.sh; do
      if [ -f "$file" ]; then
        index_file "$file"
      fi
    done
  fi
else
  echo -e "${RED}❌ Hooks directory not found: $HOOKS_DIR${NC}"
  exit 1
fi

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Indexing Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📊 Summary:${NC}"
echo -e "  Total files processed: $TOTAL_FILES"
echo -e "  Successfully indexed: $INDEXED_FILES"
echo -e "  Skipped: $SKIPPED_FILES"
echo -e "  Total chunks created: $TOTAL_CHUNKS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Store metrics in memory
if command -v /opt/homebrew/bin/claude-flow &> /dev/null; then
  /opt/homebrew/bin/claude-flow hooks notification \
    --message "Indexed $INDEXED_FILES files ($TOTAL_CHUNKS chunks) to Qdrant" \
    --telemetry true
fi

exit 0
