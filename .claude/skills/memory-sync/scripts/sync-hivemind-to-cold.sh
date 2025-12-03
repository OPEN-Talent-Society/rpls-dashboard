#!/bin/bash
# Sync Hive-Mind memory to cold storage (Supabase + Cortex)
# Extracts knowledge_base, tasks, and insights from Hive-Mind JSON
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
    KNOWLEDGE=$(cat "$HIVE_FILE" | jq -c '.knowledge_base[]?' 2>/dev/null)

    if [ -n "$KNOWLEDGE" ]; then
        echo "$KNOWLEDGE" | while read -r entry; do
            TOPIC=$(echo "$entry" | jq -r '.topic // .key // "hive-knowledge"')
            CONTENT=$(echo "$entry" | jq -r '.content // .value // ""')
            CATEGORY=$(echo "$entry" | jq -r '.category // "hive-mind"')

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

    # 4. Sync consensus decisions to Cortex (with proper SiYuan features)
    echo "  🗳️  Syncing consensus to Cortex..."
    CONSENSUS=$(cat "$HIVE_FILE" | jq -c '.consensus_votes[]?' 2>/dev/null | head -5)

    if [ -n "$CONSENSUS" ]; then
        # Create a document in Cortex with proper formatting
        DOC_CONTENT="# Hive-Mind Consensus: $PROJECT_NAME\n\n"
        DOC_CONTENT+="#hive-mind #consensus #auto-sync\n\n"
        DOC_CONTENT+="## Decisions\n\n"

        echo "$CONSENSUS" | while read -r vote; do
            DECISION=$(echo "$vote" | jq -r '.decision // .topic // "unknown"')
            RESULT=$(echo "$vote" | jq -r '.result // .outcome // "pending"')
            DOC_CONTENT+="- **$DECISION**: $RESULT\n"
        done

        # Create in Cortex using SiYuan API
        curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
            -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{
                \"notebook\": \"20251201183343-ujsixib\",
                \"path\": \"/Hive-Mind/$PROJECT_NAME-consensus\",
                \"markdown\": \"$DOC_CONTENT\"
            }" 2>/dev/null

        TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
    fi
done

echo ""
echo "✅ Hive-Mind sync complete: $TOTAL_SYNCED items synced"
