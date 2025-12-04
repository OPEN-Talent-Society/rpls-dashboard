#!/bin/bash
# Sync Cortex (SiYuan) knowledge base to Qdrant for semantic search
# Indexes documents from all notebooks with embeddings
# Created: 2025-12-03

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure .env is loaded with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }

# Cortex (SiYuan) config - credentials from .env
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
[ -z "$CF_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_TOKEN="${CORTEX_TOKEN}"
[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="agent_memory"

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

    local response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/text-embedding-004\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]}
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

# Notebooks to sync (PARA methodology)
NOTEBOOKS=(
    "20251103053911-8ex6uns:01 Projects"
    "20251201183343-543piyt:02 Areas"
    "20251201183343-ujsixib:03 Resources"
    "20251201183343-xf2snc8:04 Archives"
    "20251103053840-moamndp:05 Knowledge Base"
    "20251103053916-bq6qbgu:06 Agents"
)

INDEXED=0
SKIPPED=0

for NB_ENTRY in "${NOTEBOOKS[@]}"; do
    NB_ID="${NB_ENTRY%%:*}"
    NB_NAME="${NB_ENTRY#*:}"

    echo ""
    echo "📚 Processing: $NB_NAME"

    # Get documents from notebook
    DOCS=$(curl -s -X POST "${CORTEX_URL}/api/filetree/listDocsByPath" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"notebook\": \"${NB_ID}\", \"path\": \"/\"}" 2>/dev/null)

    # Extract document IDs
    DOC_IDS=$(echo "$DOCS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for f in data.get('data', {}).get('files', []):
    if f.get('id'):
        print(f['id'])
" 2>/dev/null)

    for DOC_ID in $DOC_IDS; do
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

        # Extract markdown content and title
        CONTENT=$(echo "$DOC_CONTENT" | python3 -c "
import sys, json
data = json.load(sys.stdin)
content = data.get('data', {}).get('content', '')
# Get first line as title, rest as content
lines = content.strip().split('\n')
title = lines[0].lstrip('# ').strip() if lines else 'Untitled'
body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else ''
print(json.dumps({'title': title, 'body': body[:4000]}))
" 2>/dev/null)

        TITLE=$(echo "$CONTENT" | python3 -c "import sys,json; print(json.load(sys.stdin)['title'])" 2>/dev/null)
        BODY=$(echo "$CONTENT" | python3 -c "import sys,json; print(json.load(sys.stdin)['body'])" 2>/dev/null)

        [ -z "$BODY" ] && [ -z "$TITLE" ] && continue

        # Create text for embedding
        EMBED_TEXT="$TITLE. $BODY"

        # Get embedding
        EMBEDDING=$(get_embedding "$EMBED_TEXT")

        if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "[]" ] && [ "$EMBEDDING" != "null" ]; then
            # Build payload
            PAYLOAD=$(python3 -c "
import json
payload = {
    'type': 'knowledge',
    'source': 'cortex',
    'content': '''$EMBED_TEXT'''[:3000],
    'indexed_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'topic': '''$TITLE''',
    'category': '''$NB_NAME''',
    'version': 1,
    'metadata': {
        'knowledge': {
            'notebook_id': '$NB_ID',
            'doc_id': '$DOC_ID',
            'notebook_name': '''$NB_NAME'''
        }
    }
}
print(json.dumps(payload))
" 2>/dev/null)

            if [ -n "$PAYLOAD" ]; then
                upsert_to_qdrant "cortex-$DOC_ID" "$EMBEDDING" "$PAYLOAD"
                INDEXED=$((INDEXED + 1))
                echo -n "."
            fi
        fi

        # Rate limiting
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
echo "   Indexed: $INDEXED documents"
echo "   Skipped: $SKIPPED (already exists)"
