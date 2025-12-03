#!/bin/bash
# Sync Swarm Memory to cold storage (Supabase + Cortex)
# Extracts patterns, trajectories, and coordination data
# Created: 2025-12-02

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-sb_secret_g87UniWlZT7GYIQsrWEYYw_VJs7i0Ei}"

# Cortex config
SIYUAN_BASE_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${CORTEX_TOKEN:-0fkvtzw0jrat2oht}"

# Cloudflare Zero Trust (required for Cortex access)
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID:-6c0fe301311410aea8ca6e236a176938.access}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET:-714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3}"
NOTEBOOK_RESOURCES="20251201183343-ujsixib"  # 03 Resources

# Swarm Memory path
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"

echo "🐝 Syncing Swarm Memory → Cold Storage"

if [ ! -f "$SWARM_DB" ]; then
    echo "  ⚠️  Swarm Memory not found at $SWARM_DB"
    exit 0
fi

TOTAL_SYNCED=0

# 1. Sync successful trajectories to Supabase patterns
echo ""
echo "📊 Syncing successful trajectories..."

# Check if task_trajectories table exists
HAS_TRAJECTORIES=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='task_trajectories';" 2>/dev/null)

if [ -n "$HAS_TRAJECTORIES" ]; then
    TRAJECTORIES=$(sqlite3 "$SWARM_DB" "SELECT agent_id, query, judge_label, created_at FROM task_trajectories WHERE judge_label = 'correct' OR judge_label = 'success' ORDER BY created_at DESC LIMIT 20;" 2>/dev/null)

    if [ -n "$TRAJECTORIES" ]; then
        echo "$TRAJECTORIES" | while IFS='|' read -r AGENT_ID QUERY LABEL CREATED_AT; do
            [ -z "$QUERY" ] && continue

            PATTERN=$(jq -n \
                --arg name "swarm-${AGENT_ID}-$(echo "$QUERY" | head -c 30 | tr ' ' '-')" \
                --arg desc "$QUERY" \
                --arg category "swarm-trajectory" \
                '{
                    pattern_id: ("swarm-traj-" + ($name | gsub(" "; "-") | ascii_downcase)),
                    name: $name,
                    description: $desc,
                    category: $category,
                    template: "# Swarm Trajectory Pattern\n\n## Query\n{{description}}\n\n## Application\nReuse this successful swarm coordination pattern.",
                    success_count: 1
                }')

            RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
                -H "apikey: ${SUPABASE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_KEY}" \
                -H "Content-Type: application/json" \
                -H "Prefer: resolution=merge-duplicates" \
                -d "$PATTERN" 2>&1)

            if ! echo "$RESPONSE" | grep -q "error"; then
                TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
                echo "  ✅ Trajectory: ${QUERY:0:40}..."
            fi
        done
    fi
fi

# 2. Sync coordination patterns
echo ""
echo "🔗 Syncing coordination patterns..."

HAS_PATTERNS=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='patterns';" 2>/dev/null)

if [ -n "$HAS_PATTERNS" ]; then
    PATTERNS=$(sqlite3 "$SWARM_DB" "SELECT pattern_name, pattern_data, success_rate FROM patterns WHERE success_rate >= 0.7 ORDER BY success_rate DESC LIMIT 10;" 2>/dev/null)

    if [ -n "$PATTERNS" ]; then
        echo "$PATTERNS" | while IFS='|' read -r NAME DATA SUCCESS_RATE; do
            [ -z "$NAME" ] && continue

            LEARNING=$(jq -n \
                --arg topic "Swarm Pattern: $NAME" \
                --arg content "$DATA" \
                --arg category "swarm-coordination" \
                --arg rate "$SUCCESS_RATE" \
                '{
                    learning_id: ("swarm-pattern-" + ($topic | gsub(" "; "-") | ascii_downcase)),
                    topic: $topic,
                    content: $content,
                    category: $category,
                    context: ("Success rate: " + $rate),
                    agent_id: "swarm-sync",
                    tags: ["swarm", "pattern", "coordination"]
                }')

            curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                -H "apikey: ${SUPABASE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_KEY}" \
                -H "Content-Type: application/json" \
                -H "Prefer: resolution=merge-duplicates" \
                -d "$LEARNING" 2>/dev/null

            TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
        done
    fi
fi

# 3. Sync swarm metrics to Cortex
echo ""
echo "📈 Syncing swarm metrics to Cortex..."

METRICS_DOC="# Swarm Memory Metrics

#swarm #metrics #auto-sync

## Overview
Aggregated metrics from Swarm Memory coordination.

## Trajectory Statistics
$(sqlite3 "$SWARM_DB" "SELECT '- **' || judge_label || '**: ' || COUNT(*) || ' entries' FROM task_trajectories GROUP BY judge_label;" 2>/dev/null || echo "- No trajectories recorded")

## Top Performing Agents
$(sqlite3 "$SWARM_DB" "SELECT '- **' || agent_id || '**: ' || COUNT(*) || ' successful tasks' FROM task_trajectories WHERE judge_label IN ('correct', 'success') GROUP BY agent_id ORDER BY COUNT(*) DESC LIMIT 5;" 2>/dev/null || echo "- No agent data")

## Database Stats
- **Location**: \`.swarm/memory.db\`
- **Tables**: $(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM sqlite_master WHERE type='table';" 2>/dev/null || echo "0")
- **Last Sync**: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Related
- [[Memory System SOP]]
- [[AgentDB Patterns Index]]
- [[Hive-Mind Memory]]

---
*Auto-synced from Swarm Memory*"

curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
    -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg nb "$NOTEBOOK_RESOURCES" \
        --arg path "/Swarm-Memory/Metrics" \
        --arg md "$METRICS_DOC" \
        '{notebook: $nb, path: $path, markdown: $md}')" 2>/dev/null

TOTAL_SYNCED=$((TOTAL_SYNCED + 1))

echo ""
echo "✅ Swarm Memory → Cold Storage sync complete: $TOTAL_SYNCED items synced"
