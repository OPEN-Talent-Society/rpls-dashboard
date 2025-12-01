#!/bin/bash
# Memory Search Hook
# Searches AgentDB/Claude Flow memory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

PATTERN="${1:-*}"
NAMESPACE="${2:-default}"
LIMIT="${3:-10}"

cat << EOF
{
  "mcp_tool": "mcp__claude-flow__memory_search",
  "parameters": {
    "pattern": "$PATTERN",
    "namespace": "$NAMESPACE",
    "limit": $LIMIT
  }
}
EOF
