#!/bin/bash
# NocoDB Task Status Update Hook
# Updates task status in NocoDB

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TASK_ID="${1:-}"
NEW_STATUS="${2:-Done}"
NOTES="${3:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$TASK_ID" ]; then
    echo "Error: Task ID required" >&2
    exit 1
fi

# Output MCP command to execute
cat << EOF
{
  "mcp_tool": "mcp__nocodb-base-ops__updateRecords",
  "parameters": {
    "tableId": "mmx3z4zxdj9ysfk",
    "records": [{
      "id": $TASK_ID,
      "fields": {
        "Status": "$NEW_STATUS",
        "Notes": "$NOTES\n\nUpdated by $CLAUDE_AGENT_NAME at $TIMESTAMP"
      }
    }]
  }
}
EOF
