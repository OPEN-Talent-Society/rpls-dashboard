#!/bin/bash

# Weekly Memory Cleanup Script
# Cleans old telemetry, prunes old episodes, vacuums databases, and runs deduplication
#
# Usage:
#   ./weekly-cleanup.sh           # Execute cleanup
#   ./weekly-cleanup.sh --dry-run # Show what would be cleaned without executing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs"
LOG_FILE="${LOG_DIR}/weekly-cleanup-$(date +%Y%m%d-%H%M%S).log"
AGENTDB_PATH="${SCRIPT_DIR}/../../../agentdb.db"
SWARM_DB_PATH="${SCRIPT_DIR}/../../../.swarm/memory.db"

# Retention policies (days)
TELEMETRY_RETENTION_DAYS=7
EPISODE_RETENTION_DAYS=90

# Dry run mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Statistics tracker
declare -A STATS=(
    [telemetry_deleted]=0
    [episodes_deleted]=0
    [agentdb_size_before]=0
    [agentdb_size_after]=0
    [swarm_size_before]=0
    [swarm_size_after]=0
    [dedup_patterns]=0
    [dedup_learnings]=0
)

# Get database size in bytes
get_db_size() {
    local db_path="$1"
    if [[ -f "$db_path" ]]; then
        stat -f%z "$db_path" 2>/dev/null || stat -c%s "$db_path" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Format bytes to human readable
format_bytes() {
    local bytes=$1
    if ((bytes < 1024)); then
        echo "${bytes}B"
    elif ((bytes < 1048576)); then
        echo "$((bytes / 1024))KB"
    elif ((bytes < 1073741824)); then
        echo "$((bytes / 1048576))MB"
    else
        echo "$((bytes / 1073741824))GB"
    fi
}

# Load Supabase credentials
load_supabase_creds() {
    local env_file="${SCRIPT_DIR}/../../../.env"

    if [[ ! -f "$env_file" ]]; then
        log "ERROR" "Missing .env file at $env_file"
        return 1
    fi

    # shellcheck disable=SC1090
    source "$env_file"

    if [[ -z "${SUPABASE_URL:-}" ]] || [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
        log "ERROR" "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY in .env"
        return 1
    fi

    return 0
}

# Clean operations telemetry older than 7 days
cleanup_telemetry() {
    log "INFO" "Cleaning operations_telemetry older than $TELEMETRY_RETENTION_DAYS days..."

    if ! load_supabase_creds; then
        return 1
    fi

    local cutoff_date
    cutoff_date=$(date -u -v-${TELEMETRY_RETENTION_DAYS}d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "${TELEMETRY_RETENTION_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ')

    # Count records to delete
    local count_query="select=count&timestamp=lt.${cutoff_date}"
    local count_response
    count_response=$(curl -s -G \
        "${SUPABASE_URL}/rest/v1/operations_telemetry" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        --data-urlencode "$count_query")

    local count
    count=$(echo "$count_response" | jq -r '.[0].count // 0' 2>/dev/null || echo "0")

    log "INFO" "Found $count telemetry records older than $cutoff_date"
    STATS[telemetry_deleted]=$count

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would delete $count telemetry records"
        return 0
    fi

    if [[ $count -gt 0 ]]; then
        # Delete in batches of 1000
        local deleted=0
        while [[ $deleted -lt $count ]]; do
            curl -s -X DELETE \
                "${SUPABASE_URL}/rest/v1/operations_telemetry?timestamp=lt.${cutoff_date}&limit=1000" \
                -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
                -H "Prefer: return=minimal" >/dev/null

            deleted=$((deleted + 1000))
            log "INFO" "Deleted batch (progress: $deleted/$count)"
        done

        log "INFO" "Successfully deleted $count telemetry records"
    fi
}

# Prune old episode patterns from Supabase
cleanup_old_episodes() {
    log "INFO" "Pruning agent_episode patterns older than $EPISODE_RETENTION_DAYS days..."

    if ! load_supabase_creds; then
        return 1
    fi

    local cutoff_date
    cutoff_date=$(date -u -v-${EPISODE_RETENTION_DAYS}d '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || date -u -d "${EPISODE_RETENTION_DAYS} days ago" '+%Y-%m-%dT%H:%M:%SZ')

    # Count records to delete
    local count_query="select=count&category=eq.agent_episode&created_at=lt.${cutoff_date}"
    local count_response
    count_response=$(curl -s -G \
        "${SUPABASE_URL}/rest/v1/agent_patterns" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        --data-urlencode "$count_query")

    local count
    count=$(echo "$count_response" | jq -r '.[0].count // 0' 2>/dev/null || echo "0")

    log "INFO" "Found $count old episode patterns older than $cutoff_date"
    STATS[episodes_deleted]=$count

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would delete $count episode patterns"
        return 0
    fi

    if [[ $count -gt 0 ]]; then
        # Delete in batches of 1000
        local deleted=0
        while [[ $deleted -lt $count ]]; do
            curl -s -X DELETE \
                "${SUPABASE_URL}/rest/v1/agent_patterns?category=eq.agent_episode&created_at=lt.${cutoff_date}&limit=1000" \
                -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
                -H "Prefer: return=minimal" >/dev/null

            deleted=$((deleted + 1000))
            log "INFO" "Deleted batch (progress: $deleted/$count)"
        done

        log "INFO" "Successfully deleted $count episode patterns"
    fi
}

# Vacuum AgentDB to reclaim space
vacuum_agentdb() {
    log "INFO" "Vacuuming AgentDB to reclaim space..."

    if [[ ! -f "$AGENTDB_PATH" ]]; then
        log "WARN" "AgentDB not found at $AGENTDB_PATH"
        return 0
    fi

    STATS[agentdb_size_before]=$(get_db_size "$AGENTDB_PATH")
    local size_before_human
    size_before_human=$(format_bytes "${STATS[agentdb_size_before]}")
    log "INFO" "AgentDB size before vacuum: $size_before_human"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would vacuum AgentDB"
        return 0
    fi

    sqlite3 "$AGENTDB_PATH" "VACUUM;" 2>&1 | tee -a "$LOG_FILE"

    STATS[agentdb_size_after]=$(get_db_size "$AGENTDB_PATH")
    local size_after_human
    size_after_human=$(format_bytes "${STATS[agentdb_size_after]}")
    local size_saved=$((STATS[agentdb_size_before] - STATS[agentdb_size_after]))
    local size_saved_human
    size_saved_human=$(format_bytes "$size_saved")

    log "INFO" "AgentDB size after vacuum: $size_after_human (saved: $size_saved_human)"
}

# Vacuum Swarm DB to reclaim space
vacuum_swarm_db() {
    log "INFO" "Vacuuming Swarm DB to reclaim space..."

    if [[ ! -f "$SWARM_DB_PATH" ]]; then
        log "WARN" "Swarm DB not found at $SWARM_DB_PATH"
        return 0
    fi

    STATS[swarm_size_before]=$(get_db_size "$SWARM_DB_PATH")
    local size_before_human
    size_before_human=$(format_bytes "${STATS[swarm_size_before]}")
    log "INFO" "Swarm DB size before vacuum: $size_before_human"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would vacuum Swarm DB"
        return 0
    fi

    sqlite3 "$SWARM_DB_PATH" "VACUUM;" 2>&1 | tee -a "$LOG_FILE"

    STATS[swarm_size_after]=$(get_db_size "$SWARM_DB_PATH")
    local size_after_human
    size_after_human=$(format_bytes "${STATS[swarm_size_after]}")
    local size_saved=$((STATS[swarm_size_before] - STATS[swarm_size_after]))
    local size_saved_human
    size_saved_human=$(format_bytes "$size_saved")

    log "INFO" "Swarm DB size after vacuum: $size_after_human (saved: $size_saved_human)"
}

# Run deduplication scripts
run_deduplication() {
    log "INFO" "Running deduplication scripts..."

    local dedup_agentdb="${SCRIPT_DIR}/dedup-agentdb.sh"
    local dedup_supabase="${SCRIPT_DIR}/dedup-supabase-learnings.sh"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "[DRY-RUN] Would run dedup-agentdb.sh and dedup-supabase-learnings.sh"
        return 0
    fi

    # Run AgentDB deduplication
    if [[ -f "$dedup_agentdb" ]]; then
        log "INFO" "Running dedup-agentdb.sh..."
        if bash "$dedup_agentdb" 2>&1 | tee -a "$LOG_FILE"; then
            # Try to extract dedup count from output (if script outputs it)
            STATS[dedup_patterns]=0
            log "INFO" "AgentDB deduplication completed"
        else
            log "WARN" "AgentDB deduplication failed or not available"
        fi
    else
        log "WARN" "dedup-agentdb.sh not found at $dedup_agentdb"
    fi

    # Run Supabase learnings deduplication
    if [[ -f "$dedup_supabase" ]]; then
        log "INFO" "Running dedup-supabase-learnings.sh..."
        if bash "$dedup_supabase" 2>&1 | tee -a "$LOG_FILE"; then
            # Try to extract dedup count from output (if script outputs it)
            STATS[dedup_learnings]=0
            log "INFO" "Supabase learnings deduplication completed"
        else
            log "WARN" "Supabase learnings deduplication failed or not available"
        fi
    else
        log "WARN" "dedup-supabase-learnings.sh not found at $dedup_supabase"
    fi
}

# Print cleanup statistics
print_statistics() {
    log "INFO" "========================================="
    log "INFO" "Weekly Memory Cleanup Statistics"
    log "INFO" "========================================="

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "MODE: DRY RUN (no changes made)"
    else
        log "INFO" "MODE: EXECUTION (changes applied)"
    fi

    log "INFO" ""
    log "INFO" "Data Cleanup:"
    log "INFO" "  - Telemetry records deleted: ${STATS[telemetry_deleted]}"
    log "INFO" "  - Episode patterns pruned: ${STATS[episodes_deleted]}"
    log "INFO" "  - Patterns deduplicated: ${STATS[dedup_patterns]}"
    log "INFO" "  - Learnings deduplicated: ${STATS[dedup_learnings]}"

    log "INFO" ""
    log "INFO" "Space Reclaimed:"

    if [[ "${STATS[agentdb_size_before]}" -gt 0 ]]; then
        local agentdb_saved=$((STATS[agentdb_size_before] - STATS[agentdb_size_after]))
        local agentdb_saved_human
        agentdb_saved_human=$(format_bytes "$agentdb_saved")
        log "INFO" "  - AgentDB: $(format_bytes "${STATS[agentdb_size_before]}") -> $(format_bytes "${STATS[agentdb_size_after]}") (saved: $agentdb_saved_human)"
    fi

    if [[ "${STATS[swarm_size_before]}" -gt 0 ]]; then
        local swarm_saved=$((STATS[swarm_size_before] - STATS[swarm_size_after]))
        local swarm_saved_human
        swarm_saved_human=$(format_bytes "$swarm_saved")
        log "INFO" "  - Swarm DB: $(format_bytes "${STATS[swarm_size_before]}") -> $(format_bytes "${STATS[swarm_size_after]}") (saved: $swarm_saved_human)"
    fi

    local total_saved=$((
        (STATS[agentdb_size_before] - STATS[agentdb_size_after]) +
        (STATS[swarm_size_before] - STATS[swarm_size_after])
    ))
    local total_saved_human
    total_saved_human=$(format_bytes "$total_saved")

    log "INFO" ""
    log "INFO" "Total space reclaimed: $total_saved_human"
    log "INFO" "========================================="
    log "INFO" "Log file: $LOG_FILE"
}

# Main execution
main() {
    log "INFO" "Starting weekly memory cleanup..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Running in DRY-RUN mode (no changes will be made)"
    fi

    # Execute cleanup tasks
    cleanup_telemetry || log "WARN" "Telemetry cleanup failed"
    cleanup_old_episodes || log "WARN" "Episode cleanup failed"
    vacuum_agentdb || log "WARN" "AgentDB vacuum failed"
    vacuum_swarm_db || log "WARN" "Swarm DB vacuum failed"
    run_deduplication || log "WARN" "Deduplication failed"

    # Print statistics
    print_statistics

    log "INFO" "Weekly memory cleanup completed"
}

# Run main function
main "$@"
