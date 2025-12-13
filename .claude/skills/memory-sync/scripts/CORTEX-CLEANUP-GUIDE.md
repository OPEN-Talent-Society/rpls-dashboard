# Cortex Pollution Cleanup Guide

## Overview

The `cleanup-cortex-pollution.sh` script identifies and removes polluted documents from Cortex (SiYuan) that were created during sync operations or data migrations.

**Location:** `.claude/skills/memory-sync/scripts/cleanup-cortex-pollution.sh`

## Pollution Patterns Detected

### 1. Chunk Pollution
- **Pattern:** Documents with titles containing "chunk-" or "chunk"
- **Cause:** Smart chunking creating individual documents instead of embedding chunks
- **Example:** `chunk-20251212-001.md`, `Document chunk 1 of 5`

### 2. Supabase Dumps
- **Pattern:** Documents starting with "supabase" or "Supabase"
- **Cause:** Direct database dumps being synced as documents
- **Example:** `supabase_learnings_export.md`, `Supabase Pattern Dump`

### 3. Verbatim Dumps
- **Pattern:** Documents starting with "Episode-", "Pattern-", "Learning-"
- **Cause:** Raw AgentDB records being dumped without curation
- **Example:** `Episode-1234567890.md`, `Pattern-uuid-12345.md`

### 4. .md Extension Duplicates
- **Pattern:** Documents where both "Title" and "Title.md" exist
- **Cause:** File sync creating duplicates with extensions
- **Example:** `Meeting Notes` and `Meeting Notes.md`

## Usage

### Basic Commands

```bash
# Dry run - see what would be deleted (RECOMMENDED FIRST)
./cleanup-cortex-pollution.sh --dry-run

# Delete up to 100 pollution documents (safe default)
./cleanup-cortex-pollution.sh --limit 100

# Delete specific pollution type only
./cleanup-cortex-pollution.sh --type chunks --limit 50
./cleanup-cortex-pollution.sh --type supabase --limit 50
./cleanup-cortex-pollution.sh --type verbatim --limit 50
./cleanup-cortex-pollution.sh --type md-dupes --limit 50

# Delete all pollution (USE WITH CAUTION!)
./cleanup-cortex-pollution.sh --limit 0
```

### Command Options

| Option | Description | Default |
|--------|-------------|---------|
| `--dry-run` | Report pollution without deleting | `false` |
| `--limit N` | Maximum documents to delete (0=unlimited) | `100` |
| `--type TYPE` | Only clean specific type | `all` |
| `--help` | Show help message | - |

### Types Available

- `chunks` - Only chunk pollution
- `supabase` - Only Supabase dumps
- `verbatim` - Only verbatim dumps (Episode/Pattern/Learning)
- `md-dupes` - Only .md extension duplicates
- `all` - All pollution types (default)

## Output

### Console Output
Real-time progress with:
- Scanning progress
- Pollution counts by type
- Deletion progress (batched)
- Final summary

### Log File
Detailed log saved to: `/tmp/cortex-cleanup-TIMESTAMP.log`

Contains:
- Document IDs of all pollution found
- Deletion results for each document
- API response details
- Timestamp for audit trail

## Recommended Workflow

### 1. Initial Assessment (Dry Run)
```bash
# See what pollution exists
./cleanup-cortex-pollution.sh --dry-run
```

Review the output to understand:
- Total pollution count
- Distribution across types
- Sample documents that would be deleted

### 2. Cautious Cleanup (Limited)
```bash
# Start with small batch
./cleanup-cortex-pollution.sh --limit 50
```

Verify:
- Check Cortex to ensure correct documents were deleted
- Review `/tmp/cortex-cleanup-*.log` for details
- Confirm no legitimate content was removed

### 3. Targeted Cleanup (By Type)
```bash
# Clean one type at a time
./cleanup-cortex-pollution.sh --type chunks --limit 100
./cleanup-cortex-pollution.sh --type supabase --limit 100
# ... etc
```

### 4. Full Cleanup (If Confident)
```bash
# Remove all pollution
./cleanup-cortex-pollution.sh --limit 0
```

## Safety Features

### Rate Limiting
- Processes deletions in batches of 50
- 0.5 second delay between batches
- Prevents API overload

### Authentication
- Uses Cloudflare Zero Trust authentication
- Requires valid service token
- Prevents unauthorized access

### Dry Run Mode
- No deletions performed
- Shows exactly what would be deleted
- Safe for assessment

### Deletion Limits
- Default limit of 100 documents
- Prevents accidental mass deletion
- Can be overridden with `--limit 0`

### Legitimate Content Protection
The script preserves:
- Documents with meaningful titles
- Curated knowledge base content
- Manually created documents
- Properly formatted documents without pollution patterns

## Environment Variables Required

```bash
# From .env file
CORTEX_TOKEN=<your-token>
CORTEX_URL=https://cortex.aienablement.academy
CF_ACCESS_CLIENT_ID=<your-client-id>
CF_ACCESS_CLIENT_SECRET=<your-client-secret>
```

The script automatically extracts these individually to avoid zsh parse errors.

## Troubleshooting

### "CORTEX_TOKEN not set"
- Ensure `.env` file exists in project root
- Check that `CORTEX_TOKEN` is defined in `.env`

### "CF_ACCESS_CLIENT_ID not set"
- Verify Cloudflare Zero Trust service token is configured
- Check `.env` for `CF_ACCESS_CLIENT_ID` and `CF_ACCESS_CLIENT_SECRET`

### API timeout errors
- Script has 30-second timeout per request
- Large notebooks may need longer timeout
- Consider cleaning by type for large datasets

### Deletion failures
- Check log file for API error responses
- Verify document IDs are valid
- Ensure Cortex API permissions allow deletion

### No pollution found
- If dry run shows 0 pollution, cleanup was already performed
- Or pollution patterns don't match current data
- Adjust patterns in script if needed

## After Cleanup

### 1. Verify Cortex
- Browse notebooks in Cortex UI
- Confirm pollution is removed
- Check that legitimate content remains

### 2. Re-sync to Qdrant
```bash
# Full re-index after cleanup
./sync-cortex-to-qdrant.sh
```

This ensures Qdrant reflects the cleaned Cortex state.

### 3. Update Prevention
Fix root cause to prevent pollution:
- Update sync scripts to use upsert logic
- Configure smart-chunker to embed, not create docs
- Add validation in sync-to-cortex scripts

## Integration with Maintenance

Add to weekly maintenance routine:

```bash
# In cortex-maintenance.sh or cron
# Check for new pollution weekly
/path/to/cleanup-cortex-pollution.sh --dry-run

# Auto-cleanup if pollution > threshold
POLLUTION_COUNT=$(grep "TOTAL POLLUTION" /tmp/cortex-cleanup-*.log | tail -1 | awk '{print $4}')
if [ "$POLLUTION_COUNT" -gt 50 ]; then
    /path/to/cleanup-cortex-pollution.sh --limit 100
fi
```

## Performance

- **Scanning:** ~1-2 minutes for 1000 documents
- **Deletion:** ~50 documents per minute (rate limited)
- **Memory:** Low memory footprint (~50MB)
- **Network:** Minimal bandwidth usage

## Logs

All cleanup operations are logged to `/tmp/cortex-cleanup-TIMESTAMP.log`

Log retention:
- Logs are timestamped
- Not automatically cleaned (manual cleanup needed)
- Consider archiving important cleanup logs

## Best Practices

1. **Always dry run first** - Never delete without seeing what will be removed
2. **Use limits** - Start small, increase gradually
3. **Clean by type** - Easier to verify correctness
4. **Check logs** - Review deletion results
5. **Verify Cortex** - Manually check after cleanup
6. **Re-sync Qdrant** - Keep semantic layer in sync
7. **Fix root cause** - Update sync scripts to prevent recurrence

## Related Scripts

- `sync-cortex-to-qdrant.sh` - Sync Cortex to Qdrant (creates chunks in Qdrant, not Cortex)
- `cortex-maintenance.sh` - Regular Cortex health checks
- `sync-from-cortex.sh` - Import curated content from Cortex

## Version History

- **2025-12-12** - Initial version
  - Four pollution pattern types
  - Dry run mode
  - Batched deletion with rate limiting
  - Comprehensive logging

---

**Last Updated:** 2025-12-12
**Maintainer:** Claude Code Memory Sync System
