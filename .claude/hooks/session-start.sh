#!/bin/bash
# Session start hook: Initialize session, load cross-session memory
# Called at the beginning of each Claude session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID="$(uuidgen 2>/dev/null || echo "session-$(date +%s)")"
MEMORY_DIR="/Users/adamkovacs/Documents/codebuild/.claude/memory"

echo "=== SESSION START ===" >&2
echo "Agent: $CLAUDE_AGENT_NAME ($CLAUDE_VARIANT)" >&2
echo "Session ID: $SESSION_ID" >&2
echo "Started: $TIMESTAMP" >&2

# Create memory directory if needed
mkdir -p "$MEMORY_DIR"

# Create session file
SESSION_FILE="/tmp/claude-session-${CLAUDE_VARIANT}.json"
cat > "$SESSION_FILE" << EOF
{
  "session_id": "$SESSION_ID",
  "agent": "$CLAUDE_VARIANT",
  "agent_email": "$CLAUDE_AGENT_EMAIL",
  "agent_user_id": "$CLAUDE_AGENT_USER_ID",
  "started_at": "$TIMESTAMP",
  "status": "active",
  "tasks": [],
  "actions": [],
  "findings": [],
  "learnings": [],
  "memory_loaded": {}
}
EOF

echo "" >&2
echo "Loading cross-session memory..." >&2

# Load from AgentDB
echo "  [AgentDB] Loading agent memories..." >&2
AGENTDB_CONTEXT="$MEMORY_DIR/agentdb-context.json"
if [ -f "$AGENTDB_CONTEXT" ]; then
    echo "    Found previous AgentDB context" >&2
fi

# Load from RuVector
echo "  [RuVector] Loading knowledge vectors..." >&2
RUVECTOR_CONTEXT="$MEMORY_DIR/ruvector-context.json"
if [ -f "$RUVECTOR_CONTEXT" ]; then
    echo "    Found previous RuVector context" >&2
fi

# Load from Synapse
echo "  [Synapse] Loading coordination state..." >&2
SYNAPSE_STATE="$MEMORY_DIR/synapse-state.json"
if [ -f "$SYNAPSE_STATE" ]; then
    echo "    Found previous Synapse state" >&2
fi

# Load last session summary
LAST_SESSION="$MEMORY_DIR/last-session-${CLAUDE_VARIANT}.json"
if [ -f "$LAST_SESSION" ]; then
    echo "" >&2
    echo "Last session summary:" >&2
    if command -v jq &> /dev/null; then
        jq -r '.summary // "No summary available"' "$LAST_SESSION" >&2
    fi
fi

echo "" >&2
echo "Session initialized. Remember:" >&2
echo "  - Log all actions to NocoDB" >&2
echo "  - Document findings in Cortex" >&2
echo "  - Use full SiYuan features (tags, backlinks, metadata)" >&2
echo "  - Sync learnings to AgentDB/RuVector/Synapse" >&2
echo "" >&2

# Export session info
export CLAUDE_SESSION_ID="$SESSION_ID"
export CLAUDE_SESSION_FILE="$SESSION_FILE"

echo "$SESSION_FILE"
