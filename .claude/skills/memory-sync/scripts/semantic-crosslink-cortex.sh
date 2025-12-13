#!/bin/bash
# Semantic Cross-Linking: Qdrant → Cortex
# Queries Qdrant for semantically similar documents and creates backlinks in Cortex
# Part of Phase 5: Qdrant Indexing + Feedback Loop
# Created: 2025-12-12

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure .env is loaded with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Validate credentials
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }
[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

# Config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
COLLECTION="cortex"
SIMILARITY_THRESHOLD="${SIMILARITY_THRESHOLD:-0.75}"
MAX_LINKS="${MAX_LINKS:-5}"
LIMIT="${1:-50}"  # Documents to process per run

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Semantic Cross-Linking: Qdrant → Cortex                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "Config:"
echo "  Qdrant: $QDRANT_URL (collection: $COLLECTION)"
echo "  Cortex: $CORTEX_URL"
echo "  Similarity threshold: $SIMILARITY_THRESHOLD"
echo "  Max links per doc: $MAX_LINKS"
echo "  Documents to process: $LIMIT"
echo ""

# Function to get Gemini embedding
get_embedding() {
    local text="$1"
    local escaped_text=$(echo "$text" | head -c 3000 | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

    curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/gemini-embedding-001\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('embedding',{}).get('values',[])))" 2>/dev/null
}

# Function to search Qdrant for similar documents
search_similar() {
    local vector="$1"
    local exclude_id="$2"

    curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/search" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"vector\": $vector,
            \"limit\": $((MAX_LINKS + 1)),
            \"score_threshold\": $SIMILARITY_THRESHOLD,
            \"with_payload\": true
        }"
}

# Function to add backlink in Cortex
add_backlink() {
    local source_id="$1"
    local target_id="$2"
    local target_title="$3"

    # Create a "Related" block with backlink syntax
    local link_text="Related: (($target_id '$target_title'))"

    curl -s -X POST "${CORTEX_URL}/api/block/insertBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"dataType\": \"markdown\",
            \"data\": \"$link_text\",
            \"previousID\": \"\",
            \"parentID\": \"$source_id\"
        }"
}

# Function to set semantic cross-link attribute
set_crosslink_attr() {
    local doc_id="$1"
    local related_ids="$2"  # Comma-separated list
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    curl -s -X POST "${CORTEX_URL}/api/attr/setBlockAttrs" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"$doc_id\",
            \"attrs\": {
                \"custom-semantic-links\": \"$related_ids\",
                \"custom-semantic-linked-at\": \"$timestamp\"
            }
        }"
}

# Get documents without semantic links
echo "═══════════════════════════════════════════════════════════════"
echo "Phase 1: Finding documents without semantic links"
echo "═══════════════════════════════════════════════════════════════"

DOCS=$(curl -s -X POST "${CORTEX_URL}/api/query/sql" \
    -H "Authorization: Token ${CORTEX_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "{\"stmt\": \"SELECT id, content FROM blocks WHERE type='d' AND ial NOT LIKE '%custom-semantic-links%' LIMIT $LIMIT\"}")

DOC_COUNT=$(echo "$DOCS" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" 2>/dev/null || echo "0")
echo "Found $DOC_COUNT documents to process"
echo ""

echo "═══════════════════════════════════════════════════════════════"
echo "Phase 2: Generating embeddings and finding similar documents"
echo "═══════════════════════════════════════════════════════════════"

LINKED=0
SKIPPED=0

echo "$DOCS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for doc in data.get('data', []):
    print(f\"{doc['id']}|{doc.get('content', 'Untitled')[:100]}\")
" 2>/dev/null | while IFS='|' read -r doc_id doc_title; do
    [ -z "$doc_id" ] && continue

    echo ""
    echo "Processing: $doc_title ($doc_id)"

    # Get document content for embedding
    DOC_CONTENT=$(curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$doc_id\"}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('content','')[:3000])" 2>/dev/null)

    if [ -z "$DOC_CONTENT" ] || [ "$DOC_CONTENT" = "null" ]; then
        echo "  ⚠️ No content, skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Generate embedding
    echo "  → Generating embedding..."
    VECTOR=$(get_embedding "$DOC_CONTENT")

    if [ -z "$VECTOR" ] || [ "$VECTOR" = "[]" ]; then
        echo "  ⚠️ Failed to generate embedding, skipping"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Search for similar documents in Qdrant
    echo "  → Searching Qdrant for similar docs..."
    SIMILAR=$(search_similar "$VECTOR" "$doc_id")

    # Parse results and create cross-links
    RELATED_IDS=""
    LINK_COUNT=0

    echo "$SIMILAR" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for result in data.get('result', [])[:$MAX_LINKS]:
    payload = result.get('payload', {})
    doc_id = payload.get('doc_id', '')
    title = payload.get('title', 'Untitled')[:50]
    score = result.get('score', 0)
    if doc_id:
        print(f\"{doc_id}|{title}|{score:.3f}\")
" 2>/dev/null | while IFS='|' read -r target_id target_title score; do
        [ -z "$target_id" ] && continue
        [ "$target_id" = "$doc_id" ] && continue  # Skip self

        echo "    ✓ Found: $target_title (score: $score)"

        # Add to related IDs list
        if [ -z "$RELATED_IDS" ]; then
            RELATED_IDS="$target_id"
        else
            RELATED_IDS="$RELATED_IDS,$target_id"
        fi
        LINK_COUNT=$((LINK_COUNT + 1))
    done

    # Set semantic link attribute
    if [ -n "$RELATED_IDS" ]; then
        echo "  → Setting semantic-links attribute ($LINK_COUNT links)"
        set_crosslink_attr "$doc_id" "$RELATED_IDS"
        LINKED=$((LINKED + 1))
    else
        echo "  → No similar documents found above threshold"
    fi

    # Rate limit
    sleep 0.5
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Summary"
echo "═══════════════════════════════════════════════════════════════"
echo "Documents processed: $DOC_COUNT"
echo "Successfully linked: $LINKED"
echo "Skipped (no content/embedding): $SKIPPED"
echo ""
echo "To run on more documents: $0 100"
echo "To adjust threshold: SIMILARITY_THRESHOLD=0.8 $0"
