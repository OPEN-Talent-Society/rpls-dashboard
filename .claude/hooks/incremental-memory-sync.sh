#!/bin/bash
# Incremental Memory Sync - Runs periodically during session
# Triggered by PostToolUse counter or time-based checks
# Created: 2025-12-02
# Purpose: Prevent data loss from context compaction

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SYNC_STATE_FILE="/tmp/claude-memory-sync-state"
SYNC_LOCK_FILE="/tmp/claude-memory-sync.lock"
SYNC_LOG="/tmp/claude-memory-sync.log"

# Config
SYNC_EVERY_N_CALLS=30      # Sync every N tool calls
SYNC_EVERY_N_SECONDS=300   # Or every 5 minutes, whichever comes first
MIN_SECONDS_BETWEEN_SYNC=60 # Don't sync more often than this

# Use file locking to prevent race conditions from parallel hook invocations
# macOS-compatible: use mkdir as atomic lock operation
if ! mkdir "$SYNC_LOCK_FILE" 2>/dev/null; then
    # Check if lock is stale (older than 30 seconds)
    if [ -d "$SYNC_LOCK_FILE" ]; then
        LOCK_AGE=$(( $(date +%s) - $(stat -f %m "$SYNC_LOCK_FILE" 2>/dev/null || echo "0") ))
        if [ "$LOCK_AGE" -gt 30 ]; then
            rm -rf "$SYNC_LOCK_FILE"
            mkdir "$SYNC_LOCK_FILE" 2>/dev/null || { echo "locked"; exit 0; }
        else
            echo "locked"
            exit 0
        fi
    fi
fi
# Clean up lock on exit
trap "rm -rf '$SYNC_LOCK_FILE'" EXIT

# Initialize state if not exists
if [ ! -f "$SYNC_STATE_FILE" ]; then
    echo '{"call_count":0,"last_sync":0}' > "$SYNC_STATE_FILE"
fi

# Read current state
CALL_COUNT=$(jq -r '.call_count // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")
LAST_SYNC=$(jq -r '.last_sync // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")
NOW=$(date +%s)

# Increment call count
CALL_COUNT=$((CALL_COUNT + 1))

# Check if we should sync
SHOULD_SYNC=false
SYNC_REASON=""

# Time since last sync
TIME_SINCE_SYNC=$((NOW - LAST_SYNC))

# Condition 1: Every N calls
if [ $((CALL_COUNT % SYNC_EVERY_N_CALLS)) -eq 0 ]; then
    if [ "$TIME_SINCE_SYNC" -ge "$MIN_SECONDS_BETWEEN_SYNC" ]; then
        SHOULD_SYNC=true
        SYNC_REASON="call_count_threshold ($CALL_COUNT calls)"
    fi
fi

# Condition 2: Time threshold
if [ "$TIME_SINCE_SYNC" -ge "$SYNC_EVERY_N_SECONDS" ]; then
    SHOULD_SYNC=true
    SYNC_REASON="time_threshold (${TIME_SINCE_SYNC}s since last sync)"
fi

# Update state
jq -n --argjson count "$CALL_COUNT" --argjson last "$LAST_SYNC" \
    '{call_count: $count, last_sync: $last}' > "$SYNC_STATE_FILE"

if [ "$SHOULD_SYNC" = true ]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Incremental sync triggered: $SYNC_REASON" >> "$SYNC_LOG"

    # Update last sync time
    jq -n --argjson count "$CALL_COUNT" --argjson last "$NOW" \
        '{call_count: $count, last_sync: $last}' > "$SYNC_STATE_FILE"

    # Run sync in background (non-blocking)
    (
        # Sync AgentDB to Supabase (incremental - only new records)
        if [ -f "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh" ]; then
            "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh" --incremental >> "$SYNC_LOG" 2>&1
        fi

        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Incremental sync complete" >> "$SYNC_LOG"
    ) &

    echo "sync_triggered"
else
    echo "no_sync_needed"
fi
