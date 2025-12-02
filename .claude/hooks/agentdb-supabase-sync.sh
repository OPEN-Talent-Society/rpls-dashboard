#!/bin/bash
# AgentDB to Supabase Sync Hook
# Automatically syncs local AgentDB JSON files to Supabase cloud
# Supports learnings, patterns, and agent_memory tables
#
# Usage: ./agentdb-supabase-sync.sh [table] [mode]
#   table: learnings, patterns, or all (default: all)
#   mode: full, incremental (default: incremental)
#
# Created: 2025-12-02 - Automated 3-layer memory sync

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"
AGENTDB_DIR="$SCRIPT_DIR/../.agentdb"

TABLE="${1:-all}"
MODE="${2:-incremental}"

# Load credentials
if [ -f "${CODEBUILD_ROOT}/.env" ]; then
    source "${CODEBUILD_ROOT}/.env"
fi

# Supabase config
SUPABASE_URL="https://zxcrbcmdxpqprpxhsntc.supabase.co"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-sb_secret_g87UniWlZT7GYIQsrWEYYw_VJs7i0Ei}"

log() {
    echo "[$(date '+%H:%M:%S')] $1" >&2
}

# Track last sync timestamp
SYNC_STATE_FILE="/tmp/agentdb-sync-state.json"
get_last_sync() {
    local table="$1"
    if [ -f "$SYNC_STATE_FILE" ]; then
        jq -r --arg t "$table" '.[$t] // "1970-01-01T00:00:00Z"' "$SYNC_STATE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z"
    else
        echo "1970-01-01T00:00:00Z"
    fi
}

update_last_sync() {
    local table="$1"
    local ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    if [ -f "$SYNC_STATE_FILE" ]; then
        jq --arg t "$table" --arg ts "$ts" '.[$t] = $ts' "$SYNC_STATE_FILE" > "${SYNC_STATE_FILE}.tmp" && mv "${SYNC_STATE_FILE}.tmp" "$SYNC_STATE_FILE"
    else
        echo "{\"$table\": \"$ts\"}" > "$SYNC_STATE_FILE"
    fi
}

# Sync learnings to Supabase
sync_learnings() {
    log "Syncing learnings to Supabase..."

    local LEARNINGS_FILE="$AGENTDB_DIR/learnings.json"
    if [ ! -f "$LEARNINGS_FILE" ]; then
        log "No learnings file found"
        return 0
    fi

    local LAST_SYNC=$(get_last_sync "learnings")
    local count=0
    local synced=0

    # Read each entry and sync
    jq -c '.entries[]?' "$LEARNINGS_FILE" 2>/dev/null | while read -r entry; do
        count=$((count + 1))

        # Check if entry is newer than last sync (for incremental)
        if [ "$MODE" = "incremental" ]; then
            ENTRY_TS=$(echo "$entry" | jq -r '.timestamp // "1970-01-01T00:00:00Z"')
            if [[ "$ENTRY_TS" < "$LAST_SYNC" ]]; then
                continue
            fi
        fi

        LEARNING_ID=$(echo "$entry" | jq -r '.id')
        TOPIC=$(echo "$entry" | jq -r '.topic // "Untitled"' | sed "s/'/''/g")
        CATEGORY=$(echo "$entry" | jq -r '.category // "general"')
        CONTENT=$(echo "$entry" | jq -r '.content // ""' | sed "s/'/''/g")
        AGENT=$(echo "$entry" | jq -r '.agent // "claude-code"')
        TAGS=$(echo "$entry" | jq -c '.tags // ["automated"]')

        # Upsert to Supabase via REST API
        RESULT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "{
                \"learning_id\": \"${LEARNING_ID}\",
                \"topic\": \"${TOPIC}\",
                \"category\": \"${CATEGORY}\",
                \"content\": $(echo "$CONTENT" | jq -Rs .),
                \"agent_id\": \"${AGENT}\",
                \"agent_email\": \"claude-code@aienablement.academy\",
                \"tags\": ${TAGS}
            }" 2>&1)

        if ! echo "$RESULT" | grep -q "error"; then
            synced=$((synced + 1))
            echo "  ✅ $LEARNING_ID" >&2
        else
            echo "  ⚠️ $LEARNING_ID: $RESULT" >&2
        fi
    done

    update_last_sync "learnings"
    log "Learnings sync complete (synced new entries)"
}

# Sync patterns to Supabase
sync_patterns() {
    log "Syncing patterns to Supabase..."

    local PATTERNS_FILE="$AGENTDB_DIR/patterns.json"
    if [ ! -f "$PATTERNS_FILE" ]; then
        log "No patterns file found"
        return 0
    fi

    local LAST_SYNC=$(get_last_sync "patterns")
    local count=0
    local synced=0

    jq -c '.patterns[]?' "$PATTERNS_FILE" 2>/dev/null | while read -r entry; do
        count=$((count + 1))

        if [ "$MODE" = "incremental" ]; then
            ENTRY_TS=$(echo "$entry" | jq -r '.timestamp // "1970-01-01T00:00:00Z"')
            if [[ "$ENTRY_TS" < "$LAST_SYNC" ]]; then
                continue
            fi
        fi

        PATTERN_ID=$(echo "$entry" | jq -r '.id // .pattern_id')
        NAME=$(echo "$entry" | jq -r '.name // "Untitled"' | sed "s/'/''/g")
        CATEGORY=$(echo "$entry" | jq -r '.category // "general"')
        DESCRIPTION=$(echo "$entry" | jq -r '.description // ""' | sed "s/'/''/g")
        TEMPLATE=$(echo "$entry" | jq -c '.template // {}')
        USE_CASES=$(echo "$entry" | jq -c '.use_cases // []')

        RESULT=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "{
                \"pattern_id\": \"${PATTERN_ID}\",
                \"name\": \"${NAME}\",
                \"category\": \"${CATEGORY}\",
                \"description\": $(echo "$DESCRIPTION" | jq -Rs .),
                \"template\": ${TEMPLATE},
                \"use_cases\": ${USE_CASES}
            }" 2>&1)

        if ! echo "$RESULT" | grep -q "error"; then
            synced=$((synced + 1))
            echo "  ✅ $PATTERN_ID" >&2
        else
            echo "  ⚠️ $PATTERN_ID: $RESULT" >&2
        fi
    done

    update_last_sync "patterns"
    log "Patterns sync complete (synced new entries)"
}

# Main execution
log "=== AGENTDB → SUPABASE SYNC ==="
log "Mode: $MODE | Table: $TABLE"

case "$TABLE" in
    learnings)
        sync_learnings
        ;;
    patterns)
        sync_patterns
        ;;
    all)
        sync_learnings
        sync_patterns
        ;;
    *)
        log "Unknown table: $TABLE"
        exit 1
        ;;
esac

log "=== SYNC COMPLETE ==="
