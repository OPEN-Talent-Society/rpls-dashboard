#!/bin/bash
# Full sync across all memory backends (HOT → COLD)
# Syncs: AgentDB, Hive-Mind, Swarm → Supabase + Cortex
# Usage: sync-all.sh [--force] [--skip-qdrant] [--cold-only]

set -e

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

# Step 1: AgentDB → Supabase
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: AgentDB → Supabase (patterns, learnings)          │"
echo "└──────────────────────────────────────────────────────────────┘"
"$SCRIPT_DIR/sync-agentdb-to-supabase.sh" $FORCE 2>&1 || log "⚠️  AgentDB → Supabase had issues"
STEP=$((STEP + 1))
echo ""

# Step 2: AgentDB → Cortex (with SiYuan features)
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: AgentDB → Cortex (links, tags, PARA)              │"
echo "└──────────────────────────────────────────────────────────────┘"
if [ -f "$SCRIPT_DIR/sync-agentdb-to-cortex.sh" ]; then
    "$SCRIPT_DIR/sync-agentdb-to-cortex.sh" 2>&1 || log "⚠️  AgentDB → Cortex had issues"
else
    log "ℹ️  sync-agentdb-to-cortex.sh not found, skipping"
fi
STEP=$((STEP + 1))
echo ""

# Step 3: Hive-Mind → Cold Storage
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: Hive-Mind → Supabase + Cortex                     │"
echo "└──────────────────────────────────────────────────────────────┘"
if [ -f "$SCRIPT_DIR/sync-hivemind-to-cold.sh" ]; then
    "$SCRIPT_DIR/sync-hivemind-to-cold.sh" 2>&1 || log "⚠️  Hive-Mind sync had issues"
else
    log "ℹ️  sync-hivemind-to-cold.sh not found, skipping"
fi
STEP=$((STEP + 1))
echo ""

# Step 4: Swarm Memory → Cold Storage
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│ Step $STEP/$TOTAL_STEPS: Swarm Memory → Supabase + Cortex                  │"
echo "└──────────────────────────────────────────────────────────────┘"
if [ -f "$SCRIPT_DIR/sync-swarm-to-cold.sh" ]; then
    "$SCRIPT_DIR/sync-swarm-to-cold.sh" 2>&1 || log "⚠️  Swarm Memory sync had issues"
else
    log "ℹ️  sync-swarm-to-cold.sh not found, skipping"
fi
STEP=$((STEP + 1))
echo ""

if [ -z "$COLD_ONLY" ]; then
    # Step 5: Supabase → AgentDB (import cloud patterns for recovery)
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│ Step $STEP/$TOTAL_STEPS: Supabase → AgentDB (reverse sync)                 │"
    echo "└──────────────────────────────────────────────────────────────┘"
    "$SCRIPT_DIR/sync-supabase-to-agentdb.sh" $FORCE 2>&1 || log "⚠️  Supabase import had issues"
    STEP=$((STEP + 1))
    echo ""

    # Step 6: Collect local JSON memories
    echo "┌──────────────────────────────────────────────────────────────┐"
    echo "│ Step $STEP/$TOTAL_STEPS: Local JSON → Supabase                             │"
    echo "└──────────────────────────────────────────────────────────────┘"
    "$SCRIPT_DIR/sync-json-to-supabase.sh" $FORCE 2>/dev/null || log "ℹ️  No local JSON to sync"
    STEP=$((STEP + 1))
    echo ""

    # Step 7: Index everything to Qdrant
    if [ -z "$SKIP_QDRANT" ]; then
        echo "┌──────────────────────────────────────────────────────────────┐"
        echo "│ Step $STEP/$TOTAL_STEPS: Index to Qdrant (semantic search)             │"
        echo "└──────────────────────────────────────────────────────────────┘"
        "$SCRIPT_DIR/index-to-qdrant.sh" agent_memory 2>&1 || log "⚠️  Qdrant indexing had issues"
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
