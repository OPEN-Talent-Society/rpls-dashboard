#!/bin/bash
# Sync Cortex (SiYuan) knowledge base to Qdrant for semantic search
# Indexes documents from all notebooks with embeddings
# Created: 2025-12-03

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SMART_CHUNKER="$PROJECT_DIR/.claude/skills/memory-sync/scripts/smart-chunker.py"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure .env is loaded with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }

# Cortex (SiYuan) config - CF Service Token auth (most reliable)
# Uses Cloudflare Access Service Token for zero-trust authentication
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
[ -z "$CF_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_TOKEN="${CORTEX_TOKEN}"
[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="cortex"  # Changed from agent_memory - Cortex content goes to cortex collection

# Sync state
SYNC_STATE_FILE="/tmp/cortex-qdrant-sync-state.json"

# Check mode
INCREMENTAL=false
LIMIT=0
if [ "$1" = "--incremental" ]; then
    INCREMENTAL=true
fi
if [ "$1" = "--limit" ] && [ -n "$2" ]; then
    LIMIT=$2
fi

echo "🔄 Syncing Cortex → Qdrant"
echo "   Cortex: $CORTEX_URL"
echo "   Collection: $COLLECTION"
echo "   Mode: $([ "$INCREMENTAL" = true ] && echo 'incremental' || echo 'full')"
[ "$LIMIT" -gt 0 ] && echo "   Limit: $LIMIT documents"

# Get last sync timestamp for incremental
LAST_SYNC="1970-01-01T00:00:00Z"
if [ "$INCREMENTAL" = true ] && [ -f "$SYNC_STATE_FILE" ]; then
    LAST_SYNC=$(python3 -c "import json; print(json.load(open('$SYNC_STATE_FILE')).get('last_sync', '1970-01-01T00:00:00Z'))" 2>/dev/null || echo "1970-01-01T00:00:00Z")
fi

# Function to get Gemini embedding
get_embedding() {
    local text="$1"
    # Truncate to 5000 chars and escape for JSON
    local escaped_text=$(echo "$text" | head -c 5000 | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

    local response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/gemini-embedding-001\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }")

    echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('embedding',{}).get('values',[])))" 2>/dev/null
}

# Function to upsert to Qdrant
upsert_to_qdrant() {
    local id="$1"
    local vector="$2"
    local payload="$3"

    # Convert string ID to numeric hash
    local numeric_id=$(echo -n "$id" | md5 | cut -c1-8)
    numeric_id=$((16#$numeric_id % 2147483647))

    curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $numeric_id,
                \"vector\": $vector,
                \"payload\": $payload
            }]
        }" > /dev/null
}

# Function to check if document already exists in Qdrant
doc_exists_in_qdrant() {
    local doc_id="$1"
    local numeric_id=$(echo -n "cortex-$doc_id" | md5 | cut -c1-8)
    numeric_id=$((16#$numeric_id % 2147483647))

    local result=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"ids\": [$numeric_id]}" 2>/dev/null)

    if echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('result',[]) else 1)" 2>/dev/null; then
        return 0  # Exists
    fi
    return 1  # Doesn't exist
}

# Notebooks to sync (PARA methodology) - with category tags
# Format: notebook_id:notebook_name:category_tag
NOTEBOOKS=(
    "20251103053911-8ex6uns:Projects:project"
    "20251201183343-543piyt:Areas:area"
    "20251201183343-ujsixib:Resources:resource"
    "20251201183343-xf2snc8:Archives:archive"
    "20251103053840-moamndp:Knowledge Base:kb"
    "20251103053916-bq6qbgu:Agents:agent"
)

INDEXED=0
SKIPPED=0

for NB_ENTRY in "${NOTEBOOKS[@]}"; do
    IFS=':' read -r NB_ID NB_NAME NB_CATEGORY <<< "$NB_ENTRY"

    echo ""
    echo "📚 Processing: $NB_NAME (category: $NB_CATEGORY)"

    # Get documents with metadata using SQL query (includes custom-category in ial)
    # This is more reliable than listDocsByPath and includes IAL attributes
    DOCS=$(curl -s -X POST "${CORTEX_URL}/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT id, content, ial FROM blocks WHERE type='d' AND box='${NB_ID}' AND ial LIKE '%custom-category%'\"}" 2>/dev/null)

    # Extract document IDs with their IAL metadata
    DOC_IDS=$(echo "$DOCS" | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
for doc in data.get('data', []):
    doc_id = doc.get('id', '')
    ial = doc.get('ial', '')
    # Extract custom-category from ial
    category_match = re.search(r'custom-category=\"([^\"]+)\"', ial)
    category = category_match.group(1) if category_match else '$NB_CATEGORY'
    # Extract custom-semantic-links if present
    links_match = re.search(r'custom-semantic-links=\"([^\"]+)\"', ial)
    links = links_match.group(1) if links_match else ''
    if doc_id:
        print(f'{doc_id}|{category}|{links}')
" 2>/dev/null)

    for DOC_LINE in $DOC_IDS; do
        IFS='|' read -r DOC_ID DOC_CATEGORY DOC_LINKS <<< "$DOC_LINE"
        [ -z "$DOC_ID" ] && continue

        # Check limit
        if [ "$LIMIT" -gt 0 ] && [ "$INDEXED" -ge "$LIMIT" ]; then
            echo ""
            echo "   Reached limit of $LIMIT documents"
            break 2
        fi

        # Check if already exists (for incremental)
        if [ "$INCREMENTAL" = true ]; then
            if doc_exists_in_qdrant "$DOC_ID" 2>/dev/null; then
                SKIPPED=$((SKIPPED + 1))
                continue
            fi
        fi

        # Get document content
        DOC_CONTENT=$(curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
            -H "Authorization: Token ${CORTEX_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{\"id\": \"${DOC_ID}\"}" 2>/dev/null)

        # Extract markdown content and metadata
        DOC_METADATA=$(echo "$DOC_CONTENT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
content = data.get('data', {}).get('content', '')
# Get first line as title, rest as content
lines = content.strip().split('\n')
title = lines[0].lstrip('# ').strip() if lines else 'Untitled'
body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else ''
full_content = content.strip()
print(json.dumps({'title': title, 'body': body, 'full_content': full_content}))
" 2>/dev/null)

        TITLE=$(echo "$DOC_METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])" 2>/dev/null)
        FULL_CONTENT=$(echo "$DOC_METADATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['full_content'])" 2>/dev/null)

        [ -z "$FULL_CONTENT" ] && [ -z "$TITLE" ] && continue

        # Use smart-chunker.py for intelligent chunking
        CHUNKED_RESULT=$(echo "$DOC_METADATA" | python3 -c "
import sys, json
doc_meta = json.load(sys.stdin)
# Prepare input for smart-chunker
chunker_input = {
    'content': doc_meta['full_content'],
    'content_type': 'markdown',
    'metadata': {
        'notebook_id': '$NB_ID',
        'doc_id': '$DOC_ID',
        'notebook_name': '''$NB_NAME''',
        'title': doc_meta['title'],
        'project': 'codebuild'
    }
}
print(json.dumps(chunker_input))
" | python3 "$SMART_CHUNKER" 2>/dev/null)

        # Check if chunking was successful
        CHUNK_SUCCESS=$(echo "$CHUNKED_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('success', False))" 2>/dev/null)

        if [ "$CHUNK_SUCCESS" != "True" ]; then
            echo -n "x"  # Failed to chunk
            continue
        fi

        # Get chunk count
        CHUNK_COUNT=$(echo "$CHUNKED_RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('chunk_count', 0))" 2>/dev/null)

        # Process each chunk
        for CHUNK_IDX in $(seq 0 $((CHUNK_COUNT - 1))); do
            # Extract chunk data
            CHUNK_DATA=$(echo "$CHUNKED_RESULT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
chunk = data.get('chunks', [])[$CHUNK_IDX]
print(json.dumps(chunk))
" 2>/dev/null)

            CHUNK_TEXT=$(echo "$CHUNK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['text'])" 2>/dev/null)
            CHUNK_HASH=$(echo "$CHUNK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['hash'])" 2>/dev/null)
            CHUNK_TOTAL=$(echo "$CHUNK_DATA" | python3 -c "import sys,json; print(json.load(sys.stdin)['total'])" 2>/dev/null)

            [ -z "$CHUNK_TEXT" ] && continue

            # Create text for embedding (title + chunk for better context)
            EMBED_TEXT="$TITLE. $CHUNK_TEXT"

            # Get embedding
            EMBEDDING=$(get_embedding "$EMBED_TEXT")

            if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "[]" ] && [ "$EMBEDDING" != "null" ]; then
                # Build payload with chunk metadata and custom-category tag
                PAYLOAD=$(python3 -c "
import json
payload = {
    'type': 'knowledge',
    'source': 'cortex',
    'content': '''$CHUNK_TEXT''',
    'indexed_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'topic': '''$TITLE''',
    'category': '''$DOC_CATEGORY''',  # From custom-category attribute
    'notebook': '''$NB_NAME''',
    'cortex_url': 'https://cortex.aienablement.academy/?id=$DOC_ID',
    'cortex_doc_id': '$DOC_ID',
    'version': 1,
    'metadata': {
        'knowledge': {
            'notebook_id': '$NB_ID',
            'doc_id': '$DOC_ID',
            'notebook_name': '''$NB_NAME''',
            'custom_category': '''$DOC_CATEGORY''',  # Explicit category from metadata
            'semantic_links': '''$DOC_LINKS'''.split(',') if '''$DOC_LINKS''' else []
        },
        'chunk': {
            'index': $CHUNK_IDX,
            'total': $CHUNK_TOTAL,
            'hash': '''$CHUNK_HASH'''
        },
        'project': 'codebuild'
    }
}
print(json.dumps(payload))
" 2>/dev/null)

                if [ -n "$PAYLOAD" ]; then
                    # Use unique ID for each chunk
                    upsert_to_qdrant "cortex-$DOC_ID-chunk-$CHUNK_IDX" "$EMBEDDING" "$PAYLOAD"
                    INDEXED=$((INDEXED + 1))
                    echo -n "."
                fi
            fi

            # Rate limiting between chunks
            sleep 0.1
        done

        # Rate limiting between documents
        sleep 0.2
    done
done

# Update sync state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -c "
import json
state = {'last_sync': '$NOW', 'last_indexed_count': $INDEXED, 'last_skipped_count': $SKIPPED}
with open('$SYNC_STATE_FILE', 'w') as f:
    json.dump(state, f)
"

echo ""
echo ""
echo "✅ Cortex → Qdrant sync complete"
echo "   Indexed: $INDEXED chunks (from documents with smart chunking)"
echo "   Skipped: $SKIPPED documents (already exists)"
