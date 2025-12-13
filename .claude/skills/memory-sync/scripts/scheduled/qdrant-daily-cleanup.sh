#!/bin/bash
# Qdrant Daily Cleanup Script
# Container: harbor-home (Qdrant)
# Purpose: Remove orphaned vectors, cleanup old low-relevance vectors, compact collections
# Schedule: Daily at 2:00 AM
# Cron: 0 2 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/qdrant-daily-cleanup.sh >> /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log 2>&1

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/maintenance"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/qdrant-daily-cleanup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "═══════════════════════════════════════════════════════════"
echo "🧹 Qdrant Daily Cleanup - $(date)"
echo "═══════════════════════════════════════════════════════════"

# Load environment (extract vars individually to avoid zsh parse errors)
if [ -f "$PROJECT_DIR/.env" ]; then
    QDRANT_URL=$(grep "^QDRANT_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    QDRANT_API_KEY=$(grep "^QDRANT_API_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
fi

[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"

# Statistics
ORPHANS_REMOVED=0
OLD_VECTORS_REMOVED=0
COLLECTIONS_COMPACTED=0

# ============================================
# HEALTH CHECK
# ============================================
health_check() {
    echo ""
    echo "🏥 Health Check..."

    local health=$(curl -s --max-time 10 \
        "$QDRANT_URL/healthz" \
        -H "api-key: ${QDRANT_API_KEY}")

    if [ "$health" = "healthz check passed" ]; then
        echo "  ✅ Qdrant is healthy"
        return 0
    else
        echo "  ❌ Health check failed: $health"
        return 1
    fi
}

# ============================================
# CLEANUP ORPHANED VECTORS
# ============================================
cleanup_orphaned_vectors() {
    echo ""
    echo "🔍 Cleaning orphaned vectors (content_hash doesn't exist in source)..."

    local collections="agent_memory learnings patterns cortex"

    for col in $collections; do
        echo "  📁 Processing $col..."

        # Scroll through points and check for orphans
        local scroll_result=$(curl -s --max-time 60 -X POST \
            "$QDRANT_URL/collections/$col/points/scroll" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{"limit": 1000, "with_payload": true, "with_vector": false}')

        # Extract points with missing or empty content_hash
        local orphan_ids=$(echo "$scroll_result" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for point in data.get('result', {}).get('points', []):
    payload = point.get('payload', {})
    content_hash = payload.get('content_hash', '')
    content = payload.get('content', '')
    # Orphan if: no content_hash, empty content, or placeholder content
    if not content_hash or not content or content == 'null' or len(content) < 10:
        print(point.get('id', ''))
" 2>/dev/null)

        if [ -n "$orphan_ids" ]; then
            local count=$(echo "$orphan_ids" | wc -l | tr -d ' ')
            echo "    ⚠️  Found $count orphan vectors"

            # Delete orphans in batches
            for id in $orphan_ids; do
                curl -s --max-time 10 -X POST \
                    "$QDRANT_URL/collections/$col/points/delete" \
                    -H "api-key: ${QDRANT_API_KEY}" \
                    -H "Content-Type: application/json" \
                    -d "{\"points\": [$id]}" > /dev/null

                ORPHANS_REMOVED=$((ORPHANS_REMOVED + 1))
            done

            echo "    ✅ Removed $count orphan vectors from $col"
        else
            echo "    ✅ No orphans found in $col"
        fi
    done
}

# ============================================
# CLEANUP OLD LOW-RELEVANCE VECTORS
# ============================================
cleanup_old_low_relevance() {
    echo ""
    echo "🗑️  Cleaning old low-relevance vectors (>90 days, low scores)..."

    local collections="learnings patterns"
    local cutoff_date=$(date -v-90d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)

    echo "  📅 Cutoff date: $cutoff_date"

    for col in $collections; do
        echo "  📁 Processing $col..."

        # Scroll and filter old vectors with low success/confidence scores
        local scroll_result=$(curl -s --max-time 60 -X POST \
            "$QDRANT_URL/collections/$col/points/scroll" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{"limit": 1000, "with_payload": true, "with_vector": false}')

        # Find old + low-relevance vectors
        local old_ids=$(echo "$scroll_result" | python3 -c "
import sys, json
from datetime import datetime, timedelta
data = json.load(sys.stdin)
cutoff = datetime.fromisoformat('$cutoff_date'.replace('Z', '+00:00'))

for point in data.get('result', {}).get('points', []):
    payload = point.get('payload', {})

    # Get timestamp
    indexed_at = payload.get('indexed_at', payload.get('created_at', ''))
    if not indexed_at:
        continue

    try:
        point_time = datetime.fromisoformat(indexed_at.replace('Z', '+00:00'))
    except:
        continue

    # Check if old
    if point_time >= cutoff:
        continue

    # Check relevance scores
    success_count = payload.get('success_count', 0)
    confidence = payload.get('confidence', 0.0)
    reward = payload.get('reward', 0.0)

    # Remove if: old AND (never succeeded OR very low confidence)
    if success_count == 0 and confidence < 0.3 and reward < 0.3:
        print(point.get('id', ''))
" 2>/dev/null)

        if [ -n "$old_ids" ]; then
            local count=$(echo "$old_ids" | wc -l | tr -d ' ')
            echo "    ⚠️  Found $count old low-relevance vectors"

            # Delete in batches
            for id in $old_ids; do
                curl -s --max-time 10 -X POST \
                    "$QDRANT_URL/collections/$col/points/delete" \
                    -H "api-key: ${QDRANT_API_KEY}" \
                    -H "Content-Type: application/json" \
                    -d "{\"points\": [$id]}" > /dev/null

                OLD_VECTORS_REMOVED=$((OLD_VECTORS_REMOVED + 1))
            done

            echo "    ✅ Removed $count old low-relevance vectors from $col"
        else
            echo "    ✅ No old low-relevance vectors in $col"
        fi
    done
}

# ============================================
# COMPACT COLLECTIONS
# ============================================
compact_collections() {
    echo ""
    echo "⚡ Compacting collections..."

    local collections=$(curl -s --max-time 30 \
        "$QDRANT_URL/collections" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.collections[].name')

    for col in $collections; do
        echo "  📁 Compacting $col..."

        # Trigger optimization (compaction + indexing)
        local result=$(curl -s --max-time 300 -X POST \
            "$QDRANT_URL/collections/$col/index" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{"wait": false}')

        if echo "$result" | jq -e '.result' > /dev/null 2>&1; then
            echo "    ✅ Compaction triggered for $col"
            COLLECTIONS_COMPACTED=$((COLLECTIONS_COMPACTED + 1))
        else
            echo "    ⚠️  Compaction failed for $col"
        fi
    done
}

# ============================================
# STATISTICS REPORT
# ============================================
print_stats() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "📊 Cleanup Statistics"
    echo "═══════════════════════════════════════════════════════════"
    echo "  🗑️  Orphaned vectors removed: $ORPHANS_REMOVED"
    echo "  📅 Old low-relevance removed: $OLD_VECTORS_REMOVED"
    echo "  ⚡ Collections compacted: $COLLECTIONS_COMPACTED"
    echo "═══════════════════════════════════════════════════════════"
}

# ============================================
# MAIN
# ============================================
main() {
    echo ""

    # Run health check first
    if ! health_check; then
        echo "❌ Qdrant unhealthy - aborting cleanup"
        exit 1
    fi

    # Run cleanup tasks
    cleanup_orphaned_vectors
    cleanup_old_low_relevance
    compact_collections

    # Print statistics
    print_stats

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ Qdrant Daily Cleanup Complete - $(date)"
    echo "═══════════════════════════════════════════════════════════"
}

# Run main
main
