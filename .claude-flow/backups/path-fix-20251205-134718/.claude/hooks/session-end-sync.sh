#!/bin/bash
# Session End Sync Hook - Full sync on session end
# Triggered by Stop hook

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SCRIPT_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts"
LOG_FILE="$PROJECT_DIR/.claude-flow/metrics/memory-sync.log"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Session end - running full memory sync" >> "$LOG_FILE"

# Full sync (runs in background to not block session end)
nohup bash -c "
    '$SCRIPT_DIR/sync-agentdb-to-supabase.sh' >> '$LOG_FILE' 2>&1
    '$SCRIPT_DIR/sync-to-cortex.sh' >> '$LOG_FILE' 2>&1
    '$SCRIPT_DIR/index-to-ruvector.sh' >> '$LOG_FILE' 2>&1
" &

exit 0
