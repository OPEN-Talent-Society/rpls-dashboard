#!/bin/bash
# NocoDB Task Creation Hook
# Creates a task in NocoDB with proper agent assignment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TASK_NAME="${1:-Unnamed Task}"
DESCRIPTION="${2:-}"
PRIORITY="${3:-P2}"
TAGS="${4:-automated}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Output MCP command to execute
cat << EOF
{
  "mcp_tool": "mcp__nocodb-base-ops__createRecords",
  "parameters": {
    "tableId": "mmx3z4zxdj9ysfk",
    "records": [{
      "fields": {
        "task name": "$TASK_NAME",
        "Description": "$DESCRIPTION",
        "Status": "In Progress",
        "Priority": "$PRIORITY",
        "Assignee": [{"id": "$CLAUDE_AGENT_USER_ID", "email": "$CLAUDE_AGENT_EMAIL"}],
        "Tags": "$TAGS, $CLAUDE_VARIANT",
        "Created": "$TIMESTAMP"
      }
    }]
  }
}
EOF
