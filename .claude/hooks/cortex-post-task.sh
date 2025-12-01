#!/bin/bash
# Cortex Post-Task Hook - Log completed work to Cortex
# Auto-captures task completion and learnings to SiYuan knowledge base
# Usage: Called automatically after task completion via Claude Code hooks

set -e

TOKEN="0fkvtzw0jrat2oht"
CF_CLIENT_ID="6c0fe301311410aea8ca6e236a176938.access"
CF_CLIENT_SECRET="714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3"
URL="https://cortex.aienablement.academy"

# Arguments
TASK_DESCRIPTION="${1:-Completed task}"
NOTEBOOK_ID="${2:-20251103053911-8ex6uns}"  # Default to Projects notebook (Updated 2025-12-01)

# Generate timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DATE_SLUG=$(date +%Y-%m-%d)

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

# Escape content for JSON
ESCAPED_CONTENT=$(echo "$DOC_CONTENT" | sed 's/"/\\"/g' | tr '\n' ' ')

# Insert document via SiYuan API
INSERT_RESULT=$(curl -s -X POST "${URL}/api/block/insertBlock" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"${ESCAPED_CONTENT}\", \"previousID\": \"\", \"parentID\": \"${NOTEBOOK_ID}\"}")

CODE=$(echo "$INSERT_RESULT" | jq -r '.code')
if [ "$CODE" = "0" ]; then
  BLOCK_ID=$(echo "$INSERT_RESULT" | jq -r '.data[0].doOperations[0].id // "unknown"')
  echo "✅ Task logged to Cortex: ${BLOCK_ID}"
else
  MSG=$(echo "$INSERT_RESULT" | jq -r '.msg // "unknown error"')
  echo "❌ Failed to log task: ${MSG}"
  exit 1
fi
