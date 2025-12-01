#!/bin/bash
# Cortex Learning Log Hook
# Logs a learning to Cortex with proper structure

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TOPIC="${1:-Untitled Learning}"
CONTEXT="${2:-}"
DISCOVERY="${3:-}"
INSIGHTS="${4:-}"
CATEGORY="${5:-general}"
RELATED="${6:-}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +"%Y-%m-%d")
DOC_PATH="Learnings/${DATE}/${TOPIC// /-}"

MARKDOWN="---
title: Learning - $TOPIC
created: $TIMESTAMP
type: learning
agent: $CLAUDE_VARIANT
category: $CATEGORY
tags: [learning, $CATEGORY, $CLAUDE_VARIANT]
---

# $TOPIC

## Context
$CONTEXT

## Discovery
$DISCOVERY

## Key Insights
$INSIGHTS

## Related
$RELATED

## Tags
#learning #$CATEGORY #$CLAUDE_VARIANT #automated

---
*Logged by $CLAUDE_AGENT_NAME on $DATE*
{: custom-agent=\"$CLAUDE_VARIANT\" custom-type=\"learning\" custom-category=\"$CATEGORY\" }"

cat << EOF
{
  "mcp_tool": "mcp__cortex__siyuan_create_doc",
  "parameters": {
    "notebook": "20251201183343-ujsixib",
    "path": "$DOC_PATH",
    "markdown": $(echo "$MARKDOWN" | jq -Rs .)
  }
}
EOF
