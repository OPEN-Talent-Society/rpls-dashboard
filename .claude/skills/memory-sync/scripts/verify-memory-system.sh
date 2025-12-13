#!/bin/bash
# Memory System Verification Script
# Checks data integrity across all memory layers
# Created: 2025-12-08

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          MEMORY SYSTEM VERIFICATION                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

PASS=0
WARN=0
FAIL=0

check_pass() { echo "  ✅ $1"; ((PASS++)); }
check_warn() { echo "  ⚠️  $1"; ((WARN++)); }
check_fail() { echo "  ❌ $1"; ((FAIL++)); }

# ═══════════════════════════════════════════════════════════════════
# 1. SOURCE DATA COUNTS
# ═══════════════════════════════════════════════════════════════════
echo "📊 SOURCE DATA COUNTS"
echo "─────────────────────────────────────────────────────────────────"

# AgentDB
AGENTDB_EPISODES=$(sqlite3 "$PROJECT_DIR/agentdb.db" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
echo "  AgentDB episodes: $AGENTDB_EPISODES"

# Supabase
SB_LEARNINGS=$(curl -s -I "${SUPABASE_URL}/rest/v1/learnings?select=id" \
  -H "apikey: ${SUPABASE_KEY}" -H "Prefer: count=exact" 2>/dev/null | grep -i content-range | sed 's/.*\///' | tr -d '\r\n')
SB_PATTERNS=$(curl -s -I "${SUPABASE_URL}/rest/v1/patterns?select=id" \
  -H "apikey: ${SUPABASE_KEY}" -H "Prefer: count=exact" 2>/dev/null | grep -i content-range | sed 's/.*\///' | tr -d '\r\n')
echo "  Supabase learnings: ${SB_LEARNINGS:-0}"
echo "  Supabase patterns: ${SB_PATTERNS:-0}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# 2. QDRANT COLLECTION COUNTS
# ═══════════════════════════════════════════════════════════════════
echo "📦 QDRANT COLLECTION COUNTS"
echo "─────────────────────────────────────────────────────────────────"

for COLL in agent_memory codebase learnings patterns; do
  COUNT=$(curl -s -H "api-key: ${QDRANT_API_KEY}" "${QDRANT_URL}/collections/$COLL" 2>/dev/null | jq -r '.result.points_count // 0')
  echo "  $COLL: $COUNT"
  eval "Q_$COLL=$COUNT"
done
echo ""

# ═══════════════════════════════════════════════════════════════════
# 3. DATA INTEGRITY CHECKS
# ═══════════════════════════════════════════════════════════════════
echo "🔍 DATA INTEGRITY CHECKS"
echo "─────────────────────────────────────────────────────────────────"

# Check: Supabase learnings vs Qdrant learnings
if [ "${SB_LEARNINGS:-0}" -gt 0 ]; then
  DIFF=$((${SB_LEARNINGS:-0} - ${Q_learnings:-0}))
  if [ "$DIFF" -le 2 ]; then
    check_pass "Learnings sync: Supabase($SB_LEARNINGS) ≈ Qdrant($Q_learnings)"
  else
    check_warn "Learnings sync lag: Supabase($SB_LEARNINGS) > Qdrant($Q_learnings) [diff: $DIFF]"
  fi
fi

# Check: Supabase patterns vs Qdrant patterns
if [ "${SB_PATTERNS:-0}" -gt 0 ]; then
  DIFF=$((${SB_PATTERNS:-0} - ${Q_patterns:-0}))
  if [ "$DIFF" -eq 0 ]; then
    check_pass "Patterns sync: Supabase($SB_PATTERNS) = Qdrant($Q_patterns)"
  else
    check_warn "Patterns sync lag: Supabase($SB_PATTERNS) vs Qdrant($Q_patterns) [diff: $DIFF]"
  fi
fi

# Check: No patterns in agent_memory (cleaned)
PATTERN_IN_AM=$(curl -s -X POST "${QDRANT_URL}/collections/agent_memory/points/count" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filter":{"must":[{"key":"type","match":{"value":"pattern"}}]}}' 2>/dev/null | jq -r '.result.count // 0')

if [ "${PATTERN_IN_AM:-0}" -eq 0 ]; then
  check_pass "No patterns in agent_memory (correctly separated)"
else
  check_fail "Found $PATTERN_IN_AM patterns in agent_memory (should be 0)"
fi

# Check: No mass learning duplicates in agent_memory
LEARNING_IN_AM=$(curl -s -X POST "${QDRANT_URL}/collections/agent_memory/points/count" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"filter":{"must":[{"key":"type","match":{"value":"learning"}}]}}' 2>/dev/null | jq -r '.result.count // 0')

if [ "${LEARNING_IN_AM:-0}" -lt 100 ]; then
  check_pass "Learning duplicates in agent_memory: $LEARNING_IN_AM (acceptable)"
else
  check_warn "Learning duplicates in agent_memory: $LEARNING_IN_AM (should be < 100)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# 4. SCRIPT CONFIGURATION CHECKS
# ═══════════════════════════════════════════════════════════════════
echo "⚙️  SCRIPT CONFIGURATION CHECKS"
echo "─────────────────────────────────────────────────────────────────"

# Check: Collection names are hardcoded (not env vars)
SCRIPTS_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts"

for script_check in \
  "sync-patterns-to-qdrant.sh:patterns" \
  "sync-learnings-to-qdrant.sh:learnings" \
  "sync-episodes-to-qdrant.sh:agent_memory" \
  "index-codebase-to-qdrant.sh:codebase"; do

  SCRIPT=$(echo "$script_check" | cut -d: -f1)
  EXPECTED=$(echo "$script_check" | cut -d: -f2)

  if [ -f "$SCRIPTS_DIR/$SCRIPT" ]; then
    # Check if collection is hardcoded (not using env var fallback)
    if grep -q "QDRANT_COLLECTION=\"$EXPECTED\"" "$SCRIPTS_DIR/$SCRIPT" 2>/dev/null; then
      check_pass "$SCRIPT → hardcoded to '$EXPECTED'"
    elif grep -q "QDRANT_COLLECTION=.*\${" "$SCRIPTS_DIR/$SCRIPT" 2>/dev/null; then
      check_warn "$SCRIPT → uses env var fallback (may be polluted)"
    else
      check_pass "$SCRIPT → appears correct"
    fi
  fi
done

# Check: incremental-memory-sync.sh uses run_with_timeout
HOOK="$PROJECT_DIR/.claude/hooks/incremental-memory-sync.sh"
if [ -f "$HOOK" ]; then
  if grep -q "run_with_timeout" "$HOOK" 2>/dev/null; then
    check_pass "incremental-memory-sync.sh uses macOS-compatible timeout"
  else
    check_fail "incremental-memory-sync.sh missing run_with_timeout function"
  fi

  if grep -q "^[^#]*timeout " "$HOOK" 2>/dev/null; then
    check_warn "incremental-memory-sync.sh still has raw 'timeout' calls"
  fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# 5. SYNC HOOK STATUS
# ═══════════════════════════════════════════════════════════════════
echo "🔄 SYNC HOOK STATUS"
echo "─────────────────────────────────────────────────────────────────"

SYNC_STATE="/tmp/claude-memory-sync-state"
if [ -f "$SYNC_STATE" ]; then
  CALL_COUNT=$(jq -r '.call_count // 0' "$SYNC_STATE")
  LAST_SYNC=$(jq -r '.last_sync // 0' "$SYNC_STATE")
  NOW=$(date +%s)
  SINCE=$((NOW - LAST_SYNC))
  echo "  Call count: $CALL_COUNT"
  echo "  Last sync: ${SINCE}s ago"

  if [ "$SINCE" -lt 600 ]; then
    check_pass "Incremental sync active (last sync < 10 min ago)"
  else
    check_warn "Incremental sync may be stale (last sync > 10 min ago)"
  fi
else
  check_warn "No sync state file (hooks may not have run yet)"
fi

# Check sync log for errors
SYNC_LOG="/tmp/claude-memory-sync.log"
if [ -f "$SYNC_LOG" ]; then
  RECENT_ERRORS=$(tail -20 "$SYNC_LOG" | grep -c "error\|timeout\|not found" || echo "0")
  if [ "$RECENT_ERRORS" -eq 0 ]; then
    check_pass "No recent errors in sync log"
  else
    check_warn "Found $RECENT_ERRORS potential issues in recent sync log"
  fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════════════════"
echo "                         SUMMARY                                "
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "  ✅ Passed: $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed: $FAIL"
echo ""

if [ "$FAIL" -eq 0 ] && [ "$WARN" -le 2 ]; then
  echo "  🎉 MEMORY SYSTEM HEALTHY"
  exit 0
elif [ "$FAIL" -eq 0 ]; then
  echo "  ⚠️  MEMORY SYSTEM FUNCTIONAL (with warnings)"
  exit 0
else
  echo "  ❌ MEMORY SYSTEM NEEDS ATTENTION"
  exit 1
fi
