#!/bin/bash
# Memory Store Hook
# Stores data in AgentDB/Claude Flow memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

NAMESPACE="${1:-default}"
KEY="${2:-}"
VALUE="${3:-}"
TTL="${4:-2592000}"  # 30 days default

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [ -z "$KEY" ]; then
    echo "Error: Key required" >&2
    exit 1
fi

# Build memory entry
MEMORY_ENTRY=$(cat << EOF
{
  "content": $(echo "$VALUE" | jq -Rs .),
  "agent": "$CLAUDE_VARIANT",
  "agent_email": "$CLAUDE_AGENT_EMAIL",
  "timestamp": "$TIMESTAMP",
  "namespace": "$NAMESPACE"
}
EOF
)

cat << EOF
{
  "mcp_tool": "mcp__claude-flow__memory_usage",
  "parameters": {
    "action": "store",
    "namespace": "$NAMESPACE",
    "key": "$KEY",
    "value": $(echo "$MEMORY_ENTRY" | jq -c . | jq -Rs .),
    "ttl": $TTL
  }
}
EOF

# === BRIDGE TO LEARNINGS/PATTERNS (Added 2025-12-01) ===
# Trigger the memory-to-learnings bridge to check if this memory
# should also be captured as a learning or pattern
if [ -f "$SCRIPT_DIR/memory-to-learnings-bridge.sh" ]; then
    "$SCRIPT_DIR/memory-to-learnings-bridge.sh" "$KEY" "$VALUE" "$NAMESPACE" 2>/dev/null &
fi
