#!/bin/bash
# Pre-task hook: Load context and prepare for work
# Called before starting any significant task

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TASK_NAME="${1:-Unnamed Task}"
TASK_PRIORITY="${2:-P2}"
TASK_TAGS="${3:-}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_FILE="/tmp/claude-session-${CLAUDE_VARIANT}.json"

echo "=== PRE-TASK HOOK ===" >&2
echo "Agent: $CLAUDE_AGENT_NAME ($CLAUDE_AGENT_EMAIL)" >&2
echo "Task: $TASK_NAME" >&2
echo "Priority: $TASK_PRIORITY" >&2

# Create session tracking file
cat > "$SESSION_FILE" << EOF
{
  "session_id": "$(uuidgen 2>/dev/null || echo "session-$(date +%s)")",
  "agent": "$CLAUDE_VARIANT",
  "agent_email": "$CLAUDE_AGENT_EMAIL",
  "started_at": "$TIMESTAMP",
  "current_task": "$TASK_NAME",
  "priority": "$TASK_PRIORITY",
  "tags": "$TASK_TAGS",
  "actions": [],
  "findings": [],
  "learnings": []
}
EOF

echo "Session file created: $SESSION_FILE" >&2

# Load previous context from memory systems
echo "Loading context from memory systems..." >&2

# 1. Check AgentDB for relevant context
if command -v npx &> /dev/null; then
    echo "  - AgentDB: Loading relevant memories..." >&2
    # npx claude-flow memory_search --pattern "$TASK_NAME" --limit 5 2>/dev/null || true
fi

# 2. Check RuVector for similar past work
echo "  - RuVector: Searching knowledge base..." >&2

# 3. Check Synapse for coordination state
echo "  - Synapse: Loading coordination state..." >&2

echo "Pre-task setup complete." >&2
echo "$SESSION_FILE"
