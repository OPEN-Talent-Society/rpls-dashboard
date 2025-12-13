#!/bin/bash
# Setup Cron Jobs for Memory System Maintenance
# Run this script ONCE to install cron jobs
# Created: 2025-12-11

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
MAINTENANCE_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts/maintenance"
SCRIPT_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts"

echo "═══════════════════════════════════════════════════════════"
echo "🕐 Memory System Cron Setup"
echo "═══════════════════════════════════════════════════════════"

# Make scripts executable
chmod +x "$MAINTENANCE_DIR"/*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR/memory-router.sh" 2>/dev/null || true

# Define cron jobs
# Format: minute hour day month weekday command
CRON_JOBS=$(cat <<'CRONTAB'
# ═══════════════════════════════════════════════════════════
# Memory System Maintenance - Auto-generated
# ═══════════════════════════════════════════════════════════

# Memory Router - Every 15 minutes (incremental sync)
*/15 * * * * /bin/bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/memory-router.sh >> /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/memory-router.log 2>&1

# Qdrant Maintenance - Daily at 3:00 AM
0 3 * * * /bin/bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/maintenance/qdrant-maintenance.sh >> /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/qdrant-daily.log 2>&1

# Cortex Maintenance - Daily at 4:00 AM
0 4 * * * /bin/bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/maintenance/cortex-maintenance.sh >> /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/cortex-daily.log 2>&1

# Supabase Cleanup - Weekly on Sunday at 2:00 AM
0 2 * * 0 /bin/bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/weekly-cleanup.sh >> /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/supabase-weekly.log 2>&1

# Full Memory Sync - Every 6 hours
0 */6 * * * /bin/bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-all.sh --cold-only >> /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance/full-sync.log 2>&1

# Log Rotation - Weekly on Saturday at 1:00 AM
0 1 * * 6 find /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance -name "*.log" -mtime +30 -delete

# ═══════════════════════════════════════════════════════════
CRONTAB
)

echo ""
echo "📋 Proposed Cron Jobs:"
echo "$CRON_JOBS" | grep -v "^#" | grep -v "^$" | while read line; do
    echo "  • $line"
done

echo ""
echo "⚠️  This will REPLACE any existing memory-related cron jobs."
echo ""

read -p "Install these cron jobs? (y/N) " confirm

if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ Aborted"
    exit 0
fi

# Create log directory
mkdir -p "$PROJECT_DIR/.claude/logs/maintenance"

# Backup existing crontab
BACKUP_FILE="/tmp/crontab-backup-$(date +%Y%m%d-%H%M%S)"
crontab -l > "$BACKUP_FILE" 2>/dev/null || echo "# No existing crontab" > "$BACKUP_FILE"
echo "💾 Backed up existing crontab to: $BACKUP_FILE"

# Remove old memory-related jobs and add new ones
{
    # Keep non-memory jobs from existing crontab
    crontab -l 2>/dev/null | grep -v "memory-router\|qdrant-maintenance\|cortex-maintenance\|weekly-cleanup\|sync-all\|Memory System Maintenance" || true

    # Add new jobs
    echo "$CRON_JOBS"
} | crontab -

echo ""
echo "✅ Cron jobs installed!"
echo ""
echo "📊 Schedule Summary:"
echo "  • Memory Router: Every 15 min (incremental)"
echo "  • Qdrant: Daily 3am (full maintenance)"
echo "  • Cortex: Daily 4am (full maintenance)"
echo "  • Supabase Cleanup: Weekly Sunday 2am"
echo "  • Full Sync: Every 6 hours"
echo "  • Log Rotation: Weekly Saturday 1am"
echo ""
echo "📝 View cron jobs: crontab -l"
echo "📝 Edit cron jobs: crontab -e"
echo "📝 Remove all: crontab -r"
echo ""
echo "📂 Logs will be in: $PROJECT_DIR/.claude/logs/maintenance/"
