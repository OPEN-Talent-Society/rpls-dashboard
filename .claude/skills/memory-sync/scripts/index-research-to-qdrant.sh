#!/bin/bash
# Index research documents (analysis, reports, market research) to Qdrant
# Features:
#   - AI-generated summaries and tags
#   - Chunk context breadcrumbs
#   - Cross-linking to related collections
#   - Incremental indexing via manifest
#
# Usage: index-research-to-qdrant.sh [directory] [--force] [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
COLLECTION_NAME="research"

# Gemini config
GEMINI_API_KEY="${GOOGLE_GEMINI_API_KEY:-$GEMINI_API_KEY}"
EMBEDDING_MODEL="gemini-embedding-001"
GEMINI_MODEL="gemini-1.5-flash"

# Chunking config
MAX_CHUNK_SIZE=2000
CHUNK_OVERLAP=300
MAX_FILE_SIZE=2097152  # 2MB

# Manifest for incremental indexing
MANIFEST_DIR="$PROJECT_DIR/.claude/skills/memory-sync/manifests"
MANIFEST_FILE="$MANIFEST_DIR/research-index-manifest.json"
mkdir -p "$MANIFEST_DIR"

# Parse arguments
SCAN_DIR="${PROJECT_DIR}"
FORCE_REINDEX=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE_REINDEX=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) SCAN_DIR="$1"; shift ;;
    esac
done

# Initialize manifest if not exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo '{}' > "$MANIFEST_FILE"
fi
MANIFEST=$(cat "$MANIFEST_FILE")

# Counters
TOTAL_FILES=0
INDEXED_FILES=0
SKIPPED_FILES=0
TOTAL_CHUNKS=0

echo -e "${BLUE}📊 Research Document Indexer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📂 Scanning: $SCAN_DIR${NC}"
echo -e "${YELLOW}🔌 Qdrant: $QDRANT_URL/collections/$COLLECTION_NAME${NC}"
if [ "$FORCE_REINDEX" = true ]; then
    echo -e "${YELLOW}⚠️  Force mode: Re-indexing all files${NC}"
fi
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No actual indexing${NC}"
fi

# Research file patterns (focused on actual research documents)
RESEARCH_PATTERNS=(
    "*-research*.md"
    "*-RESEARCH*.md"
    "*-analysis*.md"
    "*-ANALYSIS*.md"
    "*research-*.md"
    "*RESEARCH-*.md"
    "*analysis-*.md"
    "*audience*.md"
    "*competitive*.md"
    "*market*.md"
)

# Directories to skip (expanded to exclude non-research content)
SKIP_DIRS=(
    "node_modules" ".next" ".git" "dist" "build" ".cache"
    "coverage" ".turbo" ".vercel" "__pycache__" "venv"
    "archives" "backups" "claude-backups"
    "vendor" ".github" "templates" "marketplaces"
    "plugin-bundles" "plugins" "specs-backup"
)

# Content hash for incremental indexing
compute_content_hash() {
    local file="$1"
    cat "$file" 2>/dev/null | md5 2>/dev/null || cat "$file" 2>/dev/null | md5sum | cut -d' ' -f1
}

# Check if file needs indexing
needs_indexing() {
    local file_path="$1"
    local current_hash="$2"

    if [ "$FORCE_REINDEX" = true ]; then
        return 0
    fi

    local prev_hash=$(echo "$MANIFEST" | jq -r --arg fp "$file_path" '.[$fp].hash // ""')
    if [ "$prev_hash" = "$current_hash" ]; then
        return 1
    fi
    return 0
}

# Update manifest
update_manifest() {
    local file_path="$1"
    local hash="$2"
    local chunks="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    MANIFEST=$(echo "$MANIFEST" | jq --arg fp "$file_path" --arg h "$hash" --argjson c "$chunks" --arg ts "$timestamp" \
        '.[$fp] = {hash: $h, chunks: $c, indexed_at: $ts}')
}

# Generate embedding
generate_embedding() {
    local text="$1"
    local escaped_text=$(echo -n "$text" | jq -Rs '.')

    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"models/${EMBEDDING_MODEL}\",
            \"content\": {\"parts\":[{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" 2>/dev/null)

    echo "$response" | jq -c '.embedding.values'
}

# Generate AI metadata (tags, summary, category)
generate_ai_metadata() {
    local text="$1"
    local filename="$2"

    local sample="${text:0:4000}"

    local prompt="Analyze this research document and provide:
1. A 2-3 sentence summary
2. 5-10 relevant tags (lowercase, hyphenated)
3. Category: market-research, competitive-analysis, technical-research, business-strategy, product-research, or other
4. Key entities mentioned (companies, products, people)

Document: $filename
Content:
$sample

Respond in JSON format:
{
  \"summary\": \"...\",
  \"tags\": [\"tag1\", \"tag2\"],
  \"category\": \"...\",
  \"entities\": [\"entity1\", \"entity2\"]
}"

    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"contents\": [{\"parts\":[{\"text\": $(echo -n "$prompt" | jq -Rs '.')}]}],
            \"generationConfig\": {\"temperature\": 0.2, \"maxOutputTokens\": 512}
        }" 2>/dev/null)

    local ai_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

    if [ -n "$ai_text" ]; then
        # Extract JSON from response
        echo "$ai_text" | grep -o '{[^}]*}' | head -1
    else
        echo '{"summary":"Research document","tags":["research"],"category":"other","entities":[]}'
    fi
}

# Create chunk summary for breadcrumbs
create_chunk_summary() {
    local chunk="$1"
    echo "$chunk" | head -c 100 | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//'
}

# Index a single file
index_file() {
    local file="$1"
    local rel_path="${file#$PROJECT_DIR/}"

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Check file size
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        echo -e "${YELLOW}⚠️  Skipping (too large): $rel_path${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return
    fi

    # Compute hash and check if needs indexing
    local content_hash=$(compute_content_hash "$file")
    if ! needs_indexing "$rel_path" "$content_hash"; then
        echo -e "${BLUE}⏭️  Unchanged: $rel_path${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return
    fi

    echo -e "${GREEN}📝 Processing: $rel_path${NC}"

    if [ "$DRY_RUN" = true ]; then
        return
    fi

    # Read content
    local content=$(cat "$file")
    local filename=$(basename "$file")

    # Generate AI metadata
    local ai_meta=$(generate_ai_metadata "$content" "$filename")
    local summary=$(echo "$ai_meta" | jq -r '.summary // "Research document"')
    local tags=$(echo "$ai_meta" | jq -c '.tags // ["research"]')
    local category=$(echo "$ai_meta" | jq -r '.category // "other"')
    local entities=$(echo "$ai_meta" | jq -c '.entities // []')

    # Split into chunks
    local text_length=${#content}
    local num_chunks=1
    if [ $text_length -gt $MAX_CHUNK_SIZE ]; then
        num_chunks=$(( (text_length + MAX_CHUNK_SIZE - CHUNK_OVERLAP - 1) / (MAX_CHUNK_SIZE - CHUNK_OVERLAP) ))
    fi

    # Collect chunks first for breadcrumbs
    declare -a chunks
    local start=0
    while [ $start -lt $text_length ]; do
        local end=$((start + MAX_CHUNK_SIZE))
        [ $end -gt $text_length ] && end=$text_length
        chunks+=("${content:$start:$((end - start))}")
        start=$((end - CHUNK_OVERLAP))
        [ $end -eq $text_length ] && break
    done

    # Index each chunk with breadcrumbs
    local chunk_index=0
    local total=${#chunks[@]}
    for chunk in "${chunks[@]}"; do
        local prev_summary=""
        local next_summary=""

        [ $chunk_index -gt 0 ] && prev_summary=$(create_chunk_summary "${chunks[$((chunk_index - 1))]}")
        [ $chunk_index -lt $((total - 1)) ] && next_summary=$(create_chunk_summary "${chunks[$((chunk_index + 1))]}")

        # Position context
        local position_pct=$(( (chunk_index * 100) / total ))
        local position="beginning"
        [ $position_pct -gt 75 ] && position="end"
        [ $position_pct -gt 50 ] && [ $position_pct -le 75 ] && position="latter half"
        [ $position_pct -gt 25 ] && [ $position_pct -le 50 ] && position="middle"
        [ $position_pct -gt 0 ] && [ $position_pct -le 25 ] && position="early"

        # Generate embedding
        local embedding=$(generate_embedding "$chunk")
        if [ -z "$embedding" ] || [ "$embedding" == "null" ]; then
            echo -e "${RED}  ❌ Failed to generate embedding for chunk $chunk_index${NC}"
            continue
        fi

        # Generate point ID
        local point_id=$(echo -n "${rel_path}:chunk${chunk_index}" | md5 2>/dev/null | cut -c1-8 || echo -n "${rel_path}:chunk${chunk_index}" | md5sum | cut -c1-8)
        point_id=$(printf "%lu" "0x$point_id")

        # Create payload
        local payload=$(jq -n \
            --argjson id "$point_id" \
            --arg type "research" \
            --arg file_path "$rel_path" \
            --arg filename "$filename" \
            --arg content "$chunk" \
            --arg doc_summary "$summary" \
            --argjson tags "$tags" \
            --arg category "$category" \
            --argjson entities "$entities" \
            --argjson chunk_index "$chunk_index" \
            --argjson total_chunks "$total" \
            --arg prev_chunk_summary "$prev_summary" \
            --arg next_chunk_summary "$next_summary" \
            --arg position_in_file "$position" \
            --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --argjson vector "$embedding" \
            '{
              points: [{
                id: $id,
                vector: $vector,
                payload: {
                  type: $type,
                  file_path: $file_path,
                  filename: $filename,
                  content: $content,
                  doc_summary: $doc_summary,
                  tags: $tags,
                  category: $category,
                  entities: $entities,
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
            "$QDRANT_URL/collections/$COLLECTION_NAME/points" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$payload")

        if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
            TOTAL_CHUNKS=$((TOTAL_CHUNKS + 1))
            echo -e "${GREEN}  ✅ Chunk $((chunk_index + 1))/$total${NC}"
        else
            echo -e "${RED}  ❌ Failed chunk $chunk_index: $(echo "$response" | jq -r '.status.error // "unknown"')${NC}"
        fi

        chunk_index=$((chunk_index + 1))

        # Rate limit
        sleep 0.2
    done

    INDEXED_FILES=$((INDEXED_FILES + 1))
    update_manifest "$rel_path" "$content_hash" "$total"
}

# Check Qdrant connection
echo -e "${YELLOW}🔌 Checking Qdrant connection...${NC}"
COLLECTION_CHECK=$(curl -s "${QDRANT_URL}/collections/${COLLECTION_NAME}" -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null)
if ! echo "$COLLECTION_CHECK" | jq -e '.result' > /dev/null 2>&1; then
    echo -e "${YELLOW}📦 Collection '$COLLECTION_NAME' not found, creating...${NC}"
    curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION_NAME}" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"vectors": {"size": 768, "distance": "Cosine"}, "on_disk_payload": true}' > /dev/null
fi
echo -e "${GREEN}✅ Connected to Qdrant${NC}"

# Find and index research files
echo -e "${YELLOW}🔍 Scanning for research documents...${NC}"

# Build find command with patterns
find_cmd="find \"$SCAN_DIR\" -type f \\("
first=true
for pattern in "${RESEARCH_PATTERNS[@]}"; do
    if [ "$first" = true ]; then
        find_cmd="$find_cmd -name \"$pattern\""
        first=false
    else
        find_cmd="$find_cmd -o -name \"$pattern\""
    fi
done
find_cmd="$find_cmd \\)"

# Add skip directories
for skip in "${SKIP_DIRS[@]}"; do
    find_cmd="$find_cmd -not -path \"*/$skip/*\""
done

# Execute find and process files
eval "$find_cmd" 2>/dev/null | while read -r file; do
    index_file "$file"
done

# Save manifest
echo "$MANIFEST" > "$MANIFEST_FILE"

# Summary
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}📊 Research Indexing Summary${NC}"
echo -e "  Total files found: $TOTAL_FILES"
echo -e "  Files indexed: $INDEXED_FILES"
echo -e "  Files skipped: $SKIPPED_FILES"
echo -e "  Total chunks: $TOTAL_CHUNKS"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Store in AgentDB
if [ "$DRY_RUN" != true ] && command -v npx &> /dev/null; then
    npx claude-flow agentdb pattern-store \
        --task "Index research documents to Qdrant" \
        --reward 0.9 \
        --success true \
        --message "Indexed $INDEXED_FILES research files ($TOTAL_CHUNKS chunks)" \
        2>/dev/null || true
fi

# Sync research documents to Cortex (second brain)
echo ""
echo -e "${YELLOW}📚 Syncing research to Cortex (SiYuan)...${NC}"

# Cortex config
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_API_TOKEN="${CORTEX_TOKEN}"
CF_AUTH_EMAIL="${CF_AUTH_EMAIL:-adam@aienablement.academy}"
CF_GLOBAL_KEY="${CF_GLOBAL_API_KEY}"

# Resources notebook for research documents
RESEARCH_NOTEBOOK="20251201183343-ujsixib"  # 03 Resources

sync_to_cortex() {
    local file="$1"
    local rel_path="${file#$PROJECT_DIR/}"
    local filename=$(basename "$file" .md)
    local content=$(cat "$file")

    # Generate AI metadata for tags
    local ai_meta=$(generate_ai_metadata "$content" "$filename")
    local tags=$(echo "$ai_meta" | jq -r '.tags | join(", ") // "research"')
    local category=$(echo "$ai_meta" | jq -r '.category // "research"')
    local summary=$(echo "$ai_meta" | jq -r '.summary // "Research document"')

    # Create document with YAML frontmatter for Cortex
    local md_content="---
title: \"$filename\"
type: research
category: $category
tags: [$tags]
source: \"$rel_path\"
indexed_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)
---

# $filename

> $summary

$content

---
*Source: \`$rel_path\`*
*Indexed: $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

    # Create in Cortex with proper headers
    local result=$(curl -s -X POST "${CORTEX_URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${CORTEX_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"notebook\": \"${RESEARCH_NOTEBOOK}\",
            \"path\": \"/Research/$filename\",
            \"markdown\": $(echo "$md_content" | jq -Rs .)
        }" 2>/dev/null)

    if echo "$result" | grep -q '"code":0'; then
        local doc_id=$(echo "$result" | jq -r '.data // empty')
        echo -e "${GREEN}  ✅ Cortex: $filename${NC}"

        # Set custom attributes for semantic tags
        if [ -n "$doc_id" ]; then
            curl -s -X POST "${CORTEX_URL}/api/attr/setBlockAttrs" \
                -H "Authorization: Token ${CORTEX_API_TOKEN}" \
                -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
                -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
                -H "Content-Type: application/json" \
                -d "{
                    \"id\": \"${doc_id}\",
                    \"attrs\": {
                        \"custom-semantic-tags\": \"$tags\",
                        \"custom-category\": \"$category\",
                        \"custom-source-type\": \"research\"
                    }
                }" > /dev/null 2>&1
        fi
    else
        echo -e "${YELLOW}  ⚠️  Cortex failed: $filename${NC}"
    fi
}

# Sync indexed files to Cortex
if [ "$DRY_RUN" != true ] && [ -n "$CORTEX_API_TOKEN" ]; then
    eval "$find_cmd" 2>/dev/null | head -20 | while read -r file; do
        sync_to_cortex "$file"
        sleep 0.5  # Rate limit
    done
    echo -e "${GREEN}✅ Cortex sync complete${NC}"
else
    echo -e "${YELLOW}⚠️  Cortex sync skipped (dry run or no token)${NC}"
fi

echo -e "${GREEN}✅ Research indexing complete${NC}"
