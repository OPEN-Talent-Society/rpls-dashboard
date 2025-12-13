#!/bin/bash
# Qdrant Scheduled Maintenance Script
# Runs inside Qdrant container or remotely via API
# Purpose: Cleanup, deduplication, index optimization, health checks
# Schedule: Run via cron (e.g., 0 3 * * * for daily at 3am)
# Created: 2025-12-11

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/maintenance"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/qdrant-maintenance-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

QDRANT_URL="https://qdrant.harbor.fyi"

echo "═══════════════════════════════════════════════════════════"
echo "🔧 Qdrant Maintenance - $(date)"
echo "═══════════════════════════════════════════════════════════"

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
# COLLECTION STATS
# ============================================
collection_stats() {
    echo ""
    echo "📊 Collection Statistics..."

    local collections=$(curl -s --max-time 30 \
        "$QDRANT_URL/collections" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.collections[].name')

    local total_points=0

    for col in $collections; do
        local info=$(curl -s --max-time 30 \
            "$QDRANT_URL/collections/$col" \
            -H "api-key: ${QDRANT_API_KEY}")

        local points=$(echo "$info" | jq -r '.result.points_count // 0')
        local indexed=$(echo "$info" | jq -r '.result.indexed_vectors_count // 0')
        local status=$(echo "$info" | jq -r '.result.status // "unknown"')

        echo "  📁 $col: $points points ($indexed indexed) - $status"
        total_points=$((total_points + points))
    done

    echo ""
    echo "  📈 Total: $total_points vectors across $(echo "$collections" | wc -w | tr -d ' ') collections"
}

# ============================================
# DUPLICATE DETECTION & CLEANUP
# ============================================
find_duplicates() {
    echo ""
    echo "🔍 Checking for potential duplicates..."

    local collections="agent_memory learnings patterns"

    for col in $collections; do
        echo "  Scanning $col..."

        # Get sample of recent points to check for duplicate content hashes
        local points=$(curl -s --max-time 60 -X POST \
            "$QDRANT_URL/collections/$col/points/scroll" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{"limit": 1000, "with_payload": true}' | jq -c '.result.points[]')

        # Count unique content hashes vs total
        local total=$(echo "$points" | wc -l | tr -d ' ')
        local unique_hashes=$(echo "$points" | jq -r '.payload.content_hash // .payload.task // .payload.topic' | sort -u | wc -l | tr -d ' ')

        if [ "$total" -gt 0 ]; then
            local dupe_rate=$((100 - (unique_hashes * 100 / total)))
            echo "    📊 $total points, ~$unique_hashes unique (est. ${dupe_rate}% duplicates)"

            if [ "$dupe_rate" -gt 20 ]; then
                echo "    ⚠️  High duplicate rate detected in $col"
            fi
        fi
    done
}

# ============================================
# INDEX OPTIMIZATION
# ============================================
optimize_indexes() {
    echo ""
    echo "⚡ Index Optimization..."

    local collections=$(curl -s --max-time 30 \
        "$QDRANT_URL/collections" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.collections[].name')

    for col in $collections; do
        local info=$(curl -s --max-time 30 \
            "$QDRANT_URL/collections/$col" \
            -H "api-key: ${QDRANT_API_KEY}")

        local points=$(echo "$info" | jq -r '.result.points_count // 0')
        local indexed=$(echo "$info" | jq -r '.result.indexed_vectors_count // 0')

        # Check if index is behind
        if [ "$indexed" -lt "$points" ]; then
            local behind=$((points - indexed))
            echo "  📁 $col: $behind vectors not yet indexed"

            # Trigger index rebuild if significantly behind
            if [ "$behind" -gt 100 ]; then
                echo "    🔄 Triggering index update for $col..."
                curl -s --max-time 300 -X POST \
                    "$QDRANT_URL/collections/$col/index" \
                    -H "api-key: ${QDRANT_API_KEY}" \
                    -H "Content-Type: application/json" \
                    -d '{"wait": false}' > /dev/null
            fi
        else
            echo "  ✅ $col: fully indexed"
        fi
    done
}

# ============================================
# CLEANUP OLD DATA (Optional)
# ============================================
cleanup_old_data() {
    echo ""
    echo "🧹 Cleanup Check..."

    # Check for old data that might need archiving (>90 days)
    local cutoff=$(date -v-90d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -d '90 days ago' +%Y-%m-%dT%H:%M:%SZ)

    echo "  📅 Checking for data older than: $cutoff"
    echo "  ℹ️  Auto-cleanup disabled - manual review required"
    echo "  📝 To archive old data, use: sync-old-to-archive.sh"
}

# ============================================
# SNAPSHOT/BACKUP CHECK
# ============================================
backup_status() {
    echo ""
    echo "💾 Backup Status..."

    local snapshots=$(curl -s --max-time 30 \
        "$QDRANT_URL/snapshots" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result // []')

    local count=$(echo "$snapshots" | jq 'length')

    if [ "$count" -gt 0 ]; then
        echo "  📸 Found $count snapshots"
        echo "$snapshots" | jq -r '.[] | "    - \(.name) (\(.size // 0) bytes)"' | head -5
    else
        echo "  ⚠️  No snapshots found"
        echo "  💡 Consider creating: POST /snapshots"
    fi
}

# ============================================
# MAIN
# ============================================
main() {
    echo ""

    # Run health check first
    if ! health_check; then
        echo "❌ Qdrant unhealthy - aborting maintenance"
        exit 1
    fi

    # Run maintenance tasks
    collection_stats
    find_duplicates
    optimize_indexes
    cleanup_old_data
    backup_status

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ Qdrant Maintenance Complete - $(date)"
    echo "═══════════════════════════════════════════════════════════"
}

# Handle arguments
case "${1:-}" in
    --health)
        health_check
        ;;
    --stats)
        collection_stats
        ;;
    --dupes)
        find_duplicates
        ;;
    --optimize)
        optimize_indexes
        ;;
    --backup)
        backup_status
        ;;
    --help)
        echo "Usage: qdrant-maintenance.sh [--health|--stats|--dupes|--optimize|--backup|--help]"
        echo "  No args: full maintenance run"
        ;;
    *)
        main
        ;;
esac
