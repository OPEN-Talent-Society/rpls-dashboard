#!/bin/bash
# Sync Hive-Mind memory to cold storage (Supabase + Cortex)
# Extracts knowledge_base, tasks, and insights from Hive-Mind JSON
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

# Cloudflare auth - Global API Key (more reliable)
CF_AUTH_EMAIL="${CF_AUTH_EMAIL:-adam@aienablement.academy}"
CF_GLOBAL_KEY="${CF_GLOBAL_API_KEY}"

echo "🐝 Syncing Hive-Mind → Cold Storage"

# Find all hive-mind memory files
HIVE_FILES=$(find "$PROJECT_DIR" -name "memory.json" -path "*hive-mind*" 2>/dev/null)

if [ -z "$HIVE_FILES" ]; then
    echo "  ⚠️  No Hive-Mind memory files found"
    exit 0
fi

TOTAL_SYNCED=0

for HIVE_FILE in $HIVE_FILES; do
    echo ""
    echo "📂 Processing: $HIVE_FILE"

    # Extract project name from path
    PROJECT_NAME=$(echo "$HIVE_FILE" | sed 's|.*/\([^/]*\)/.hive-mind/.*|\1|')

    # 1. Sync knowledge_base entries to Supabase learnings
    echo "  📚 Syncing knowledge_base..."
    # Check if knowledge_base is an array of objects
    KB_TYPE=$(cat "$HIVE_FILE" | jq -r 'if (.knowledge_base | type) == "array" then "array" else "other" end' 2>/dev/null)

    if [ "$KB_TYPE" = "array" ]; then
        KB_COUNT=$(cat "$HIVE_FILE" | jq '.knowledge_base | length' 2>/dev/null || echo "0")
        for i in $(seq 0 $((KB_COUNT - 1))); do
            entry=$(cat "$HIVE_FILE" | jq -c ".knowledge_base[$i]" 2>/dev/null)
            [ -z "$entry" ] || [ "$entry" = "null" ] && continue

            TOPIC=$(echo "$entry" | jq -r '.topic // .key // "hive-knowledge"' 2>/dev/null)
            CONTENT=$(echo "$entry" | jq -r '.content // .value // ""' 2>/dev/null)
            CATEGORY=$(echo "$entry" | jq -r '.category // "hive-mind"' 2>/dev/null)

            if [ -n "$CONTENT" ]; then
                LEARNING=$(jq -n \
                    --arg topic "$TOPIC" \
                    --arg content "$CONTENT" \
                    --arg category "$CATEGORY" \
                    --arg context "Synced from Hive-Mind: $PROJECT_NAME" \
                    --arg agent_id "hive-mind-sync" \
                    '{
                        learning_id: ("hive-" + ($topic | gsub(" "; "-") | ascii_downcase)),
                        topic: $topic,
                        content: $content,
                        category: $category,
                        context: $context,
                        agent_id: $agent_id,
                        tags: ["hive-mind", "auto-sync"]
                    }')

                RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                    -H "apikey: ${SUPABASE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                    -H "Content-Type: application/json" \
                    -H "Prefer: resolution=merge-duplicates" \
                    -d "$LEARNING" 2>&1)

                if ! echo "$RESPONSE" | grep -q "error"; then
                    TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
                fi
            fi
        done
    fi

    # 2. Sync completed tasks as patterns
    echo "  ✅ Syncing completed tasks..."
    TASKS=$(cat "$HIVE_FILE" | jq -c '.tasks[]? | select(.status == "completed" or .status == "done")' 2>/dev/null)

    if [ -n "$TASKS" ]; then
        echo "$TASKS" | while read -r task; do
            NAME=$(echo "$task" | jq -r '.description // .name // "hive-task"' | head -c 100)
            RESULT=$(echo "$task" | jq -r '.result // .output // ""')

            if [ -n "$NAME" ]; then
                PATTERN=$(jq -n \
                    --arg name "$NAME" \
                    --arg desc "$RESULT" \
                    --arg category "hive-task" \
                    '{
                        pattern_id: ("hive-task-" + (now | tostring)),
                        name: $name,
                        description: $desc,
                        category: $category,
                        template: "# Hive Task Pattern\n\n## Context\n{{description}}\n\n## Application\nApply this pattern when encountering similar tasks.",
                        success_count: 1
                    }')

                curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
                    -H "apikey: ${SUPABASE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                    -H "Content-Type: application/json" \
                    -H "Prefer: resolution=merge-duplicates" \
                    -d "$PATTERN" 2>/dev/null

                TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
            fi
        done
    fi

    # 3. Sync agent performance as metrics to Supabase agent_memory
    echo "  📊 Syncing agent metrics..."
    METRICS=$(cat "$HIVE_FILE" | jq -c '.performance_metrics // {}' 2>/dev/null)

    if [ "$METRICS" != "{}" ] && [ -n "$METRICS" ]; then
        MEMORY=$(jq -n \
            --arg key "hive-metrics-$PROJECT_NAME" \
            --arg value "$METRICS" \
            --arg ns "hive-mind" \
            --arg agent "hive-mind-sync" \
            '{
                key: $key,
                value: $value,
                namespace: $ns,
                agent_id: $agent,
                metadata: {"source": "hive-mind-sync", "type": "metrics"}
            }')

        curl -s -X POST "${SUPABASE_URL}/rest/v1/agent_memory" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "$MEMORY" 2>/dev/null

        TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
    fi

    # 4. DISABLED - Cortex sync per MEMORY-SYSTEM-SPECIFICATION.md
    # Raw machine data (consensus votes) should NOT be dumped to Cortex
    # Use /cortex-* commands for curated human-readable content
    echo "  🗳️  Cortex sync DISABLED (use /cortex-note for curated content)"
done

echo ""
echo "✅ Hive-Mind sync complete: $TOTAL_SYNCED items synced"
