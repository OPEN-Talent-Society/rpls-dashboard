#!/bin/bash
# Cortex Document Creation Hook
# Creates a document in Cortex/SiYuan with full metadata

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

DOC_TITLE="${1:-Untitled}"
DOC_TYPE="${2:-note}"  # note, learning, task, decision
NOTEBOOK="${3:-resources}"  # projects, areas, resources, archives, agent_logs
DOC_PATH="${4:-}"
CONTENT="${5:-}"
TAGS="${6:-}"
NOCODB_TASK_ID="${7:-}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE=$(date +"%Y-%m-%d")

# Map notebook names to IDs
case "$NOTEBOOK" in
    projects) NOTEBOOK_ID="20231114112233-projects" ;;
    areas) NOTEBOOK_ID="20231114112234-areas" ;;
    resources) NOTEBOOK_ID="20231114112235-resources" ;;
    archives) NOTEBOOK_ID="20231114112236-archives" ;;
    agent_logs) NOTEBOOK_ID="20231114112237-agent-logs" ;;
    *) NOTEBOOK_ID="20231114112235-resources" ;;
esac

# Generate path if not provided
if [ -z "$DOC_PATH" ]; then
    DOC_PATH="$DOC_TYPE/${DATE}/${DOC_TITLE// /-}"
fi

# Generate YAML frontmatter
FRONTMATTER="---
title: $DOC_TITLE
created: $TIMESTAMP
type: $DOC_TYPE
agent: $CLAUDE_VARIANT
agent_email: $CLAUDE_AGENT_EMAIL"

if [ -n "$NOCODB_TASK_ID" ]; then
    FRONTMATTER="$FRONTMATTER
nocodb_task: $NOCODB_TASK_ID"
fi

if [ -n "$TAGS" ]; then
    FRONTMATTER="$FRONTMATTER
tags: [$TAGS]"
fi

FRONTMATTER="$FRONTMATTER
---"

# Build full markdown
FULL_MARKDOWN="$FRONTMATTER

# $DOC_TITLE

$CONTENT

---
*Created by $CLAUDE_AGENT_NAME on $DATE*
#$DOC_TYPE #$CLAUDE_VARIANT #automated"

# Output MCP command
cat << EOF
{
  "mcp_tool": "mcp__cortex__siyuan_create_doc",
  "parameters": {
    "notebook": "$NOTEBOOK_ID",
    "path": "$DOC_PATH",
    "markdown": $(echo "$FULL_MARKDOWN" | jq -Rs .)
  }
}
EOF
