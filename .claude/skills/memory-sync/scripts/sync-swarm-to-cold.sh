#!/bin/bash
# Sync Swarm Memory to cold storage (Supabase + Cortex)
# Extracts patterns, trajectories, and coordination data
# Created: 2025-12-02

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# Cortex config
SIYUAN_BASE_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${CORTEX_TOKEN}"

# Cloudflare Zero Trust (required for Cortex access)
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
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
    TRAJ_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM task_trajectories WHERE judge_label = 'correct' OR judge_label = 'success';" 2>/dev/null || echo "0")

    if [ "$TRAJ_COUNT" -gt 0 ]; then
        TRAJECTORIES=$(sqlite3 "$SWARM_DB" "SELECT agent_id, query, judge_label, created_at FROM task_trajectories WHERE judge_label = 'correct' OR judge_label = 'success' ORDER BY created_at DESC LIMIT 20;" 2>/dev/null)
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
    else
        echo "  ℹ️  No successful trajectories found"
    fi
else
    echo "  ℹ️  task_trajectories table not found"
fi

# 2. Sync ReasoningBank patterns to AgentDB (fast bulk insert)
echo ""
echo "🔗 Syncing ReasoningBank patterns to AgentDB..."

HAS_PATTERNS=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='patterns';" 2>/dev/null)
AGENTDB="$PROJECT_DIR/agentdb.db"

if [ -n "$HAS_PATTERNS" ]; then
    PATTERN_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
    echo "  📊 Found $PATTERN_COUNT patterns in ReasoningBank"

    if [ "$PATTERN_COUNT" -gt 0 ] && [ -f "$AGENTDB" ]; then
        # FAST APPROACH: Use SQLite's ATTACH to copy patterns directly
        # This avoids slow shell loops and API calls

        # Count before
        BEFORE=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes WHERE session_id='reasoningbank-sync';" 2>/dev/null || echo "0")

        # Use ATTACH to efficiently copy data between databases
        sqlite3 "$AGENTDB" "
            ATTACH '${SWARM_DB}' AS swarm;

            -- Insert patterns from ReasoningBank into AgentDB episodes
            INSERT OR REPLACE INTO episodes (task, reward, success, critique, session_id)
            SELECT
                COALESCE(json_extract(pattern_data, '$.title'), 'Pattern-' || id) as task,
                confidence as reward,
                1 as success,
                substr(COALESCE(json_extract(pattern_data, '$.content'), pattern_data), 1, 2000) as critique,
                'reasoningbank-sync' as session_id
            FROM swarm.patterns;

            DETACH swarm;
        " 2>/dev/null

        # Count after
        AFTER=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes WHERE session_id='reasoningbank-sync';" 2>/dev/null || echo "0")
        SYNCED=$((AFTER - BEFORE))

        if [ "$SYNCED" -ge 0 ]; then
            echo "  ✅ Synced $AFTER patterns to AgentDB (${SYNCED} new)"
            TOTAL_SYNCED=$((TOTAL_SYNCED + AFTER))
        else
            echo "  ⚠️  Sync may have replaced some entries"
        fi

        # Optional: Also sync to Supabase (slower, one by one - only first 50 for API limits)
        if [ -n "$SUPABASE_KEY" ]; then
            echo "  📤 Syncing top 50 patterns to Supabase..."
            SYNCED_TO_SUPABASE=0

            sqlite3 "$SWARM_DB" "SELECT id, json_extract(pattern_data, '$.title'), confidence FROM patterns ORDER BY confidence DESC LIMIT 50;" 2>/dev/null | while IFS='|' read -r ID TITLE CONF; do
                [ -z "$ID" ] && continue
                [ -z "$TITLE" ] && TITLE="Pattern-$ID"

                LEARNING=$(jq -n \
                    --arg topic "$TITLE" \
                    --arg category "reasoningbank-pattern" \
                    --arg patternId "$ID" \
                    '{
                        learning_id: ("rb-" + $patternId),
                        topic: $topic,
                        content: "See ReasoningBank for full content",
                        category: $category,
                        agent_id: "reasoningbank-sync",
                        tags: ["reasoningbank", "pattern"]
                    }')

                curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                    -H "apikey: ${SUPABASE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                    -H "Content-Type: application/json" \
                    -H "Prefer: resolution=merge-duplicates" \
                    -d "$LEARNING" >/dev/null 2>&1

                SYNCED_TO_SUPABASE=$((SYNCED_TO_SUPABASE + 1))
            done
            echo "  ✅ Synced to Supabase: 50 patterns (top by confidence)"
        fi
    else
        echo "  ℹ️  No patterns found or AgentDB not available"
    fi
else
    echo "  ℹ️  patterns table not found in Swarm Memory"
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
