#!/bin/bash
# Install Cron Jobs for Scheduled Maintenance Scripts
# Usage: bash install-cron-jobs.sh [--dry-run]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false

if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
fi

echo "═══════════════════════════════════════════════════════════"
echo "📅 Installing Scheduled Maintenance Cron Jobs"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Create required directories
echo "📁 Creating log directories..."
mkdir -p /Users/adamkovacs/.claude_code/logs
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/backups/cortex
echo "  ✅ Directories created"
echo ""

# Define cron jobs
CRON_JOBS=$(cat <<'EOF'
# Claude Memory Sync - Scheduled Infrastructure Maintenance
# Installed: $(date)

# Qdrant daily cleanup (2 AM)
0 2 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/qdrant-daily-cleanup.sh >> /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log 2>&1

# Cortex hourly validation (every hour at :15)
15 * * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-hourly-validate.sh >> /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log 2>&1

# Cortex daily backup (3 AM)
0 3 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-daily-backup.sh >> /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log 2>&1
EOF
)

# Check if jobs already exist
echo "🔍 Checking existing crontab..."
EXISTING_CRONTAB=$(crontab -l 2>/dev/null || echo "")

if echo "$EXISTING_CRONTAB" | grep -q "qdrant-daily-cleanup.sh"; then
    echo "  ⚠️  Cron jobs already installed"
    echo ""
    echo "Current scheduled jobs:"
    crontab -l | grep -A 10 "Claude Memory Sync"
    echo ""
    read -p "Do you want to reinstall? This will remove existing jobs. [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi

    # Remove existing jobs
    echo "🗑️  Removing existing jobs..."
    CLEANED_CRONTAB=$(echo "$EXISTING_CRONTAB" | sed '/# Claude Memory Sync - Scheduled Infrastructure Maintenance/,/cortex-daily-backup\.sh/d')
    echo "$CLEANED_CRONTAB" | crontab -
fi

echo ""
echo "📋 Jobs to be installed:"
echo "$CRON_JOBS"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 DRY RUN MODE - No changes made"
    echo ""
    echo "To install, run without --dry-run flag:"
    echo "  bash $0"
    exit 0
fi

# Install cron jobs
echo "📥 Installing cron jobs..."

# Get existing crontab (if any)
EXISTING_CRONTAB=$(crontab -l 2>/dev/null || echo "")

# Append new jobs
NEW_CRONTAB="$EXISTING_CRONTAB

$CRON_JOBS
"

# Install new crontab
echo "$NEW_CRONTAB" | crontab -

echo "  ✅ Cron jobs installed"
echo ""

# Verify installation
echo "✅ Verification:"
crontab -l | grep -A 10 "Claude Memory Sync"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "✅ Installation Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "📊 Scheduled Jobs:"
echo "  - Qdrant Cleanup:        Daily at 2:00 AM"
echo "  - Cortex Validation:     Hourly at :15 minutes"
echo "  - Cortex Backup:         Daily at 3:00 AM"
echo ""
echo "📁 Log Locations:"
echo "  - Qdrant:    /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log"
echo "  - Cortex Val: /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log"
echo "  - Cortex Bak: /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log"
echo ""
echo "📝 Health Reports:"
echo "  /Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports/"
echo ""
echo "💡 Next Steps:"
echo "  1. Setup Supabase pg_cron (see supabase-weekly-cleanup.sql)"
echo "  2. Monitor logs: tail -f /Users/adamkovacs/.claude_code/logs/*.log"
echo "  3. Test scripts manually before waiting for scheduled runs"
echo ""
echo "🧪 Test Now (Optional):"
echo "  bash $SCRIPT_DIR/cortex-hourly-validate.sh"
echo ""
