#!/bin/bash
# Sync AgentDB episodes to Supabase patterns table
# Usage: sync-agentdb-to-supabase.sh [--force]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load environment
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# AgentDB path
AGENTDB_PATH="${PROJECT_DIR}/agentdb.db"

echo "🔄 Syncing AgentDB → Supabase"
echo "   Source: $AGENTDB_PATH"
echo "   Target: $SUPABASE_URL/rest/v1/patterns"

# Check if agentdb.db exists
if [ ! -f "$AGENTDB_PATH" ]; then
    echo "⚠️  AgentDB not found at $AGENTDB_PATH"
    exit 1
fi

# Extract episodes from AgentDB using sqlite3
# No LIMIT - sync all episodes to ensure complete data in Supabase
EPISODES=$(sqlite3 "$AGENTDB_PATH" "SELECT json_object(
    'session_id', session_id,
    'task', task,
    'reward', reward,
    'success', success,
    'input', input,
    'output', output,
    'critique', critique,
    'created_at', created_at
) FROM episodes ORDER BY created_at DESC;" 2>/dev/null || echo "[]")

if [ -z "$EPISODES" ] || [ "$EPISODES" = "[]" ]; then
    echo "ℹ️  No episodes to sync"
    exit 0
fi

# Count episodes
COUNT=$(echo "$EPISODES" | wc -l | tr -d ' ')
echo "📊 Found $COUNT episodes to sync"

# Transform and upsert each episode to Supabase patterns table
echo "$EPISODES" | while read -r episode; do
    if [ -z "$episode" ]; then continue; fi

    # Extract fields
    SESSION_ID=$(echo "$episode" | jq -r '.session_id // empty')
    TASK=$(echo "$episode" | jq -r '.task // empty')
    REWARD=$(echo "$episode" | jq -r '.reward // 0')
    SUCCESS=$(echo "$episode" | jq -r '.success // false')
    CRITIQUE=$(echo "$episode" | jq -r '.critique // empty')

    if [ -z "$SESSION_ID" ] || [ -z "$TASK" ]; then continue; fi

    # Create pattern record
    PATTERN_ID="episode-${SESSION_ID}"
    PATTERN=$(jq -n \
        --arg pid "$PATTERN_ID" \
        --arg name "$TASK" \
        --arg desc "$CRITIQUE" \
        --argjson reward "$REWARD" \
        --argjson success "$SUCCESS" \
        '{
            pattern_id: $pid,
            name: $name,
            category: "agent_episode",
            description: $desc,
            template: { reward: $reward, success: $success, source: "agentdb" },
            use_cases: ["task_completion", "learning"],
            success_count: (if $success then 1 else 0 end)
        }')

    # Upsert to Supabase
    RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "$PATTERN" 2>&1)

    if echo "$RESPONSE" | grep -q "error"; then
        echo "❌ Failed to sync: $SESSION_ID"
        echo "   Error: $RESPONSE"
    else
        echo "✅ Synced: $TASK"
    fi
done

echo ""
echo "✅ Sync complete: AgentDB → Supabase"
