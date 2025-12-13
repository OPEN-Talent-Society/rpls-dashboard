#!/bin/bash
# Cortex Daily Backup Script
# Container: OCI (Cortex/SiYuan)
# Purpose: Export all notebooks to markdown, sync to NAS, prune old backups
# Schedule: Daily at 3:00 AM
# Cron: 0 3 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-daily-backup.sh >> /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log 2>&1

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/maintenance"
BACKUP_DIR="$PROJECT_DIR/.claude/backups/cortex"
NAS_BACKUP_DIR="${NAS_BACKUP_PATH:-/Volumes/NAS/backups/cortex}"

mkdir -p "$LOG_DIR" "$BACKUP_DIR"

LOG_FILE="$LOG_DIR/cortex-daily-backup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "═══════════════════════════════════════════════════════════"
echo "💾 Cortex Daily Backup - $(date)"
echo "═══════════════════════════════════════════════════════════"

# Load environment (extract vars individually to avoid zsh parse errors)
if [ -f "$PROJECT_DIR/.env" ]; then
    CORTEX_URL=$(grep "^CORTEX_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
fi

[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"

# Backup timestamp
BACKUP_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_SUBDIR="$BACKUP_DIR/$BACKUP_TIMESTAMP"
mkdir -p "$BACKUP_SUBDIR"

# Statistics
NOTEBOOKS_EXPORTED=0
DOCUMENTS_EXPORTED=0
BACKUP_SIZE=0

# Helper for Cortex API calls (with CF Access)
cortex_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-{}}"

    curl -s --max-time 60 -X "$method" \
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
# EXPORT ALL NOTEBOOKS TO MARKDOWN
# ============================================
export_notebooks() {
    echo ""
    echo "📚 Exporting all notebooks to markdown..."

    # Get list of notebooks
    local notebooks=$(cortex_api POST "/api/notebook/lsNotebooks" '{}')
    local nb_count=$(echo "$notebooks" | jq '.data.notebooks | length')

    echo "  📊 Found $nb_count notebooks to export"

    # Export each notebook
    for nb_entry in $(echo "$notebooks" | jq -r '.data.notebooks[] | @base64'); do
        local nb_data=$(echo "$nb_entry" | base64 -d 2>/dev/null || echo "$nb_entry" | base64 -D)
        local nb_id=$(echo "$nb_data" | jq -r '.id')
        local nb_name=$(echo "$nb_data" | jq -r '.name')

        echo "  📁 Exporting: $nb_name ($nb_id)"

        # Create notebook directory
        local nb_dir="$BACKUP_SUBDIR/$nb_name"
        mkdir -p "$nb_dir"

        # Get all documents in notebook
        local docs=$(cortex_api POST "/api/query/sql" \
            "{\"stmt\": \"SELECT id, content FROM blocks WHERE type='d' AND box='${nb_id}' LIMIT 10000\"}")

        local doc_count=$(echo "$docs" | jq '.data | length' 2>/dev/null || echo "0")
        echo "    📄 Exporting $doc_count documents..."

        # Export each document
        local exported=0
        for doc_entry in $(echo "$docs" | jq -r '.data[] | @base64'); do
            local doc_data=$(echo "$doc_entry" | base64 -d 2>/dev/null || echo "$doc_entry" | base64 -D)
            local doc_id=$(echo "$doc_data" | jq -r '.id')

            # Get full document content
            local doc_content=$(cortex_api POST "/api/export/exportMdContent" \
                "{\"id\": \"${doc_id}\"}")

            local markdown=$(echo "$doc_content" | jq -r '.data.content // ""')

            if [ -n "$markdown" ] && [ "$markdown" != "null" ]; then
                # Extract title from first line
                local title=$(echo "$markdown" | head -1 | sed 's/^#* *//' | tr '/' '-')
                [ -z "$title" ] && title="untitled-$doc_id"

                # Save to file
                local filename="${title}.md"
                echo "$markdown" > "$nb_dir/$filename"
                exported=$((exported + 1))
            fi

            # Rate limiting
            sleep 0.1
        done

        echo "    ✅ Exported $exported/$doc_count documents"
        NOTEBOOKS_EXPORTED=$((NOTEBOOKS_EXPORTED + 1))
        DOCUMENTS_EXPORTED=$((DOCUMENTS_EXPORTED + exported))
    done
}

# ============================================
# SYNC TO NAS BACKUP LOCATION
# ============================================
sync_to_nas() {
    echo ""
    echo "🔄 Syncing to NAS backup location..."

    # Check if NAS is mounted
    if [ ! -d "$(dirname "$NAS_BACKUP_DIR")" ]; then
        echo "  ⚠️  NAS not mounted - skipping NAS sync"
        echo "  💡 Mount path: $(dirname "$NAS_BACKUP_DIR")"
        return 0
    fi

    mkdir -p "$NAS_BACKUP_DIR"

    # Create dated backup on NAS
    local nas_dated_dir="$NAS_BACKUP_DIR/$BACKUP_TIMESTAMP"

    echo "  📂 Copying to: $nas_dated_dir"

    # Use rsync for efficient copy
    if command -v rsync &> /dev/null; then
        rsync -av --progress "$BACKUP_SUBDIR/" "$nas_dated_dir/"
        echo "  ✅ Synced to NAS using rsync"
    else
        cp -R "$BACKUP_SUBDIR" "$nas_dated_dir"
        echo "  ✅ Copied to NAS using cp"
    fi

    # Also maintain a "latest" symlink
    rm -f "$NAS_BACKUP_DIR/latest"
    ln -s "$nas_dated_dir" "$NAS_BACKUP_DIR/latest"
    echo "  🔗 Updated 'latest' symlink"
}

# ============================================
# PRUNE OLD BACKUPS (>30 days)
# ============================================
prune_old_backups() {
    echo ""
    echo "🗑️  Pruning backups older than 30 days..."

    local pruned=0

    # Prune local backups
    if [ -d "$BACKUP_DIR" ]; then
        echo "  📁 Checking local backups: $BACKUP_DIR"

        for backup in "$BACKUP_DIR"/*; do
            [ ! -d "$backup" ] && continue

            # Get backup age in days (macOS compatible)
            local backup_date=$(basename "$backup" | cut -d'-' -f1)
            local backup_epoch=$(date -j -f "%Y%m%d" "$backup_date" +%s 2>/dev/null || echo "0")
            local now_epoch=$(date +%s)
            local age_days=$(( (now_epoch - backup_epoch) / 86400 ))

            if [ "$age_days" -gt 30 ]; then
                echo "    🗑️  Removing: $(basename "$backup") (${age_days} days old)"
                rm -rf "$backup"
                pruned=$((pruned + 1))
            fi
        done
    fi

    # Prune NAS backups
    if [ -d "$NAS_BACKUP_DIR" ]; then
        echo "  📁 Checking NAS backups: $NAS_BACKUP_DIR"

        for backup in "$NAS_BACKUP_DIR"/*; do
            [ ! -d "$backup" ] && continue
            [ "$(basename "$backup")" = "latest" ] && continue

            # Get backup age in days
            local backup_date=$(basename "$backup" | cut -d'-' -f1)
            local backup_epoch=$(date -j -f "%Y%m%d" "$backup_date" +%s 2>/dev/null || echo "0")
            local now_epoch=$(date +%s)
            local age_days=$(( (now_epoch - backup_epoch) / 86400 ))

            if [ "$age_days" -gt 30 ]; then
                echo "    🗑️  Removing: $(basename "$backup") (${age_days} days old)"
                rm -rf "$backup"
                pruned=$((pruned + 1))
            fi
        done
    fi

    if [ "$pruned" -gt 0 ]; then
        echo "  ✅ Pruned $pruned old backups"
    else
        echo "  ✅ No old backups to prune"
    fi
}

# ============================================
# CALCULATE BACKUP SIZE
# ============================================
calculate_backup_size() {
    echo ""
    echo "📊 Calculating backup size..."

    if [ -d "$BACKUP_SUBDIR" ]; then
        # macOS compatible du command
        BACKUP_SIZE=$(du -sk "$BACKUP_SUBDIR" | cut -f1)
        local size_mb=$((BACKUP_SIZE / 1024))
        echo "  💾 Backup size: ${size_mb} MB"
    fi
}

# ============================================
# STATISTICS REPORT
# ============================================
print_stats() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "📊 Backup Statistics"
    echo "═══════════════════════════════════════════════════════════"
    echo "  📚 Notebooks exported: $NOTEBOOKS_EXPORTED"
    echo "  📄 Documents exported: $DOCUMENTS_EXPORTED"
    echo "  💾 Backup size: $((BACKUP_SIZE / 1024)) MB"
    echo "  📂 Backup location: $BACKUP_SUBDIR"
    [ -d "$NAS_BACKUP_DIR" ] && echo "  🔄 NAS location: $NAS_BACKUP_DIR/$BACKUP_TIMESTAMP"
    echo "═══════════════════════════════════════════════════════════"
}

# ============================================
# MAIN
# ============================================
main() {
    echo ""

    # Run health check first
    if ! health_check; then
        echo "❌ Cortex unhealthy - aborting backup"
        exit 1
    fi

    # Run backup tasks
    export_notebooks
    calculate_backup_size
    sync_to_nas
    prune_old_backups

    # Print statistics
    print_stats

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ Cortex Daily Backup Complete - $(date)"
    echo "═══════════════════════════════════════════════════════════"
}

# Run main
main
