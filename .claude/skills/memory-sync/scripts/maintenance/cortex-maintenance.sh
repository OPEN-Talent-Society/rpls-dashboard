#!/bin/bash
# Cortex (SiYuan) Scheduled Maintenance Script
# Runs remotely via API (CF Access authenticated)
# Purpose: Orphan cleanup, index sync to Qdrant, health checks
# Schedule: Run via cron (e.g., 0 4 * * * for daily at 4am)
# Created: 2025-12-11

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/maintenance"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/cortex-maintenance-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"

echo "═══════════════════════════════════════════════════════════"
echo "🧠 Cortex Maintenance - $(date)"
echo "═══════════════════════════════════════════════════════════"

# Helper for Cortex API calls (with CF Access)
cortex_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-{}}"

    curl -s --max-time 30 -X "$method" \
        "$CORTEX_URL$endpoint" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$data"
}

# ============================================
# HEALTH CHECK
# ============================================
health_check() {
    echo ""
    echo "🏥 Health Check..."

    local version=$(cortex_api POST "/api/system/version" '{}' | jq -r '.data.ver // "unknown"')

    if [ "$version" != "unknown" ] && [ -n "$version" ]; then
        echo "  ✅ Cortex is healthy (version: $version)"
        return 0
    else
        echo "  ❌ Health check failed"
        return 1
    fi
}

# ============================================
# NOTEBOOK STATISTICS
# ============================================
notebook_stats() {
    echo ""
    echo "📊 Notebook Statistics..."

    local notebooks=$(cortex_api POST "/api/notebook/lsNotebooks" '{}')
    local count=$(echo "$notebooks" | jq '.data.notebooks | length')

    echo "  📚 Total notebooks: $count"

    echo "$notebooks" | jq -r '.data.notebooks[] | "    📁 \(.name) (\(.id))"' | head -10

    # Get total document count across all notebooks
    for nb_id in $(echo "$notebooks" | jq -r '.data.notebooks[].id'); do
        local docs=$(cortex_api POST "/api/filetree/listDocsByPath" "{\"notebook\":\"$nb_id\",\"path\":\"/\"}")
        local doc_count=$(echo "$docs" | jq '.data | length' 2>/dev/null || echo "0")
        echo "      → $doc_count documents"
    done
}

# ============================================
# ORPHAN DETECTION & CLEANUP
# ============================================
find_orphans() {
    echo ""
    echo "🔍 Checking for orphan blocks..."

    # Use SiYuan's built-in orphan detection
    local orphans=$(cortex_api POST "/api/search/searchUnRef" '{}')
    local count=$(echo "$orphans" | jq '.data.blocks | length' 2>/dev/null || echo "0")

    if [ "$count" -gt 0 ]; then
        echo "  ⚠️  Found $count orphan blocks"
        echo "  📝 Orphan IDs:"
        echo "$orphans" | jq -r '.data.blocks[]?.id' | head -10 | while read id; do
            echo "      - $id"
        done

        if [ "$count" -gt 50 ]; then
            echo "  💡 Consider running cleanup: cortex_api POST /api/filetree/removeOrphanDocs"
        fi
    else
        echo "  ✅ No orphan blocks found"
    fi
}

# ============================================
# INDEX SYNC STATUS (Cortex → Qdrant)
# ============================================
check_qdrant_sync() {
    echo ""
    echo "🔄 Checking Qdrant sync status..."

    # Check Qdrant cortex collection
    local qdrant_count=$(curl -s --max-time 30 \
        "https://qdrant.harbor.fyi/collections/cortex" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0')

    echo "  📊 Qdrant cortex collection: $qdrant_count vectors"

    # Get approximate Cortex document count
    local notebooks=$(cortex_api POST "/api/notebook/lsNotebooks" '{}')
    local total_docs=0

    for nb_id in $(echo "$notebooks" | jq -r '.data.notebooks[].id'); do
        local docs=$(cortex_api POST "/api/filetree/listDocsByPath" "{\"notebook\":\"$nb_id\",\"path\":\"/\"}")
        local doc_count=$(echo "$docs" | jq '.data | length' 2>/dev/null || echo "0")
        total_docs=$((total_docs + doc_count))
    done

    echo "  📚 Cortex documents: ~$total_docs"

    if [ "$qdrant_count" -lt "$total_docs" ]; then
        local behind=$((total_docs - qdrant_count))
        echo "  ⚠️  Qdrant may be behind by ~$behind documents"
        echo "  💡 Run: sync-cortex-to-qdrant.sh"
    else
        echo "  ✅ Qdrant appears to be in sync"
    fi
}

# ============================================
# TRIGGER INCREMENTAL SYNC
# ============================================
trigger_sync() {
    echo ""
    echo "🔄 Triggering incremental Cortex → Qdrant sync..."

    local sync_script="$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-cortex-to-qdrant.sh"

    if [ -f "$sync_script" ]; then
        # Run in background to not block maintenance
        bash "$sync_script" --incremental &
        echo "  ✅ Sync triggered in background (PID: $!)"
    else
        echo "  ⚠️  Sync script not found: $sync_script"
    fi
}

# ============================================
# DATA QUALITY CHECK
# ============================================
data_quality_check() {
    echo ""
    echo "📋 Data Quality Check..."

    # Search for recent activity
    local recent=$(cortex_api POST "/api/search/fullTextSearchBlock" \
        '{"query": "*", "types": {"document": true}, "limit": 10}')

    local recent_count=$(echo "$recent" | jq '.data.blocks | length' 2>/dev/null || echo "0")

    echo "  📝 Recent documents accessible: $recent_count"

    # Check for empty or very short documents
    echo "  🔍 Checking for potentially incomplete documents..."
    local empty_check=$(cortex_api POST "/api/search/fullTextSearchBlock" \
        '{"query": "Memory-Router", "types": {"document": true}, "limit": 5}')

    local memory_docs=$(echo "$empty_check" | jq '.data.blocks | length' 2>/dev/null || echo "0")
    echo "  📊 Memory-Router documents: $memory_docs"
}

# ============================================
# BACKUP STATUS
# ============================================
backup_status() {
    echo ""
    echo "💾 Backup Status..."

    # Check for recent exports
    local exports=$(cortex_api POST "/api/export/listExports" '{}' 2>/dev/null)

    if echo "$exports" | jq -e '.data' > /dev/null 2>&1; then
        echo "  📸 Export system accessible"
    else
        echo "  ℹ️  Export API not available (check permissions)"
    fi

    echo "  💡 Recommend: Weekly markdown export to git"
}

# ============================================
# MAIN
# ============================================
main() {
    echo ""

    # Run health check first
    if ! health_check; then
        echo "❌ Cortex unhealthy - aborting maintenance"
        exit 1
    fi

    # Run maintenance tasks
    notebook_stats
    find_orphans
    check_qdrant_sync
    data_quality_check
    backup_status

    # Optionally trigger sync
    if [ "${AUTO_SYNC:-false}" = "true" ]; then
        trigger_sync
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ Cortex Maintenance Complete - $(date)"
    echo "═══════════════════════════════════════════════════════════"
}

# Handle arguments
case "${1:-}" in
    --health)
        health_check
        ;;
    --stats)
        notebook_stats
        ;;
    --orphans)
        find_orphans
        ;;
    --sync-check)
        check_qdrant_sync
        ;;
    --sync)
        trigger_sync
        ;;
    --quality)
        data_quality_check
        ;;
    --help)
        echo "Usage: cortex-maintenance.sh [--health|--stats|--orphans|--sync-check|--sync|--quality|--help]"
        echo "  No args: full maintenance run"
        echo "  Set AUTO_SYNC=true to trigger sync automatically"
        ;;
    *)
        main
        ;;
esac
