# Scheduled Infrastructure Maintenance Scripts

Automated maintenance scripts for infrastructure containers (Qdrant, Cortex, Supabase).

## Scripts Overview

### 1. qdrant-daily-cleanup.sh
**Container:** harbor-home (Qdrant Vector Database)
**Schedule:** Daily at 2:00 AM
**Purpose:**
- Cleanup orphaned vectors (content_hash doesn't exist in source)
- Remove vectors older than 90 days with low relevance scores
- Compact collections for optimal performance

**Cron Entry:**
```bash
0 2 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/qdrant-daily-cleanup.sh >> /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log 2>&1
```

**Manual Execution:**
```bash
bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/qdrant-daily-cleanup.sh
```

### 2. cortex-hourly-validate.sh
**Container:** OCI (Cortex/SiYuan)
**Schedule:** Hourly at :15 minutes past the hour
**Purpose:**
- Check for orphan documents (no references)
- Validate custom-category attributes exist
- Generate health report (JSON)

**Cron Entry:**
```bash
15 * * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-hourly-validate.sh >> /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log 2>&1
```

**Manual Execution:**
```bash
bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-hourly-validate.sh
```

**Health Reports Location:**
```
/Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports/cortex-health-*.json
```

### 3. cortex-daily-backup.sh
**Container:** OCI (Cortex/SiYuan)
**Schedule:** Daily at 3:00 AM
**Purpose:**
- Export all notebooks to markdown
- Sync to NAS backup location (if mounted)
- Prune backups older than 30 days

**Cron Entry:**
```bash
0 3 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-daily-backup.sh >> /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log 2>&1
```

**Manual Execution:**
```bash
bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-daily-backup.sh
```

**Backup Locations:**
- Local: `/Users/adamkovacs/Documents/codebuild/.claude/backups/cortex/`
- NAS: `/Volumes/NAS/backups/cortex/` (if NAS_BACKUP_PATH env var is set)

### 4. supabase-weekly-cleanup.sql
**Database:** Supabase (PostgreSQL)
**Schedule:** Weekly on Sunday at 4:00 AM
**Purpose:**
- Delete learnings older than 180 days with no references
- Delete patterns with success_count = 0 and older than 90 days
- Delete duplicate learnings (same task_id + context)
- Delete old telemetry (>7 days)
- Vacuum tables to reclaim space

**Setup with pg_cron (Supabase):**

1. Enable pg_cron extension (Supabase Dashboard → Database → Extensions)
2. Run the SQL script manually first to test:
```bash
psql $DATABASE_URL -f /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/supabase-weekly-cleanup.sql
```

3. Uncomment the pg_cron setup section at the bottom of the SQL file and execute in Supabase SQL Editor

**Manual Execution:**
```bash
# Via psql
psql $PUBLIC_SUPABASE_URL -f /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/supabase-weekly-cleanup.sql

# OR via Supabase SQL Editor
# Copy/paste the SQL file and execute
```

**Check scheduled jobs:**
```sql
SELECT * FROM cron.job;
```

**Unschedule job:**
```sql
SELECT cron.unschedule('supabase-weekly-cleanup');
```

## Installation Instructions

### macOS (Local Development)

1. **Create log directories:**
```bash
mkdir -p /Users/adamkovacs/.claude_code/logs
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/logs/maintenance
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports
mkdir -p /Users/adamkovacs/Documents/codebuild/.claude/backups/cortex
```

2. **Add to crontab:**
```bash
crontab -e
```

Add these lines:
```bash
# Qdrant daily cleanup (2 AM)
0 2 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/qdrant-daily-cleanup.sh >> /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log 2>&1

# Cortex hourly validation (every hour at :15)
15 * * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-hourly-validate.sh >> /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log 2>&1

# Cortex daily backup (3 AM)
0 3 * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-daily-backup.sh >> /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log 2>&1
```

3. **Verify cron jobs:**
```bash
crontab -l
```

### Supabase (pg_cron)

See instructions in `supabase-weekly-cleanup.sql` file.

## Environment Variables Required

All scripts use individual variable extraction to avoid zsh parse errors:

```bash
# .env file must contain:
QDRANT_URL=https://qdrant.harbor.fyi
QDRANT_API_KEY=your_key_here

CORTEX_URL=https://cortex.aienablement.academy
CORTEX_TOKEN=your_token_here
CF_ACCESS_CLIENT_ID=your_client_id
CF_ACCESS_CLIENT_SECRET=your_client_secret

# Optional for NAS backups
NAS_BACKUP_PATH=/Volumes/NAS/backups/cortex
```

## Monitoring

### Check Logs

```bash
# Qdrant cleanup
tail -f /Users/adamkovacs/.claude_code/logs/qdrant-daily-cleanup.log

# Cortex validation
tail -f /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log

# Cortex backup
tail -f /Users/adamkovacs/.claude_code/logs/cortex-daily-backup.log
```

### Health Reports

Cortex validation generates JSON health reports hourly:
```bash
# View latest health report
cat /Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports/cortex-health-*.json | jq .

# Monitor health status
watch -n 60 'cat /Users/adamkovacs/Documents/codebuild/.claude/logs/health-reports/cortex-health-$(date +%Y%m%d-%H).json | jq .'
```

### Backup Verification

```bash
# Check local backups
ls -lh /Users/adamkovacs/Documents/codebuild/.claude/backups/cortex/

# Check NAS backups (if mounted)
ls -lh /Volumes/NAS/backups/cortex/
```

## Troubleshooting

### Qdrant Cleanup Issues

**Problem:** High orphan count
**Solution:** Check Qdrant collection integrity, run manual cleanup

**Problem:** Compaction fails
**Solution:** Check Qdrant logs, ensure sufficient disk space

### Cortex Validation Issues

**Problem:** Authentication errors
**Solution:** Verify CF_ACCESS_CLIENT_ID and CF_ACCESS_CLIENT_SECRET are valid

**Problem:** High orphan count
**Solution:** Review document linking strategy, consider manual cleanup

### Cortex Backup Issues

**Problem:** NAS not mounted
**Solution:** Script will skip NAS sync gracefully, mount NAS or set NAS_BACKUP_PATH

**Problem:** Export timeouts
**Solution:** Increase curl timeout in script, or run during low-traffic hours

### Supabase Cleanup Issues

**Problem:** pg_cron not available
**Solution:** Enable pg_cron extension in Supabase Dashboard

**Problem:** Permission errors
**Solution:** Use service role key, ensure user has DELETE permissions

## Performance Impact

| Script | CPU Impact | Network Impact | Duration |
|--------|-----------|----------------|----------|
| qdrant-daily-cleanup.sh | Low | Medium | 2-5 min |
| cortex-hourly-validate.sh | Very Low | Low | 30-60 sec |
| cortex-daily-backup.sh | Medium | High | 5-15 min |
| supabase-weekly-cleanup.sql | Medium | N/A | 1-3 min |

## Maintenance Schedule Summary

```
00:00 - Midnight
01:00
02:00 - [Qdrant Daily Cleanup]
03:00 - [Cortex Daily Backup]
04:00 - [Supabase Weekly Cleanup] (Sundays only)
05:00
...
:15 - [Cortex Hourly Validation] (every hour)
...
23:00
```

## Related Scripts

- **Full sync:** `sync-all.sh` - Sync all memory backends
- **Manual maintenance:** `maintenance/qdrant-maintenance.sh`, `maintenance/cortex-maintenance.sh`
- **Stats:** `memory-stats.sh` - View memory system statistics

## Version History

- **2025-12-12:** Initial creation with 4 scheduled scripts
