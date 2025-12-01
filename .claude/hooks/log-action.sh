#!/bin/bash
# Log action hook: Track individual actions during task execution
# Called after each significant action (file edit, command, decision)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

ACTION_TYPE="${1:-action}"  # action, decision, finding, learning, blocker
ACTION_DESC="${2:-No description}"
ACTION_FILE="${3:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_FILE="/tmp/claude-session-${CLAUDE_VARIANT}.json"

# Log to session file
if [ -f "$SESSION_FILE" ] && command -v jq &> /dev/null; then
    NEW_ACTION=$(cat << EOF
{
  "type": "$ACTION_TYPE",
  "description": "$ACTION_DESC",
  "file": "$ACTION_FILE",
  "timestamp": "$TIMESTAMP"
}
EOF
)

    # Append to actions array
    jq --argjson action "$NEW_ACTION" '.actions += [$action]' "$SESSION_FILE" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"
fi

# Also log to stdout for MCP memory storage
echo "{\"agent\": \"$CLAUDE_VARIANT\", \"type\": \"$ACTION_TYPE\", \"desc\": \"$ACTION_DESC\", \"ts\": \"$TIMESTAMP\"}"
