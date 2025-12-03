#!/bin/bash
# Memory Sync Hook - Auto-sync on pattern storage
# Triggered by PostToolUse on agentdb_pattern_store

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SCRIPT_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts"
LOG_FILE="$PROJECT_DIR/.claude-flow/metrics/memory-sync.log"

# Parse hook input
HOOK_INPUT="$1"
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only sync on pattern storage
if [ "$TOOL_NAME" != "agentdb_pattern_store" ]; then
    exit 0
fi

# Log sync trigger
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Memory sync triggered by $TOOL_NAME" >> "$LOG_FILE"

# Async sync to Supabase (non-blocking)
nohup "$SCRIPT_DIR/sync-agentdb-to-supabase.sh" >> "$LOG_FILE" 2>&1 &

# Return success immediately
exit 0
