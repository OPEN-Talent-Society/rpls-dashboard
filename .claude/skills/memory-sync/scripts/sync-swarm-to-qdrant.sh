#!/bin/bash
# Sync Swarm Memory to Qdrant for semantic search
# Simplified version - directly embeds content without complex chunking
# Created: 2025-12-03 | Simplified: 2025-12-11

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="agent_memory"
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
SYNC_STATE_FILE="/tmp/swarm-qdrant-sync-state.json"

PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "🔄 Syncing Swarm Memory → Qdrant"
echo "   Database: $SWARM_DB"
echo "   Collection: $COLLECTION"

if [ ! -f "$SWARM_DB" ]; then
    echo "   ⚠️  Swarm database not found"
    exit 0
fi

# Function to get Gemini embedding
get_embedding() {
    local text="$1"
    local escaped_text=$(echo "$text" | jq -Rs '.')

    curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/gemini-embedding-001\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" | jq -c '.embedding.values // empty'
}

# Function to upsert to Qdrant (macOS compatible)
upsert_to_qdrant() {
    local id="$1"
    local vector="$2"
    local payload="$3"

    # macOS uses md5, Linux uses md5sum
    local numeric_id
    if command -v md5 &>/dev/null; then
        numeric_id=$(echo -n "$id" | md5 | cut -c1-8)
    else
        numeric_id=$(echo -n "$id" | md5sum | cut -c1-8)
    fi
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

INDEXED=0

# Index high-value memory entries (skip operational telemetry)
echo ""
echo "📍 Indexing valuable memory entries..."

# Query memory entries with valuable namespaces
ENTRIES_JSON=$(sqlite3 "$SWARM_DB" -json "
    SELECT
        id,
        COALESCE(key, '') as key,
        COALESCE(value, '') as value,
        COALESCE(namespace, '') as namespace
    FROM memory_entries
    WHERE namespace IN ('hooks:post-task','coordination','task-index','patterns','learnings','insights')
    ORDER BY created_at DESC
    LIMIT 100;
" 2>/dev/null || echo "[]")

ENTRY_COUNT=$(echo "$ENTRIES_JSON" | jq 'length' 2>/dev/null || echo "0")
ENTRY_COUNT=${ENTRY_COUNT:-0}

echo "   Found $ENTRY_COUNT entries to process"

if [ "$ENTRY_COUNT" -gt 0 ]; then
    # Process entries using jq to safely handle JSON
    echo "$ENTRIES_JSON" | jq -c '.[]' 2>/dev/null | while read -r entry; do
        ID=$(echo "$entry" | jq -r '.id // ""')
        KEY=$(echo "$entry" | jq -r '.key // ""')
        VALUE=$(echo "$entry" | jq -r '.value // ""')
        NAMESPACE=$(echo "$entry" | jq -r '.namespace // ""')

        [ -z "$VALUE" ] && continue

        # Skip if VALUE looks like operational telemetry
        case "$VALUE" in
            command:*|tool:*|metric:*|debug:*|log:*) continue ;;
        esac

        # Build content - truncate at 4000 chars for embedding
        CONTENT="$KEY: $VALUE"
        CONTENT=$(echo "$CONTENT" | head -c 4000)

        # Get embedding
        EMBEDDING=$(get_embedding "$CONTENT")

        if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
            # Build payload using jq for safe JSON encoding
            PAYLOAD=$(jq -cn \
                --arg type "swarm-memory" \
                --arg source "swarm-memory" \
                --arg content "$CONTENT" \
                --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --arg topic "$KEY" \
                --arg namespace "$NAMESPACE" \
                --arg original_id "$ID" \
                --arg project_name "$PROJECT_NAME" \
                '{
                    type: $type,
                    source: $source,
                    content: $content,
                    indexed_at: $indexed_at,
                    topic: $topic,
                    category: $namespace,
                    version: 1,
                    project: {name: $project_name},
                    metadata: {original_id: $original_id, namespace: $namespace}
                }')

            upsert_to_qdrant "swarm-$ID" "$EMBEDDING" "$PAYLOAD"
            echo -n "."
            INDEXED=$((INDEXED + 1))

            # Rate limit
            sleep 0.2
        fi
    done
    echo ""
fi

# Update sync state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
INDEXED=${INDEXED:-0}
echo "{\"last_sync\": \"$NOW\", \"indexed_count\": $INDEXED}" > "$SYNC_STATE_FILE"

echo ""
echo "✅ Swarm → Qdrant sync complete"
echo "   Indexed: $INDEXED entries"
