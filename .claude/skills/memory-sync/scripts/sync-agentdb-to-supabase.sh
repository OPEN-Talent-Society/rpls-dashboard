#!/bin/bash
# Sync AgentDB episodes to Supabase patterns table
# Usage: sync-agentdb-to-supabase.sh [--incremental|--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Detect project name from current directory or use default
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == *"/codebuild"* ]]; then
    PROJECT_NAME="codebuild"
else
    PROJECT_NAME=$(basename "$CURRENT_DIR")
fi

# Load environment
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# AgentDB path
AGENTDB_PATH="${PROJECT_DIR}/agentdb.db"
SYNC_STATE_FILE="/tmp/agentdb-supabase-sync-state.json"

# Helper scripts
SMART_CHUNKER="${SCRIPT_DIR}/smart-chunker.py"
CONTENT_HASHER="${SCRIPT_DIR}/content-hasher.sh"

# Adaptive batch sizing function
calculate_batch_size() {
    local backlog=$1
    local base_batch=100

    if [ "$backlog" -lt 100 ]; then
        echo "$base_batch"
    elif [ "$backlog" -lt 500 ]; then
        echo $((base_batch * 2))  # 200
    elif [ "$backlog" -lt 2000 ]; then
        echo $((base_batch * 4))  # 400
    else
        echo $((base_batch * 10)) # 1000
    fi
}

# Sync mode
MODE="${1:---incremental}"
BATCH_SIZE=50  # Will be overridden by adaptive sizing
MAX_HOOK_ITEMS=100  # Max items per incremental run to prevent blocking

echo "🔄 Syncing AgentDB → Supabase (mode: $MODE)"
echo "   Source: $AGENTDB_PATH"
echo "   Target: $SUPABASE_URL/rest/v1/patterns"

# Check if agentdb.db exists
if [ ! -f "$AGENTDB_PATH" ]; then
    echo "⚠️  AgentDB not found at $AGENTDB_PATH"
    exit 1
fi

# Initialize sync state if not exists
if [ ! -f "$SYNC_STATE_FILE" ]; then
    echo '{"last_synced_id":0,"last_sync_time":"1970-01-01T00:00:00Z"}' > "$SYNC_STATE_FILE"
fi

# Get last synced ID
LAST_SYNCED_ID=$(jq -r '.last_synced_id // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")

# Count total and unsynced episodes
TOTAL_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
UNSYNCED_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes WHERE id > $LAST_SYNCED_ID;" 2>/dev/null || echo "0")

echo "📊 Total episodes: $TOTAL_COUNT"
echo "📊 Unsynced episodes: $UNSYNCED_COUNT"
echo "📊 Last synced ID: $LAST_SYNCED_ID"

if [ "$UNSYNCED_COUNT" -eq 0 ]; then
    echo "✅ All episodes already synced!"
    exit 0
fi

# Use adaptive batch sizing
ADAPTIVE_BATCH=$(calculate_batch_size $UNSYNCED_COUNT)
if [ "$MODE" != "--incremental" ]; then
    BATCH_SIZE=$ADAPTIVE_BATCH
    echo "📊 Adaptive batch size: $BATCH_SIZE (based on $UNSYNCED_COUNT backlog)"
fi

# Determine limit based on mode
if [ "$MODE" = "--incremental" ]; then
    LIMIT="LIMIT $MAX_HOOK_ITEMS"
    echo "   Mode: Incremental (max $MAX_HOOK_ITEMS items per run)"
    if [ "$UNSYNCED_COUNT" -gt "$MAX_HOOK_ITEMS" ]; then
        echo "   ℹ️  $((UNSYNCED_COUNT - MAX_HOOK_ITEMS)) items will remain for next sync"
    fi
else
    LIMIT=""
    echo "   Mode: Full sync (all $UNSYNCED_COUNT unsynced items)"
fi

# Extract UNSYNCED episodes only (WHERE id > last_synced_id) - FIXED: JSON parsing
# Using proven pattern from sync-episodes-to-qdrant.sh (no pipe delimiters!)
EPISODES_JSON=$(sqlite3 "$AGENTDB_PATH" -json "
SELECT
    id,
    COALESCE(session_id, '') as session_id,
    REPLACE(REPLACE(COALESCE(task, ''), char(10), ' '), char(13), ' ') as task,
    REPLACE(REPLACE(COALESCE(critique, ''), char(10), ' '), char(13), ' ') as critique,
    COALESCE(reward, 0) as reward,
    COALESCE(success, 0) as success
FROM episodes
WHERE id > $LAST_SYNCED_ID
ORDER BY id ASC $LIMIT;
" 2>/dev/null || echo "[]")

# Check if we have episodes
EPISODE_COUNT=$(echo "$EPISODES_JSON" | jq 'length' 2>/dev/null || echo "0")

if [ "$EPISODE_COUNT" -eq 0 ]; then
    echo "ℹ️  No new episodes to sync"
    exit 0
fi

echo "📤 Syncing $EPISODE_COUNT unsynced episodes in batches of $BATCH_SIZE"

# Process in batches to avoid blocking
SYNCED=0
FAILED=0
BATCH=()
MAX_ID=0

# Convert JSON array to JSONL (one object per line) and process
# FIXED: Use process substitution instead of pipe to preserve variables
while IFS= read -r episode_json; do
    # Extract fields from JSON (safe, no delimiter issues)
    EPISODE_ID=$(echo "$episode_json" | jq -r '.id')
    SESSION_ID=$(echo "$episode_json" | jq -r '.session_id')
    TASK=$(echo "$episode_json" | jq -r '.task')
    REWARD=$(echo "$episode_json" | jq -r '.reward')
    SUCCESS=$(echo "$episode_json" | jq -r '.success')
    CRITIQUE=$(echo "$episode_json" | jq -r '.critique')

    # Skip if empty
    if [ -z "$EPISODE_ID" ]; then continue; fi
    if [ -z "$SESSION_ID" ] || [ -z "$TASK" ]; then continue; fi

    # Track max ID for state update
    if [ "$EPISODE_ID" -gt "$MAX_ID" ]; then
        MAX_ID=$EPISODE_ID
    fi

    # Create pattern record with UNIQUE pattern_id (include episode_id to avoid collisions)
    PATTERN_ID="episode-${EPISODE_ID}-${SESSION_ID}"
    SUCCESS_BOOL="false"
    [ "$SUCCESS" = "1" ] && SUCCESS_BOOL="true"

    # Generate content hash for deduplication
    COMBINED_CONTENT="${TASK}|${CRITIQUE}"
    CONTENT_HASH=$(echo -n "$COMBINED_CONTENT" | bash "$CONTENT_HASHER" 2>/dev/null || echo "")

    # Check if content length needs chunking (>2000 chars for critique)
    CRITIQUE_LENGTH=${#CRITIQUE}
    DESCRIPTION="$CRITIQUE"

    if [ "$CRITIQUE_LENGTH" -gt 2000 ]; then
        # Use smart-chunker for long content
        CHUNK_INPUT=$(jq -n \
            --arg content "$CRITIQUE" \
            --arg type "text" \
            '{content: $content, content_type: $type, metadata: {episode_id: 0}}')

        CHUNK_RESULT=$(echo "$CHUNK_INPUT" | python3 "$SMART_CHUNKER" 2>/dev/null || echo '{"success":false}')

        if echo "$CHUNK_RESULT" | jq -e '.success' >/dev/null 2>&1; then
            # Get first chunk text (most relevant)
            DESCRIPTION=$(echo "$CHUNK_RESULT" | jq -r '.chunks[0].text // ""')
            CHUNK_COUNT=$(echo "$CHUNK_RESULT" | jq -r '.chunk_count // 1')

            # Add chunking info to metadata
            echo "   ℹ️  Episode $EPISODE_ID chunked into $CHUNK_COUNT parts (using first chunk)"
        else
            # Fallback to simple truncation
            DESCRIPTION="${CRITIQUE:0:2000}..."
        fi
    fi

    PATTERN=$(jq -n \
        --arg pid "$PATTERN_ID" \
        --arg name "$TASK" \
        --arg desc "$DESCRIPTION" \
        --arg reward "$REWARD" \
        --arg success "$SUCCESS_BOOL" \
        --arg eid "$EPISODE_ID" \
        --arg hash "$CONTENT_HASH" \
        --arg project "$PROJECT_NAME" \
        '{
            pattern_id: $pid,
            name: $name,
            category: "agent_episode",
            description: $desc,
            template: {
                reward: ($reward | tonumber),
                success: ($success == "true"),
                source: "agentdb",
                episode_id: ($eid | tonumber),
                content_hash: $hash,
                project: $project
            },
            use_cases: ["task_completion", "learning"],
            success_count: (if ($success == "true") then 1 else 0 end)
        }')

    # Add to batch
    BATCH+=("$PATTERN")

    # When batch is full, send it
    if [ ${#BATCH[@]} -ge $BATCH_SIZE ]; then
        # Convert array to JSON array
        BATCH_JSON=$(printf '%s\n' "${BATCH[@]}" | jq -s '.')

        # Upsert batch to Supabase - use PATCH for true upsert behavior
        # pattern_id is unique, so we upsert based on that
        # Note: Prefer header format is semicolon-separated, not comma-separated
        # Use on_conflict to properly upsert based on pattern_id
        RESPONSE=$(curl -s --max-time 60 -X POST "${SUPABASE_URL}/rest/v1/patterns?on_conflict=pattern_id" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "$BATCH_JSON" 2>&1 || echo '{"error":"timeout"}')

        # Debug: save response
        echo "$RESPONSE" > /tmp/supabase-batch-response.txt

        if echo "$RESPONSE" | grep -qi "error\|code.*23"; then
            FAILED=$((FAILED + ${#BATCH[@]}))
            ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // .hint // .details // "unknown"' 2>/dev/null || echo "$RESPONSE")
            echo "❌ Batch failed (${#BATCH[@]} items): $ERROR_MSG"
        else
            SYNCED=$((SYNCED + ${#BATCH[@]}))
            echo "✅ Batch synced: ${#BATCH[@]} items ($SYNCED/$EPISODE_COUNT total)"

            # Update state after successful batch
            jq -n \
                --argjson lid "$MAX_ID" \
                --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{last_synced_id: $lid, last_sync_time: $lts}' > "$SYNC_STATE_FILE"
        fi

        # Clear batch
        BATCH=()
    fi
done < <(echo "$EPISODES_JSON" | jq -c '.[]')

# Process remaining items in batch
if [ ${#BATCH[@]} -gt 0 ]; then
    BATCH_JSON=$(printf '%s\n' "${BATCH[@]}" | jq -s '.')

    RESPONSE=$(curl -s --max-time 60 -X POST "${SUPABASE_URL}/rest/v1/patterns?on_conflict=pattern_id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "$BATCH_JSON" 2>&1 || echo '{"error":"timeout"}')

    if echo "$RESPONSE" | grep -q "error"; then
        FAILED=$((FAILED + ${#BATCH[@]}))
        echo "❌ Final batch failed (${#BATCH[@]} items)"
    else
        SYNCED=$((SYNCED + ${#BATCH[@]}))
        echo "✅ Final batch synced: ${#BATCH[@]} items"

        # Update state after final batch
        jq -n \
            --argjson lid "$MAX_ID" \
            --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{last_synced_id: $lid, last_sync_time: $lts}' > "$SYNC_STATE_FILE"
    fi
fi

echo ""
echo "✅ Sync complete: AgentDB → Supabase"
echo "   Synced: $SYNCED items"
echo "   Last ID: $MAX_ID"
if [ $FAILED -gt 0 ]; then
    echo "   Failed: $FAILED items"
fi

# Check remaining backlog
REMAINING=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes WHERE id > $MAX_ID;" 2>/dev/null || echo "0")
if [ "$REMAINING" -gt 0 ]; then
    echo ""
    echo "ℹ️  $REMAINING episodes remaining. Run again to continue sync."
fi
