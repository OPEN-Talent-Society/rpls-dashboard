#!/bin/bash
# Sync AgentDB episodes/patterns to Cortex with proper SiYuan features
# Uses PARA methodology, bi-directional links, and proper tagging
# Uses smart-chunker.py for long content
# Created: 2025-12-02
# Updated: 2025-12-11 - Added upsert logic via cortex-helpers.sh to prevent duplicates

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SMART_CHUNKER="$PROJECT_DIR/.claude/skills/memory-sync/scripts/smart-chunker.py"

# Load cortex-helpers.sh for upsert functionality
CORTEX_HELPERS="$PROJECT_DIR/.claude/lib/cortex-helpers.sh"
if [ ! -f "$CORTEX_HELPERS" ]; then
    echo "❌ ERROR: cortex-helpers.sh not found at $CORTEX_HELPERS"
    exit 1
fi
source "$CORTEX_HELPERS"

# Proper env loading with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# AgentDB path
AGENTDB="$PROJECT_DIR/agentdb.db"

echo "📚 Syncing AgentDB → Cortex (SiYuan)"

if [ ! -f "$AGENTDB" ]; then
    echo "  ⚠️  AgentDB not found at $AGENTDB"
    exit 0
fi

TOTAL_SYNCED=0
TOTAL_SKIPPED=0
TOTAL_UPDATED=0

# NOTE: doc_exists() function now provided by cortex-helpers.sh
# NOTE: upsert_doc() function now provided by cortex-helpers.sh

# Function to chunk long content using smart-chunker.py
# Returns chunked content as JSON array
chunk_content() {
    local CONTENT="$1"
    local CONTENT_TYPE="${2:-text}"
    local PROJECT_NAME="${3:-}"

    # If content is short (< 500 chars), no chunking needed
    if [ ${#CONTENT} -lt 500 ]; then
        echo "$CONTENT"
        return 0
    fi

    # Build metadata
    local METADATA="{}"
    if [ -n "$PROJECT_NAME" ]; then
        METADATA=$(jq -n --arg proj "$PROJECT_NAME" '{project: $proj}')
    fi

    # Call smart-chunker.py
    local CHUNK_RESULT=$(echo "$CONTENT" | jq -n \
        --arg content "$CONTENT" \
        --arg type "$CONTENT_TYPE" \
        --argjson meta "$METADATA" \
        '{content: $content, content_type: $type, metadata: $meta}' | \
        python3 "$SMART_CHUNKER" 2>/dev/null)

    # Check if chunking succeeded
    if echo "$CHUNK_RESULT" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "$CHUNK_RESULT" | jq -r '.chunks'
    else
        # Fallback to original content on error
        echo "$CONTENT"
    fi
}

# Function to upsert a Cortex document with metadata (uses helper library)
upsert_cortex_document() {
    local TITLE="$1"
    local MARKDOWN="$2"
    local DOC_PATH="$3"
    local EPISODE_ID="${4:-}"
    local CHUNK_INDEX="${5:-0}"
    local CHUNK_TOTAL="${6:-1}"

    # Extract project name
    local PROJECT_NAME=$(basename "$PROJECT_DIR" 2>/dev/null || echo "codebuild")

    # Build metadata JSON
    local METADATA=$(jq -n \
        --arg proj "$PROJECT_NAME" \
        --arg episode "$EPISODE_ID" \
        --arg chunk_idx "$CHUNK_INDEX" \
        --arg chunk_tot "$CHUNK_TOTAL" \
        '{
            "custom-type": "learning",
            "custom-project": $proj,
            "custom-episode-id": $episode,
            "custom-chunk-index": $chunk_idx,
            "custom-chunk-total": $chunk_tot
        }')

    # Use upsert_doc from cortex-helpers.sh
    # Args: title, markdown, notebook_id, path, source, metadata_json
    local DOC_ID=$(upsert_doc "$TITLE" "$MARKDOWN" "$NOTEBOOK_RESOURCES" "$DOC_PATH" "agentdb" "$METADATA")

    if [ -n "$DOC_ID" ]; then
        return 0
    fi
    return 1
}

# 1. Sync successful episodes as learnings to Resources
echo ""
echo "📖 Syncing successful episodes as learnings..."

# Use JSON parsing with full content (no truncation)
EPISODES_JSON=$(sqlite3 "$AGENTDB" -json "
SELECT
    id,
    COALESCE(session_id, '') as session_id,
    COALESCE(task, '') as task,
    COALESCE(critique, '') as critique,
    COALESCE(reward, 0) as reward,
    COALESCE(success, 0) as success,
    COALESCE(created_at, '') as created_at
FROM episodes
WHERE success = 1 AND reward >= 0.7
ORDER BY created_at DESC
LIMIT 10;
" 2>/dev/null || echo "[]")

EPISODE_COUNT=$(echo "$EPISODES_JSON" | jq 'length' 2>/dev/null || echo "0")

if [ "$EPISODE_COUNT" -gt 0 ]; then
    echo "$EPISODES_JSON" | jq -c '.[]' | while read -r episode_json; do
        # Extract fields from JSON (safe, no delimiter issues)
        EPISODE_ID=$(echo "$episode_json" | jq -r '.id')
        SESSION_ID=$(echo "$episode_json" | jq -r '.session_id')
        TASK=$(echo "$episode_json" | jq -r '.task')
        REWARD=$(echo "$episode_json" | jq -r '.reward')
        SUCCESS=$(echo "$episode_json" | jq -r '.success')
        CRITIQUE=$(echo "$episode_json" | jq -r '.critique')
        CREATED_AT=$(echo "$episode_json" | jq -r '.created_at')

        # Skip if empty
        [ -z "$TASK" ] && continue

        # Extract project name from working directory if available
        PROJECT_NAME=$(basename "$PROJECT_DIR" 2>/dev/null || echo "codebuild")

        # Create safe document path (max 50 chars for title)
        TASK_TITLE=$(echo "$TASK" | head -c 50)
        SAFE_TASK=$(echo "$TASK_TITLE" | sed 's/[^a-zA-Z0-9 ]//g' | tr ' ' '-')
        DOC_PATH="/AgentDB-Learnings/${SAFE_TASK}-$(date +%Y%m%d)"
        DOC_TITLE="Learning: ${TASK_TITLE}"

        # Note: upsert_cortex_document will handle duplicates (update instead of create)

        # Build full content for chunking analysis
        FULL_CONTENT="# Learning: ${TASK}

#learning #agentdb #auto-sync #reward-${REWARD%.*} #project-${PROJECT_NAME}

## Task Description
${TASK}

## Outcome
- **Reward Score**: ${REWARD}
- **Success**: Yes
- **Session**: ${SESSION_ID}
- **Created**: ${CREATED_AT}
- **Project**: ${PROJECT_NAME}

## Key Insights
${CRITIQUE:-No critique recorded}

## Related
- [[AgentDB Episodes]]
- [[Memory System]]
- [[${PROJECT_NAME}]]

---
*Synced from AgentDB on $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

        # Check if content needs chunking
        if [ ${#FULL_CONTENT} -gt 500 ]; then
            # Use smart chunker for long content
            CHUNKS=$(chunk_content "$FULL_CONTENT" "markdown" "$PROJECT_NAME")

            # Check if chunking was successful (returns array)
            if echo "$CHUNKS" | jq -e 'type == "array"' >/dev/null 2>&1; then
                CHUNK_COUNT=$(echo "$CHUNKS" | jq 'length')

                # Create each chunk as a separate document
                echo "$CHUNKS" | jq -c '.[]' | while read -r chunk_json; do
                    CHUNK_TEXT=$(echo "$chunk_json" | jq -r '.text')
                    CHUNK_INDEX=$(echo "$chunk_json" | jq -r '.index')
                    CHUNK_TOTAL=$(echo "$chunk_json" | jq -r '.total')

                    # Create chunk-specific path
                    CHUNK_PATH="${DOC_PATH}-chunk-$((CHUNK_INDEX + 1))-of-${CHUNK_TOTAL}"

                    # Use chunk text as markdown
                    MARKDOWN="$CHUNK_TEXT

---
**Chunk $((CHUNK_INDEX + 1)) of ${CHUNK_TOTAL}**"

                    CHUNK_TITLE="${DOC_TITLE} (Chunk $((CHUNK_INDEX + 1))/$CHUNK_TOTAL)"

                    # Upsert chunk document
                    upsert_cortex_document "$CHUNK_TITLE" "$MARKDOWN" "$CHUNK_PATH" "$EPISODE_ID" "$CHUNK_INDEX" "$CHUNK_TOTAL"
                done

                echo "  ✅ Synced in ${CHUNK_COUNT} chunks: ${TASK_TITLE}..."
                TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
                continue
            fi
        fi

        # No chunking needed, use full content as markdown
        MARKDOWN="$FULL_CONTENT"

        # Upsert document using helper function
        if upsert_cortex_document "$DOC_TITLE" "$MARKDOWN" "$DOC_PATH" "$EPISODE_ID" 0 1; then
            TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
            echo "  ✅ Synced: ${TASK_TITLE}..."
        fi
    done
else
    echo "  ℹ️  No episodes found to sync"
fi

# 2. Sync patterns to Areas (ongoing reference)
echo ""
echo "🔄 Syncing patterns to Areas..."

# FIXED: Use JSON parsing instead of pipe delimiters
PATTERNS_JSON=$(sqlite3 "$AGENTDB" -json "
SELECT DISTINCT
    REPLACE(REPLACE(task, char(10), ' '), char(13), ' ') as task,
    AVG(reward) as avg_reward,
    COUNT(*) as attempts
FROM episodes
WHERE success = 1
GROUP BY task
HAVING attempts >= 2
ORDER BY avg_reward DESC
LIMIT 5;
" 2>/dev/null || echo "[]")

PATTERN_COUNT=$(echo "$PATTERNS_JSON" | jq 'length' 2>/dev/null || echo "0")

if [ "$PATTERN_COUNT" -gt 0 ]; then
    echo "$PATTERNS_JSON" | jq -c '.[]' | while read -r pattern_json; do
        # Extract fields from JSON (safe, no delimiter issues)
        TASK=$(echo "$pattern_json" | jq -r '.task')
        AVG_REWARD=$(echo "$pattern_json" | jq -r '.avg_reward')
        ATTEMPTS=$(echo "$pattern_json" | jq -r '.attempts')

        [ -z "$TASK" ] && continue

        # Extract project name
        PROJECT_NAME=$(basename "$PROJECT_DIR" 2>/dev/null || echo "codebuild")

        # Create safe document path (max 50 chars for title)
        TASK_TITLE=$(echo "$TASK" | head -c 50)
        SAFE_TASK=$(echo "$TASK_TITLE" | sed 's/[^a-zA-Z0-9 ]//g' | tr ' ' '-')
        DOC_PATH="/AgentDB-Patterns/${SAFE_TASK}"
        DOC_TITLE="Pattern: ${TASK_TITLE}"

        # Note: upsert_doc will handle duplicates (update instead of create)

        # Build full markdown content with project metadata
        MARKDOWN="# Pattern: ${TASK}

#pattern #agentdb #recurring #auto-sync #project-${PROJECT_NAME}

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
| Project | ${PROJECT_NAME} |

## Usage
This pattern can be referenced for similar future tasks.

## Related Patterns
- [[AgentDB Patterns]]
- [[Memory System]]
- [[Learnings Index]]
- [[${PROJECT_NAME}]]

---
*Pattern extracted from AgentDB on $(date -u +%Y-%m-%dT%H:%M:%SZ)*"

        # Build metadata JSON
        PATTERN_METADATA=$(jq -n \
            --arg proj "$PROJECT_NAME" \
            --arg avg_rew "$AVG_REWARD" \
            --arg attempts "$ATTEMPTS" \
            '{
                "custom-type": "pattern",
                "custom-project": $proj,
                "custom-avg-reward": $avg_rew,
                "custom-attempts": $attempts
            }')

        # Upsert pattern document using helper library
        if upsert_doc "$DOC_TITLE" "$MARKDOWN" "$NOTEBOOK_AREAS" "$DOC_PATH" "agentdb" "$PATTERN_METADATA" >/dev/null; then
            TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
            echo "  ✅ Pattern synced: ${TASK_TITLE}..."
        fi
    done
else
    echo "  ℹ️  No patterns found to sync"
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

# Use upsert_doc instead of direct API call to prevent duplicates
INDEX_METADATA=$(jq -n '{"custom-type": "index", "custom-category": "learnings"}')
if upsert_doc "AgentDB Learnings Index" "$LEARNINGS_INDEX" "$NOTEBOOK_RESOURCES" "/AgentDB-Learnings/Index" "agentdb" "$INDEX_METADATA" >/dev/null; then
    echo "  ✅ Learnings Index updated"
fi

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

# Use upsert_doc instead of direct API call to prevent duplicates
INDEX_METADATA=$(jq -n '{"custom-type": "index", "custom-category": "patterns"}')
if upsert_doc "AgentDB Patterns Index" "$PATTERNS_INDEX" "$NOTEBOOK_AREAS" "/AgentDB-Patterns/Index" "agentdb" "$INDEX_METADATA" >/dev/null; then
    echo "  ✅ Patterns Index updated"
fi

echo ""
echo "✅ AgentDB → Cortex sync complete"
echo "   📝 Documents synced: $TOTAL_SYNCED (created or updated)"
echo "   🔄 Using upsert logic - no duplicates created"
