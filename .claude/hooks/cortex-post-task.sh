#!/bin/bash

# Cortex Post-Task Hook - Log completed work to Cortex
# Auto-captures task completion and learnings to SiYuan knowledge base
# Usage: Called automatically after task completion via Claude Code hooks
# FIXED: Now uses upsert logic to prevent duplicate task logs

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load .env with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Source cortex helpers library for upsert logic
LIB_DIR="${PROJECT_DIR}/.claude/lib"
if [ -f "${LIB_DIR}/cortex-helpers.sh" ]; then
    source "${LIB_DIR}/cortex-helpers.sh"
else
    echo "❌ Error: cortex-helpers.sh not found at ${LIB_DIR}/cortex-helpers.sh"
    exit 1
fi

# Arguments
TASK_DESCRIPTION="${1:-Completed task}"
NOTEBOOK_NAME="${2:-projects}"  # Default to Projects notebook

# Generate timestamp and identifiers
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE_SLUG=$(date +%Y-%m-%d)
TASK_TITLE="Task: ${TASK_DESCRIPTION}"
DOC_PATH="/${DATE_SLUG}-task-${TASK_DESCRIPTION//[^a-zA-Z0-9]/-}"

# Create document content
DOC_CONTENT="# Task: ${TASK_DESCRIPTION}

**Completed:** ${TIMESTAMP}
**Status:** ✅ Done

## Summary

${TASK_DESCRIPTION}

## Key Learnings

- [Add learnings here]

## Related Documents

- [[Projects]]

---
*Auto-logged by cortex-post-task hook*
"

# Resolve notebook ID from name
NOTEBOOK_ID=$(resolve_notebook_id "$NOTEBOOK_NAME")

# Build metadata directly (avoid nested jq issues)
METADATA=$(jq -n \
    --arg task "$TASK_DESCRIPTION" \
    --arg ts "$TIMESTAMP" \
    '{
        "custom-source": "cortex-post-task",
        "custom-synced": $ts,
        "custom-version": "1",
        "custom-type": "task-log",
        "custom-project": "codebuild",
        "custom-task-description": $task,
        "custom-completed-at": $ts,
        "custom-status": "completed"
    }')

# Upsert document (update if exists, create if not)
DOC_ID=$(upsert_doc "$TASK_TITLE" "$DOC_CONTENT" "$NOTEBOOK_ID" "$DOC_PATH" "cortex-post-task" "$METADATA")

if [ -n "$DOC_ID" ]; then
    echo "✅ Task logged to Cortex: ${DOC_ID}"
    echo "   Title: ${TASK_TITLE}"
    echo "   Notebook: ${NOTEBOOK_NAME} (${NOTEBOOK_ID})"
else
    echo "❌ Failed to log task to Cortex"
    exit 1
fi
