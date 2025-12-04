#!/bin/bash
# Sync AgentDB episodes/patterns to Cortex with proper SiYuan features
# Uses PARA methodology, bi-directional links, and proper tagging
# Created: 2025-12-02

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Cortex config
SIYUAN_BASE_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${CORTEX_TOKEN}"

# Cloudflare Zero Trust (required for Cortex access)
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"

# PARA Notebooks (Cortex)
NOTEBOOK_PROJECTS="20251103053911-8ex6uns"     # 01 Projects
NOTEBOOK_AREAS="20251201183343-543piyt"        # 02 Areas
NOTEBOOK_RESOURCES="20251201183343-ujsixib"    # 03 Resources - for learnings
NOTEBOOK_ARCHIVES="20251201183343-xf2snc8"     # 04 Archives
NOTEBOOK_KB="20251103053840-moamndp"           # 05 Knowledge Base
NOTEBOOK_AGENTS="20251103053916-bq6qbgu"       # 06 Agents

# AgentDB path
AGENTDB="$PROJECT_DIR/agentdb.db"

echo "📚 Syncing AgentDB → Cortex (SiYuan)"

if [ ! -f "$AGENTDB" ]; then
    echo "  ⚠️  AgentDB not found at $AGENTDB"
    exit 0
fi

TOTAL_SYNCED=0
TOTAL_SKIPPED=0

# Function to check if document already exists in Cortex
# Returns 0 if exists (skip), 1 if not exists (create)
doc_exists_in_cortex() {
    local SEARCH_TITLE="$1"
    local SEARCH_SOURCE="$2"

    # Search for existing document with same title and source attribute
    local SEARCH_RESULT=$(curl -s -X POST "${SIYUAN_BASE_URL}/api/search/fullTextSearchBlock" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg q "$SEARCH_TITLE" '{query: $q}')" 2>/dev/null)

    # Check if we found a match with custom-source=agentdb attribute
    if echo "$SEARCH_RESULT" | jq -e '.data.blocks[] | select(.ial."custom-source" == "'"$SEARCH_SOURCE"'")' >/dev/null 2>&1; then
        return 0  # Exists, skip
    fi
    return 1  # Doesn't exist, create
}

# 1. Sync successful episodes as learnings to Resources
echo ""
echo "📖 Syncing successful episodes as learnings..."

EPISODES=$(sqlite3 "$AGENTDB" "SELECT session_id, task, reward, success, critique FROM episodes WHERE success = 1 AND reward >= 0.7 ORDER BY created_at DESC LIMIT 10;" 2>/dev/null)

if [ -n "$EPISODES" ]; then
    echo "$EPISODES" | while IFS='|' read -r SESSION_ID TASK REWARD SUCCESS CRITIQUE; do
        # Skip if empty
        [ -z "$TASK" ] && continue

        # Create safe document path
        SAFE_TASK=$(echo "$TASK" | sed 's/[^a-zA-Z0-9 ]//g' | head -c 50 | tr ' ' '-')
        DOC_PATH="/AgentDB-Learnings/${SAFE_TASK}-$(date +%Y%m%d)"

        # CHECK FOR DUPLICATES: Skip if already synced
        if doc_exists_in_cortex "${SAFE_TASK}" "agentdb"; then
            echo "  ⏭️  Skipped (exists): ${TASK:0:40}..."
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
            continue
        fi

        # Build markdown with proper SiYuan features
        MARKDOWN="# Learning: ${TASK:0:80}

#learning #agentdb #auto-sync #reward-${REWARD%.*}

## Task Description
${TASK}

## Outcome
- **Reward Score**: ${REWARD}
- **Success**: Yes
- **Session**: ${SESSION_ID}

## Key Insights
${CRITIQUE:-No critique recorded}

## Related
- [[AgentDB Episodes]]
- [[Memory System]]

---
*Synced from AgentDB on $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

        # Create document in Cortex
        RESPONSE=$(curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
            -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "$(jq -n \
                --arg nb "$NOTEBOOK_RESOURCES" \
                --arg path "$DOC_PATH" \
                --arg md "$MARKDOWN" \
                '{notebook: $nb, path: $path, markdown: $md}')" 2>&1)

        if echo "$RESPONSE" | jq -e '.code == 0' >/dev/null 2>&1; then
            DOC_ID=$(echo "$RESPONSE" | jq -r '.data // ""')
            TOTAL_SYNCED=$((TOTAL_SYNCED + 1))

            # Add attributes/tags to the document
            if [ -n "$DOC_ID" ]; then
                curl -s -X POST "${SIYUAN_BASE_URL}/api/attr/setBlockAttrs" \
                    -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
                    -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
                    -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
                    -H "Content-Type: application/json" \
                    -d "$(jq -n \
                        --arg id "$DOC_ID" \
                        '{id: $id, attrs: {
                            "custom-source": "agentdb",
                            "custom-type": "learning",
                            "custom-reward": "'"$REWARD"'",
                            "custom-synced": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
                        }}')" 2>/dev/null
            fi

            echo "  ✅ Synced: ${TASK:0:40}..."
        fi
    done
fi

# 2. Sync patterns to Areas (ongoing reference)
echo ""
echo "🔄 Syncing patterns to Areas..."

PATTERNS=$(sqlite3 "$AGENTDB" "SELECT DISTINCT task, AVG(reward) as avg_reward, COUNT(*) as attempts FROM episodes WHERE success = 1 GROUP BY task HAVING attempts >= 2 ORDER BY avg_reward DESC LIMIT 5;" 2>/dev/null)

if [ -n "$PATTERNS" ]; then
    echo "$PATTERNS" | while IFS='|' read -r TASK AVG_REWARD ATTEMPTS; do
        [ -z "$TASK" ] && continue

        SAFE_TASK=$(echo "$TASK" | sed 's/[^a-zA-Z0-9 ]//g' | head -c 50 | tr ' ' '-')
        DOC_PATH="/AgentDB-Patterns/${SAFE_TASK}"

        # CHECK FOR DUPLICATES: Skip if pattern already synced
        if doc_exists_in_cortex "Pattern: ${SAFE_TASK}" "agentdb"; then
            echo "  ⏭️  Skipped pattern (exists): ${TASK:0:40}..."
            TOTAL_SKIPPED=$((TOTAL_SKIPPED + 1))
            continue
        fi

        MARKDOWN="# Pattern: ${TASK:0:80}

#pattern #agentdb #recurring #auto-sync

## Pattern Summary
This task pattern has been completed **${ATTEMPTS} times** with an average reward of **${AVG_REWARD}**.

## Task
${TASK}

## Statistics
| Metric | Value |
|--------|-------|
| Attempts | ${ATTEMPTS} |
| Avg Reward | ${AVG_REWARD} |
| Status | Recurring Success |

## Usage
This pattern can be referenced for similar future tasks.

## Related Patterns
- [[AgentDB Patterns]]
- [[Memory System]]
- [[Learnings Index]]

---
*Pattern extracted from AgentDB on $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

        RESPONSE=$(curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
            -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "$(jq -n \
                --arg nb "$NOTEBOOK_AREAS" \
                --arg path "$DOC_PATH" \
                --arg md "$MARKDOWN" \
                '{notebook: $nb, path: $path, markdown: $md}')" 2>&1)

        if echo "$RESPONSE" | jq -e '.code == 0' >/dev/null 2>&1; then
            TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
            echo "  ✅ Pattern synced: ${TASK:0:40}..."
        fi
    done
fi

# 3. Create index documents for navigation
echo ""
echo "📑 Creating/updating index documents..."

# Learnings Index
LEARNINGS_INDEX="# AgentDB Learnings Index

#index #agentdb #learnings

## Overview
This index contains all learnings extracted from AgentDB episodes.

## Recent Learnings
$(sqlite3 "$AGENTDB" "SELECT '- [[' || substr(task, 1, 50) || ']] (reward: ' || reward || ')' FROM episodes WHERE success = 1 ORDER BY created_at DESC LIMIT 10;" 2>/dev/null)

## Categories
- High-reward tasks (0.9+)
- Standard tasks (0.7-0.9)
- Learning opportunities (< 0.7)

## Related
- [[AgentDB Patterns]]
- [[Memory System SOP]]

---
*Last updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
    -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg nb "$NOTEBOOK_RESOURCES" \
        --arg path "/AgentDB-Learnings/Index" \
        --arg md "$LEARNINGS_INDEX" \
        '{notebook: $nb, path: $path, markdown: $md}')" 2>/dev/null

# Patterns Index
PATTERNS_INDEX="# AgentDB Patterns Index

#index #agentdb #patterns

## Overview
Recurring successful task patterns from AgentDB.

## Top Patterns by Success Rate
$(sqlite3 "$AGENTDB" "SELECT '- [[' || substr(task, 1, 50) || ']] (' || COUNT(*) || ' attempts, avg: ' || printf('%.2f', AVG(reward)) || ')' FROM episodes WHERE success = 1 GROUP BY task HAVING COUNT(*) >= 2 ORDER BY AVG(reward) DESC LIMIT 10;" 2>/dev/null)

## Usage
Reference these patterns when approaching similar tasks.

## Related
- [[AgentDB Learnings Index]]
- [[Memory System SOP]]

---
*Last updated: $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
    -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
        --arg nb "$NOTEBOOK_AREAS" \
        --arg path "/AgentDB-Patterns/Index" \
        --arg md "$PATTERNS_INDEX" \
        '{notebook: $nb, path: $path, markdown: $md}')" 2>/dev/null

echo ""
echo "✅ AgentDB → Cortex sync complete"
echo "   📝 New items synced: $TOTAL_SYNCED"
echo "   ⏭️  Duplicates skipped: $TOTAL_SKIPPED"
