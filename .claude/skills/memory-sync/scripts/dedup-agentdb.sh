#!/bin/bash
# Deduplicate AgentDB episodes - keeps highest reward per unique task
# Run with --dry-run to see what would be deleted

set -e

AGENTDB="/Users/adamkovacs/Documents/codebuild/agentdb.db"
DRY_RUN=false

if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be made"
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              AGENTDB DEDUPLICATION                           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Current stats
TOTAL=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes;")
UNIQUE=$(sqlite3 "$AGENTDB" "SELECT COUNT(DISTINCT task) FROM episodes;")
DUPLICATES=$((TOTAL - UNIQUE))

echo "📊 Current State:"
echo "   Total episodes: $TOTAL"
echo "   Unique tasks: $UNIQUE"
echo "   Duplicate entries: $DUPLICATES"
echo ""

if [ "$DUPLICATES" -eq 0 ]; then
    echo "✅ No duplicates found!"
    exit 0
fi

# Show top duplicates
echo "📋 Top Duplicate Tasks:"
sqlite3 "$AGENTDB" "
SELECT task, COUNT(*) as cnt, MAX(reward) as max_reward
FROM episodes
GROUP BY task
HAVING cnt > 1
ORDER BY cnt DESC
LIMIT 10;
" | while IFS='|' read -r task cnt reward; do
    echo "   [$cnt copies] $task (best reward: $reward)"
done

echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 Would delete $DUPLICATES duplicate entries"
    echo "   Run without --dry-run to execute"
    exit 0
fi

# Create backup
BACKUP="${AGENTDB}.backup-$(date +%Y%m%d-%H%M%S)"
echo "💾 Creating backup: $BACKUP"
cp "$AGENTDB" "$BACKUP"

# Deduplication strategy:
# Keep the episode with highest reward for each task
# If rewards equal, keep the latest (highest id)

echo ""
echo "🗑️  Removing duplicates (keeping best reward per task)..."

sqlite3 "$AGENTDB" "
DELETE FROM episodes
WHERE id NOT IN (
    SELECT id FROM (
        SELECT id,
               ROW_NUMBER() OVER (
                   PARTITION BY task
                   ORDER BY reward DESC, id DESC
               ) as rn
        FROM episodes
    )
    WHERE rn = 1
);
"

# New stats
NEW_TOTAL=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes;")
DELETED=$((TOTAL - NEW_TOTAL))

echo ""
echo "✅ Deduplication Complete:"
echo "   Before: $TOTAL episodes"
echo "   After: $NEW_TOTAL episodes"
echo "   Deleted: $DELETED duplicates"
echo ""
echo "   Backup saved to: $BACKUP"

# Vacuum to reclaim space
echo ""
echo "🧹 Vacuuming database..."
sqlite3 "$AGENTDB" "VACUUM;"

SIZE_BEFORE=$(du -h "$BACKUP" | cut -f1)
SIZE_AFTER=$(du -h "$AGENTDB" | cut -f1)
echo "   Size before: $SIZE_BEFORE"
echo "   Size after: $SIZE_AFTER"
