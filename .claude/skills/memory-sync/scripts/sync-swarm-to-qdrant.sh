#!/bin/bash
# Sync Swarm Memory to Qdrant for semantic search
# Indexes task_trajectories and high-value memory_entries
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

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="agent_memory"
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
SYNC_STATE_FILE="/tmp/swarm-qdrant-sync-state.json"

# Check if incremental mode
INCREMENTAL=false
if [ "$1" = "--incremental" ]; then
    INCREMENTAL=true
fi

echo "🔄 Syncing Swarm Memory → Qdrant"
echo "   Database: $SWARM_DB"
echo "   Collection: $COLLECTION"
echo "   Mode: $([ "$INCREMENTAL" = true ] && echo 'incremental' || echo 'full')"

if [ ! -f "$SWARM_DB" ]; then
    echo "   ⚠️  Swarm database not found"
    exit 0
fi

# Get last sync timestamp for incremental
LAST_SYNC="1970-01-01T00:00:00Z"
if [ "$INCREMENTAL" = true ] && [ -f "$SYNC_STATE_FILE" ]; then
    LAST_SYNC=$(jq -r '.last_sync // "1970-01-01T00:00:00Z"' "$SYNC_STATE_FILE" 2>/dev/null)
fi

# Function to get Gemini embedding
get_embedding() {
    local text="$1"
    local escaped_text=$(echo "$text" | head -c 5000 | jq -Rs '.')

    local response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/text-embedding-004\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]}
        }")

    echo "$response" | jq -c '.embedding.values // empty'
}

# Function to upsert to Qdrant
upsert_to_qdrant() {
    local id="$1"
    local vector="$2"
    local payload="$3"

    # Convert string ID to numeric hash
    local numeric_id=$(echo -n "$id" | md5sum | cut -c1-16)
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

# 1. Index task_trajectories (most valuable)
echo ""
echo "📍 Indexing task trajectories..."

TRAJECTORIES=$(sqlite3 "$SWARM_DB" "
    SELECT task_id, agent_id, query, judge_label, judge_reasons, created_at
    FROM task_trajectories
    WHERE created_at > '$LAST_SYNC'
    ORDER BY created_at DESC
    LIMIT 50;
" 2>/dev/null)

if [ -n "$TRAJECTORIES" ]; then
    echo "$TRAJECTORIES" | while IFS='|' read -r TASK_ID AGENT_ID QUERY JUDGE_LABEL JUDGE_REASONS CREATED_AT; do
        [ -z "$QUERY" ] && continue

        # Build content for embedding
        CONTENT="Task: $QUERY. Agent: $AGENT_ID. Judgment: $JUDGE_LABEL. $JUDGE_REASONS"

        EMBEDDING=$(get_embedding "$CONTENT")

        if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
            PAYLOAD=$(jq -n \
                --arg type "trajectory" \
                --arg source "swarm-memory" \
                --arg content "$CONTENT" \
                --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --arg topic "$QUERY" \
                --arg task_id "$TASK_ID" \
                --arg agent_id "$AGENT_ID" \
                --arg judge_label "$JUDGE_LABEL" \
                '{
                    type: $type,
                    source: $source,
                    content: $content,
                    indexed_at: $indexed_at,
                    topic: $topic,
                    version: 1,
                    metadata: {
                        trajectory: {
                            task_id: $task_id,
                            agent_id: $agent_id,
                            judge_label: $judge_label
                        }
                    }
                }')

            upsert_to_qdrant "trajectory-$TASK_ID" "$EMBEDDING" "$PAYLOAD"
            INDEXED=$((INDEXED + 1))
            echo -n "."
        fi
    done
    echo ""
fi

# 2. Index high-value memory_entries (hooks:post-task, coordination)
echo "📍 Indexing high-value memory entries..."

VALUABLE_NAMESPACES="'hooks:post-task','coordination','task-index'"
ENTRIES=$(sqlite3 "$SWARM_DB" "
    SELECT id, key, value, namespace, created_at
    FROM memory_entries
    WHERE namespace IN ($VALUABLE_NAMESPACES)
    AND datetime(created_at, 'unixepoch') > '$LAST_SYNC'
    ORDER BY created_at DESC
    LIMIT 50;
" 2>/dev/null)

if [ -n "$ENTRIES" ]; then
    echo "$ENTRIES" | while IFS='|' read -r ID KEY VALUE NAMESPACE CREATED_AT; do
        [ -z "$VALUE" ] && continue

        # Build content
        CONTENT="$KEY: $VALUE"

        EMBEDDING=$(get_embedding "$CONTENT")

        if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
            PAYLOAD=$(jq -n \
                --arg type "swarm-memory" \
                --arg source "swarm-memory" \
                --arg content "$CONTENT" \
                --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --arg topic "$KEY" \
                --arg namespace "$NAMESPACE" \
                --arg original_id "$ID" \
                '{
                    type: $type,
                    source: $source,
                    content: $content,
                    indexed_at: $indexed_at,
                    topic: $topic,
                    category: $namespace,
                    version: 1,
                    metadata: {
                        "swarm-memory": {
                            original_id: $original_id,
                            namespace: $namespace
                        }
                    }
                }')

            upsert_to_qdrant "swarm-entry-$ID" "$EMBEDDING" "$PAYLOAD"
            INDEXED=$((INDEXED + 1))
            echo -n "."
        fi
    done
    echo ""
fi

# Update sync state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg last_sync "$NOW" --argjson indexed "$INDEXED" \
    '{last_sync: $last_sync, last_indexed_count: $indexed}' > "$SYNC_STATE_FILE"

echo ""
echo "✅ Swarm → Qdrant sync complete"
echo "   Indexed: $INDEXED entries"
