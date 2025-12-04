#!/bin/bash
# Sync Supabase learnings and patterns to Qdrant semantic layer
# Uses Gemini embeddings (768 dims)
# Created: 2025-12-03 (updated with incremental mode)

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure .env is loaded with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }

SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
[ -z "$SUPABASE_KEY" ] && { echo "❌ SUPABASE_SERVICE_ROLE_KEY not set"; exit 1; }
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="agent_memory"
SYNC_STATE_FILE="/tmp/supabase-qdrant-sync-state.json"

# Check mode
INCREMENTAL=false
if [ "$1" = "--incremental" ]; then
    INCREMENTAL=true
fi

echo "🔄 Syncing Supabase → Qdrant"
echo "   Source: $SUPABASE_URL"
echo "   Target: $QDRANT_URL"
echo "   Mode: $([ "$INCREMENTAL" = true ] && echo 'incremental' || echo 'full')"
echo ""

# Get last sync timestamp for incremental
LAST_SYNC="1970-01-01T00:00:00Z"
if [ "$INCREMENTAL" = true ] && [ -f "$SYNC_STATE_FILE" ]; then
    LAST_SYNC=$(python3 -c "import json; print(json.load(open('$SYNC_STATE_FILE')).get('last_sync', '1970-01-01T00:00:00Z'))" 2>/dev/null || echo "1970-01-01T00:00:00Z")
fi

# Function to get embedding
get_embedding() {
    local text="$1"
    local escaped=$(echo "$text" | head -c 2000 | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

    curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"models/text-embedding-004\", \"content\": {\"parts\": [{\"text\": $escaped}]}}" | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d.get('embedding',{}).get('values',[])))" 2>/dev/null
}

# Function to upsert to Qdrant
upsert_to_qdrant() {
    local point_id="$1"
    local vector="$2"
    local payload="$3"

    curl -s --max-time 10 -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"points\": [{\"id\": $point_id, \"vector\": $vector, \"payload\": $payload}]}" > /dev/null
}

SUCCESS=0
SKIPPED=0

# 1. Sync learnings
echo "📚 Syncing learnings..."
if [ "$INCREMENTAL" = true ]; then
    LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=id,topic,content,category,created_at&created_at=gte.${LAST_SYNC}&limit=100" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)
else
    LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=id,topic,content,category,created_at&limit=500" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)
fi

echo "$LEARNINGS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    print(json.dumps(item))
" 2>/dev/null | while read -r learning; do
    TOPIC=$(echo "$learning" | python3 -c "import sys,json; print(json.load(sys.stdin).get('topic',''))" 2>/dev/null)
    CONTENT=$(echo "$learning" | python3 -c "import sys,json; print(json.load(sys.stdin).get('content','')[:2000])" 2>/dev/null)
    CATEGORY=$(echo "$learning" | python3 -c "import sys,json; print(json.load(sys.stdin).get('category','general'))" 2>/dev/null)
    ID=$(echo "$learning" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    [ -z "$TOPIC" ] && continue
    [ ${#CONTENT} -lt 20 ] && continue

    EMBED_TEXT="$TOPIC: $CONTENT"
    EMBEDDING=$(get_embedding "$EMBED_TEXT")

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "[]" ]; then
        HASH=$(echo -n "supabase-learning-$ID" | md5)
        POINT_ID=$((16#${HASH:0:7}))

        PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'type': 'learning',
    'source': 'supabase-sync',
    'topic': '''$TOPIC''',
    'content': '''$EMBED_TEXT'''[:3000],
    'category': '$CATEGORY',
    'indexed_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'version': 1,
    'metadata': {
        'learning': {
            'supabase_id': '$ID'
        }
    }
}))
" 2>/dev/null)

        upsert_to_qdrant "$POINT_ID" "$EMBEDDING" "$PAYLOAD"
        SUCCESS=$((SUCCESS + 1))
        echo -n "."
    fi

    sleep 0.1
done
echo ""

# 2. Sync patterns
echo "📐 Syncing patterns..."
if [ "$INCREMENTAL" = true ]; then
    PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=id,name,description,category,created_at&created_at=gte.${LAST_SYNC}&limit=100" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)
else
    PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=id,name,description,category,created_at&limit=500" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)
fi

echo "$PATTERNS" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data:
    print(json.dumps(item))
" 2>/dev/null | while read -r pattern; do
    NAME=$(echo "$pattern" | python3 -c "import sys,json; print(json.load(sys.stdin).get('name',''))" 2>/dev/null)
    DESC=$(echo "$pattern" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description','')[:2000])" 2>/dev/null)
    CATEGORY=$(echo "$pattern" | python3 -c "import sys,json; print(json.load(sys.stdin).get('category','general'))" 2>/dev/null)
    ID=$(echo "$pattern" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

    [ -z "$NAME" ] && continue
    [ ${#DESC} -lt 10 ] && continue

    EMBED_TEXT="Pattern: $NAME. $DESC"
    EMBEDDING=$(get_embedding "$EMBED_TEXT")

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "[]" ]; then
        HASH=$(echo -n "supabase-pattern-$ID" | md5)
        POINT_ID=$((16#${HASH:0:7}))

        PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'type': 'pattern',
    'source': 'supabase-sync',
    'topic': '''$NAME''',
    'content': '''$EMBED_TEXT'''[:3000],
    'category': '$CATEGORY',
    'indexed_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)',
    'version': 1,
    'metadata': {
        'pattern': {
            'supabase_id': '$ID',
            'name': '''$NAME'''
        }
    }
}))
" 2>/dev/null)

        upsert_to_qdrant "$POINT_ID" "$EMBEDDING" "$PAYLOAD"
        SUCCESS=$((SUCCESS + 1))
        echo -n "."
    fi

    sleep 0.1
done
echo ""

# Update sync state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
python3 -c "
import json
state = {'last_sync': '$NOW', 'last_success_count': $SUCCESS}
with open('$SYNC_STATE_FILE', 'w') as f:
    json.dump(state, f)
" 2>/dev/null

echo ""
echo "✅ Supabase → Qdrant sync complete"
echo "   Indexed: $SUCCESS items"
