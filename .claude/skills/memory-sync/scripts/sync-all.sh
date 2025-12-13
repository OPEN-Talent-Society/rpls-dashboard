#!/bin/bash
# Full sync across all memory backends (HOT → COLD)
# Syncs: AgentDB, Hive-Mind, Swarm → Supabase + Cortex
# Usage: sync-all.sh [--force] [--skip-qdrant] [--cold-only]
# Auto-terminates after 60 seconds to prevent runaway background processes

set -e

# Self-termination timeout (60 seconds max)
MAX_RUNTIME=60
START_TIME=$(date +%s)

check_timeout() {
    ELAPSED=$(($(date +%s) - START_TIME))
    if [ "$ELAPSED" -ge "$MAX_RUNTIME" ]; then
        echo "⚠️  Sync auto-terminated after ${MAX_RUNTIME}s (will continue next session)"
        exit 0
    fi
}

# macOS-compatible timeout runner that kills entire process group
run_with_timeout() {
    local timeout_secs=$1
    shift
    # Run command in subshell so we can kill the process group
    (
        "$@"
    ) &
    local pid=$!
    # Watchdog kills after timeout
    (
        sleep "$timeout_secs"
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -9 "$pid" 2>/dev/null
    ) &
    local watchdog=$!
    # Wait for main command
    wait "$pid" 2>/dev/null
    local result=$?
    # Kill watchdog if command finished
    kill "$watchdog" 2>/dev/null 2>&1
    wait "$watchdog" 2>/dev/null 2>&1
    return $result
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SYNC_LOG="/tmp/claude-memory-sync-all.log"
FORCE=""
SKIP_QDRANT=""
COLD_ONLY=""

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE="--force"; shift ;;
        --skip-qdrant) SKIP_QDRANT="true"; shift ;;
        --cold-only) COLD_ONLY="true"; shift ;;
        *) shift ;;
    esac
done

log() {
    echo "[$(date -u +%H:%M:%S)] $1"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$SYNC_LOG"
}

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          UNIFIED MEMORY SYNC - All Backends                  ║"
echo "║          Hot Layer → Cold Storage (Supabase + Cortex)        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

STEP=1
TOTAL_STEPS=7
[ -n "$SKIP_QDRANT" ] && TOTAL_STEPS=$((TOTAL_STEPS - 1))
[ -n "$COLD_ONLY" ] && TOTAL_STEPS=4

# Step 1: AgentDB → Supabase (15s timeout)
check_timeout
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: AgentDB → Supabase (patterns, learnings)          │"
echo "└──────────────────────────────────────────────────────────────┘"
run_with_timeout 15 "$SCRIPT_DIR/sync-agentdb-to-supabase.sh" $FORCE 2>&1 || log "⚠️  AgentDB → Supabase timeout or error"
STEP=$((STEP + 1))
echo ""

# Step 2: SKIPPED - AgentDB → Cortex is DISABLED per MEMORY-SYSTEM-SPECIFICATION.md
# Raw machine data MUST NOT be dumped to Cortex (causes pollution)
# Cortex should only receive human-curated wiki articles via commands/hooks
check_timeout
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: AgentDB → Cortex: SKIPPED (per spec)              │"
echo "└──────────────────────────────────────────────────────────────┘"
log "ℹ️  AgentDB → Cortex sync DISABLED - use /cortex-* commands for curated content"
STEP=$((STEP + 1))
echo ""

# Step 3: Hive-Mind → Cold Storage (15s timeout)
check_timeout
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: Hive-Mind → Supabase + Cortex                     │"
echo "└──────────────────────────────────────────────────────────────┘"
if [ -f "$SCRIPT_DIR/sync-hivemind-to-cold.sh" ]; then
    run_with_timeout 15 "$SCRIPT_DIR/sync-hivemind-to-cold.sh" 2>&1 || log "⚠️  Hive-Mind sync timeout or error"
else
    log "ℹ️  sync-hivemind-to-cold.sh not found, skipping"
fi
STEP=$((STEP + 1))
echo ""

# Step 4: Swarm Memory → Cold Storage (15s timeout)
check_timeout
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: Swarm Memory → Supabase + Cortex                  │"
echo "└──────────────────────────────────────────────────────────────┘"
if [ -f "$SCRIPT_DIR/sync-swarm-to-cold.sh" ]; then
    run_with_timeout 15 "$SCRIPT_DIR/sync-swarm-to-cold.sh" 2>&1 || log "⚠️  Swarm Memory sync timeout or error"
else
    log "ℹ️  sync-swarm-to-cold.sh not found, skipping"
fi
STEP=$((STEP + 1))
echo ""

if [ -z "$COLD_ONLY" ]; then
    # Step 5: Supabase → AgentDB (import cloud patterns for recovery) - 15s timeout
    check_timeout
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│ Step $STEP/$TOTAL_STEPS: Supabase → AgentDB (reverse sync)                 │"
    echo "└──────────────────────────────────────────────────────────────┘"
    run_with_timeout 15 "$SCRIPT_DIR/sync-supabase-to-agentdb.sh" $FORCE 2>&1 || log "⚠️  Supabase import timeout or error"
    STEP=$((STEP + 1))
    echo ""

    # Step 6: Collect local JSON memories - 10s timeout
    check_timeout
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│ Step $STEP/$TOTAL_STEPS: Local JSON → Supabase                             │"
    echo "└──────────────────────────────────────────────────────────────┘"
    run_with_timeout 10 "$SCRIPT_DIR/sync-json-to-supabase.sh" $FORCE 2>/dev/null || log "ℹ️  JSON sync timeout or no local JSON"
    STEP=$((STEP + 1))
    echo ""

    # Step 7: Index everything to Qdrant - 20s timeout
    check_timeout
    if [ -z "$SKIP_QDRANT" ]; then
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│ Step $STEP/$TOTAL_STEPS: Index to Qdrant (semantic search)             │"
        echo "└──────────────────────────────────────────────────────────────┘"
        run_with_timeout 20 "$SCRIPT_DIR/index-to-qdrant.sh" agent_memory 2>&1 || log "⚠️  Qdrant indexing timeout or error"
    else
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│ Step $STEP/$TOTAL_STEPS: Qdrant indexing SKIPPED                       │"
        echo "└──────────────────────────────────────────────────────────────┘"
    fi
    echo ""
fi

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                     SYNC COMPLETE                            ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
log "✅ Full sync completed at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""
"$SCRIPT_DIR/memory-stats.sh" 2>/dev/null || echo "Run memory-stats.sh for details"
