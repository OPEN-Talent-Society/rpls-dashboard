#!/bin/bash
# Post-Error Hook: Log errors with resolutions to prevent recurrence
# Implements "Don't make the same mistake twice" principle

ERROR_CATEGORY="$1"
ERROR_MESSAGE="$2"
RESOLUTION="$3"
PREVENTION="${4:-}"
RELATED_FILES="${5:-}"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
ERROR_ID=$(echo "${ERROR_CATEGORY}:${ERROR_MESSAGE}" | md5 | cut -c1-12)

# Store in AgentDB for cross-session memory
pnpm dlx claude-flow memory store \
  --namespace "errors" \
  --key "errors/${ERROR_CATEGORY}/${ERROR_ID}" \
  --value "{
    \"id\": \"$ERROR_ID\",
    \"category\": \"$ERROR_CATEGORY\",
    \"error\": \"$ERROR_MESSAGE\",
    \"resolution\": \"$RESOLUTION\",
    \"prevention\": \"$PREVENTION\",
    \"related_files\": \"$RELATED_FILES\",
    \"timestamp\": \"$TIMESTAMP\",
    \"agent\": \"${CLAUDE_VARIANT:-claude-code}\",
    \"agent_email\": \"${CLAUDE_AGENT_EMAIL:-claude-code@aienablement.academy}\"
  }"

echo "Error logged: errors/${ERROR_CATEGORY}/${ERROR_ID}"

# Also create a Cortex learning document for human visibility
if [ -n "$PREVENTION" ]; then
  CORTEX_CONTENT=$(cat <<EOF
---
title: "Error Resolution - ${ERROR_CATEGORY}"
created: ${TIMESTAMP}
type: error-resolution
agent: ${CLAUDE_VARIANT:-claude-code}
tags: [error, ${ERROR_CATEGORY}, resolution, prevention]
---

# Error: ${ERROR_MESSAGE}

## Category
${ERROR_CATEGORY}

## Resolution
${RESOLUTION}

## Prevention
${PREVENTION}

## Related Files
${RELATED_FILES}

## Metadata
- **Error ID**: ${ERROR_ID}
- **Agent**: ${CLAUDE_VARIANT:-claude-code}
- **Logged**: ${TIMESTAMP}

#error #${ERROR_CATEGORY} #prevention #automated
EOF
)

  echo "Creating Cortex error resolution document..."
  # This would call the Cortex API to create the document
fi
