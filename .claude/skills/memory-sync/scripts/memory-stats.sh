#!/bin/bash
# Show memory statistics across all backends
# Usage: memory-stats.sh

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Proper env loading (set -a exports all variables)
set -a
source "$PROJECT_DIR/.env" 2>/dev/null || true
set +a

SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
# Use service role key for full access
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              UNIFIED MEMORY STATISTICS                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# AgentDB Stats
echo "┌─ AgentDB/ReasoningBank (Local SQLite) ────────────────────────"
AGENTDB_PATH="$PROJECT_DIR/agentdb.db"
if [ -f "$AGENTDB_PATH" ]; then
    EPISODES=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
    SIZE=$(du -h "$AGENTDB_PATH" 2>/dev/null | cut -f1)
    echo "│  Episodes: $EPISODES"
    echo "│  Size: $SIZE"
    echo "│  Path: $AGENTDB_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Swarm Memory Stats
echo "┌─ Swarm Memory (Local SQLite) ─────────────────────────────────"
SWARM_PATH="$PROJECT_DIR/.swarm/memory.db"
if [ -f "$SWARM_PATH" ]; then
    SIZE=$(du -h "$SWARM_PATH" 2>/dev/null | cut -f1)
    echo "│  Size: $SIZE"
    echo "│  Path: $SWARM_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Hive-Mind Memory Stats
echo "┌─ Hive-Mind Memory (Local JSON) ───────────────────────────────"
HIVE_PATH="$PROJECT_DIR/project-campfire/.hive-mind/memory.json"
if [ -f "$HIVE_PATH" ]; then
    SIZE=$(du -h "$HIVE_PATH" 2>/dev/null | cut -f1)
    KEYS=$(jq 'keys | length' "$HIVE_PATH" 2>/dev/null || echo "0")
    echo "│  Keys: $KEYS"
    echo "│  Size: $SIZE"
    echo "│  Path: $HIVE_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Supabase Stats - Use content-range header for accurate counts (not limited to 1000)
echo "┌─ Supabase (Cloud PostgreSQL) ─────────────────────────────────"
if [ -n "$SUPABASE_KEY" ]; then
    # Function to get actual count via content-range header
    get_count() {
        local table="$1"
        curl -s -I "${SUPABASE_URL}/rest/v1/${table}?select=id&limit=1" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Prefer: count=exact" 2>/dev/null | \
            grep -i "content-range" | sed 's/.*\///' | tr -d '\r\n'
    }
    PATTERNS=$(get_count "patterns")
    LEARNINGS=$(get_count "learnings")
    MEMORIES=$(get_count "agent_memory")
    echo "│  patterns table: ${PATTERNS:-?} records"
    echo "│  learnings table: ${LEARNINGS:-?} records"
    echo "│  agent_memory table: ${MEMORIES:-?} records"
    echo "│  URL: $SUPABASE_URL"
else
    echo "│  Status: Not configured (missing SUPABASE_SERVICE_ROLE_KEY)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Cortex (SiYuan) Stats
echo "┌─ Cortex/SiYuan (Knowledge Base) ─────────────────────────────"
CORTEX_URL_VAL="${CORTEX_URL:-https://cortex.aienablement.academy}"
if [ -n "$CORTEX_TOKEN" ] && [ -n "$CF_ACCESS_CLIENT_ID" ]; then
    BLOCK_COUNT=$(curl -s --max-time 5 -X POST "${CORTEX_URL_VAL}/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{"stmt": "SELECT COUNT(*) as count FROM blocks"}' 2>/dev/null | jq -r '.data[0].count // "?"')
    DOC_COUNT=$(curl -s --max-time 5 -X POST "${CORTEX_URL_VAL}/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"stmt\": \"SELECT COUNT(*) as count FROM blocks WHERE type = 'd'\"}" 2>/dev/null | jq -r '.data[0].count // "?"')
    echo "│  Blocks: ${BLOCK_COUNT:-?}"
    echo "│  Documents: ${DOC_COUNT:-?}"
    echo "│  URL: $CORTEX_URL_VAL"
else
    echo "│  Status: Not configured (missing CORTEX_TOKEN or CF_ACCESS_CLIENT_ID)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# RuVector Stats
echo "┌─ RuVector (Vector Search) ────────────────────────────────────"
RUVECTOR_VERSION=$(pnpm dlx ruvector --version 2>/dev/null || echo "Not installed")
echo "│  Version: $RUVECTOR_VERSION"
pnpm dlx ruvector stats --collection agent_memory 2>/dev/null || echo "│  Collection: Not initialized"
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Qdrant Stats - Query each collection directly for accurate counts
echo "┌─ Qdrant (Semantic Layer) ─────────────────────────────────────"
QDRANT_URL_DISPLAY="${QDRANT_URL:-https://qdrant.harbor.fyi}"
if [ -n "$QDRANT_API_KEY" ]; then
    for collection in agent_memory learnings patterns codebase; do
        COUNT=$(curl -s "${QDRANT_URL}/collections/${collection}" \
            -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq -r '.result.points_count // "null"' 2>/dev/null)
        if [ "$COUNT" = "null" ] || [ -z "$COUNT" ]; then
            echo "│  $collection: Not initialized"
        else
            echo "│  $collection: $COUNT vectors"
        fi
    done
    echo "│  URL: $QDRANT_URL_DISPLAY"
else
    echo "│  Status: Not configured (QDRANT_API_KEY missing)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Health Check Section
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    HEALTH CHECK                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

HEALTH_SCORE=100
WARNINGS=()

# 1. Check Supabase learnings for swarm-memory pollution
echo "┌─ Supabase Learnings Pollution Check ─────────────────────────"
if [ -n "$SUPABASE_KEY" ]; then
    SWARM_POLLUTION=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=category&category=eq.swarm-memory&limit=1" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact" 2>/dev/null | \
        grep -i "content-range" | sed 's/.*\///' | tr -d '\r\n')

    if [ -n "$SWARM_POLLUTION" ] && [ "$SWARM_POLLUTION" != "0" ]; then
        echo "│  ⚠️  WARNING: swarm-memory category detected ($SWARM_POLLUTION records)"
        echo "│      This indicates memory pollution - swarm data in learnings table"
        HEALTH_SCORE=$((HEALTH_SCORE - 20))
        WARNINGS+=("Swarm-memory pollution in learnings table")
    else
        echo "│  ✅ No pollution detected"
    fi
else
    echo "│  ⊘  Skipped (Supabase not configured)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# 2. Check AgentDB for duplicate tasks
echo "┌─ AgentDB Duplicate Tasks Check ──────────────────────────────"
if [ -f "$AGENTDB_PATH" ]; then
    TOTAL_EPISODES=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
    if [ "$TOTAL_EPISODES" -gt 0 ]; then
        # Find episodes with identical task names
        DUPLICATE_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) - COUNT(DISTINCT task) FROM episodes;" 2>/dev/null || echo "0")
        DUPLICATE_PCT=$((DUPLICATE_COUNT * 100 / TOTAL_EPISODES))

        echo "│  Total episodes: $TOTAL_EPISODES"
        echo "│  Duplicate tasks: $DUPLICATE_COUNT ($DUPLICATE_PCT%)"

        if [ "$DUPLICATE_PCT" -gt 10 ]; then
            echo "│  ⚠️  WARNING: Duplicate rate exceeds 10% threshold"
            HEALTH_SCORE=$((HEALTH_SCORE - 10))
            WARNINGS+=("AgentDB duplicates: ${DUPLICATE_PCT}%")
        else
            echo "│  ✅ Duplicate rate within acceptable range"
        fi
    else
        echo "│  ⊘  No episodes to check"
    fi
else
    echo "│  ⊘  AgentDB not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# 3. Check Cortex for orphaned blocks
echo "┌─ Cortex Orphan Percentage Check ─────────────────────────────"
if [ -n "$CORTEX_TOKEN" ] && [ -n "$CF_ACCESS_CLIENT_ID" ]; then
    TOTAL_BLOCKS=$(curl -s --max-time 5 -X POST "${CORTEX_URL_VAL}/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{"stmt": "SELECT COUNT(*) as count FROM blocks"}' 2>/dev/null | jq -r '.data[0].count // "0"')

    # Orphans are blocks without a parent reference
    ORPHAN_BLOCKS=$(curl -s --max-time 5 -X POST "${CORTEX_URL_VAL}/api/query/sql" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d '{"stmt": "SELECT COUNT(*) as count FROM blocks WHERE parent_id IS NULL OR parent_id = \"\""}' 2>/dev/null | jq -r '.data[0].count // "0"')

    if [ "$TOTAL_BLOCKS" -gt 0 ]; then
        ORPHAN_PCT=$((ORPHAN_BLOCKS * 100 / TOTAL_BLOCKS))
        echo "│  Total blocks: $TOTAL_BLOCKS"
        echo "│  Orphan blocks: $ORPHAN_BLOCKS ($ORPHAN_PCT%)"

        if [ "$ORPHAN_PCT" -gt 20 ]; then
            echo "│  ⚠️  WARNING: Orphan rate exceeds 20% threshold"
            HEALTH_SCORE=$((HEALTH_SCORE - 20))
            WARNINGS+=("Cortex orphan rate: ${ORPHAN_PCT}%")
        else
            echo "│  ✅ Orphan rate within acceptable range"
        fi
    else
        echo "│  ⊘  No blocks to check"
    fi
else
    echo "│  ⊘  Skipped (Cortex not configured)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# 4. Check Qdrant semantic memory (unified agent_memory collection)
echo "┌─ Qdrant Semantic Memory Check ─────────────────────────────────"
if [ -n "$QDRANT_API_KEY" ]; then
    # Primary check: agent_memory is the unified collection
    AGENT_MEMORY_COUNT=$(curl -s "${QDRANT_URL}/collections/agent_memory" \
        -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq -r '.result.points_count // "0"' 2>/dev/null)

    if [ "$AGENT_MEMORY_COUNT" -gt 1000 ]; then
        echo "│  ✅ agent_memory: $AGENT_MEMORY_COUNT vectors (healthy)"
    elif [ "$AGENT_MEMORY_COUNT" -gt 0 ]; then
        echo "│  ⚠️  agent_memory: $AGENT_MEMORY_COUNT vectors (low - consider re-ingestion)"
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
        WARNINGS+=("Low vector count in agent_memory")
    else
        echo "│  ❌ agent_memory: EMPTY (critical - run reingest-all.sh)"
        HEALTH_SCORE=$((HEALTH_SCORE - 30))
        WARNINGS+=("Empty agent_memory collection")
    fi

    # Info only: secondary collections (no penalty - they may use unified approach)
    echo "│  ─────────────────────────────────────────"
    echo "│  Secondary collections (optional):"
    for collection in learnings patterns codebase cortex; do
        COUNT=$(curl -s "${QDRANT_URL}/collections/${collection}" \
            -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq -r '.result.points_count // "0"' 2>/dev/null)
        if [ "$COUNT" -gt 0 ]; then
            echo "│    $collection: $COUNT vectors"
        else
            echo "│    $collection: (using unified approach)"
        fi
    done
else
    echo "│  ⊘  Skipped (Qdrant not configured)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Storage Capacity Check
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                 STORAGE CAPACITY CHECK                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Supabase estimate (500MB free tier limit)
echo "┌─ Supabase (500MB Free Tier Limit) ───────────────────────────"
if [ -n "$SUPABASE_KEY" ]; then
    # Estimate based on record counts (rough: ~1KB per pattern, ~2KB per learning)
    PATTERNS_EST=$((PATTERNS * 1))        # ~1KB each
    LEARNINGS_EST=$((LEARNINGS * 2))      # ~2KB each
    MEMORIES_EST=$((MEMORIES * 1))        # ~1KB each
    TOTAL_KB=$((PATTERNS_EST + LEARNINGS_EST + MEMORIES_EST))
    TOTAL_MB=$((TOTAL_KB / 1024))
    USAGE_PCT=$((TOTAL_MB * 100 / 500))

    echo "│  Estimated usage: ~${TOTAL_MB}MB / 500MB (${USAGE_PCT}%)"

    if [ "$USAGE_PCT" -gt 80 ]; then
        echo "│  ⚠️  WARNING: Approaching 500MB free tier limit!"
        HEALTH_SCORE=$((HEALTH_SCORE - 15))
        WARNINGS+=("Supabase storage at ${USAGE_PCT}%")
    elif [ "$USAGE_PCT" -gt 50 ]; then
        echo "│  ⚠️  NOTICE: Over 50% of free tier used"
    else
        echo "│  ✅ Storage within safe limits"
    fi
else
    echo "│  ⊘  Cannot estimate (Supabase not configured)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Qdrant storage (self-hosted - check Docker VM disk)
echo "┌─ Qdrant Vector Storage ──────────────────────────────────────"
if [ -n "$QDRANT_API_KEY" ]; then
    # Get total vectors across all collections
    TOTAL_VECTORS=0
    for collection in agent_memory learnings patterns codebase cortex; do
        COUNT=$(curl -s --max-time 5 "${QDRANT_URL}/collections/${collection}" \
            -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq -r '.result.points_count // 0' 2>/dev/null)
        TOTAL_VECTORS=$((TOTAL_VECTORS + COUNT))
    done

    # Estimate: 768-dim float32 = 3KB per vector + metadata ~1KB = ~4KB each
    QDRANT_MB=$((TOTAL_VECTORS * 4 / 1024))

    echo "│  Total vectors: $TOTAL_VECTORS"
    echo "│  Estimated size: ~${QDRANT_MB}MB"
    echo "│  Note: Self-hosted - check Docker VM disk space"

    if [ "$TOTAL_VECTORS" -gt 100000 ]; then
        echo "│  ⚠️  Large vector count - monitor disk usage"
    else
        echo "│  ✅ Vector count within normal range"
    fi
else
    echo "│  ⊘  Cannot check (Qdrant not configured)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Overall Health Score
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  OVERALL HEALTH SCORE                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Ensure score doesn't go below 0
if [ $HEALTH_SCORE -lt 0 ]; then
    HEALTH_SCORE=0
fi

# Color-coded score display
if [ $HEALTH_SCORE -ge 80 ]; then
    STATUS_ICON="✅"
    STATUS_TEXT="HEALTHY"
elif [ $HEALTH_SCORE -ge 60 ]; then
    STATUS_ICON="⚠️"
    STATUS_TEXT="NEEDS ATTENTION"
else
    STATUS_ICON="❌"
    STATUS_TEXT="CRITICAL"
fi

echo "  Score: $HEALTH_SCORE/100  $STATUS_ICON  $STATUS_TEXT"
echo ""

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo "  Issues Found:"
    for warning in "${WARNINGS[@]}"; do
        echo "    • $warning"
    done
    echo ""
fi

echo "─────────────────────────────────────────────────────────────"
echo ""
echo "Run 'sync-all.sh' to synchronize all backends"
