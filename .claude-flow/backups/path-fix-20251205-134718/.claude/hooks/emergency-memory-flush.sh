#!/bin/bash
# Emergency Memory Flush - Full sync before potential data loss
# Call this when context is running low or before major operations
# Created: 2025-12-02
# Purpose: Ensure all hot memory reaches cold storage

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
FLUSH_LOG="/tmp/claude-emergency-flush.log"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] EMERGENCY FLUSH STARTED" >> "$FLUSH_LOG"

# Source environment
source "$PROJECT_DIR/.env" 2>/dev/null || true

# 1. Sync AgentDB episodes to Supabase (BLOCKING - wait for completion)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Syncing AgentDB..." >> "$FLUSH_LOG"
if [ -f "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh" ]; then
    "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh" >> "$FLUSH_LOG" 2>&1 || true
fi

# 2. Sync Swarm Memory patterns to Supabase (BLOCKING)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Syncing Swarm Memory..." >> "$FLUSH_LOG"
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
if [ -f "$SWARM_DB" ]; then
    # Export swarm patterns to Supabase
    PATTERN_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
    echo "  Swarm patterns to sync: $PATTERN_COUNT" >> "$FLUSH_LOG"

    if [ "$PATTERN_COUNT" -gt 0 ]; then
        sqlite3 "$SWARM_DB" "SELECT json_object('id', id, 'type', type, 'data', pattern_data, 'confidence', confidence) FROM patterns;" 2>/dev/null | while read -r pattern; do
            # Transform and send to Supabase
            SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
            SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

            if [ -n "$SUPABASE_KEY" ]; then
                curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
                    -H "apikey: ${SUPABASE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                    -H "Content-Type: application/json" \
                    -H "Prefer: resolution=merge-duplicates" \
                    -d "$pattern" 2>/dev/null || true
            fi
        done
    fi
fi

# 3. Export key memory to JSON backup (BLOCKING)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Creating local backup..." >> "$FLUSH_LOG"
BACKUP_DIR="$PROJECT_DIR/.claude-flow/backups"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/emergency-$(date +%Y%m%d-%H%M%S).json"

# Dump AgentDB to JSON
AGENTDB="$PROJECT_DIR/agentdb.db"
if [ -f "$AGENTDB" ]; then
    sqlite3 "$AGENTDB" "SELECT json_group_array(json_object('id',id,'task',task,'reward',reward,'success',success,'created_at',created_at)) FROM episodes;" > "$BACKUP_FILE" 2>/dev/null || echo "[]" > "$BACKUP_FILE"
fi

# 4. Log completion
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] EMERGENCY FLUSH COMPLETE" >> "$FLUSH_LOG"
echo "  Backup: $BACKUP_FILE" >> "$FLUSH_LOG"

echo "flush_complete"
