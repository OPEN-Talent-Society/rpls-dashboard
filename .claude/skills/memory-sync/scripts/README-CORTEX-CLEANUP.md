# Cortex Pollution Cleanup - Quick Start

## TL;DR

```bash
# Step 1: See what pollution exists (SAFE - no deletion)
./cleanup-cortex-pollution.sh --dry-run

# Step 2: Clean up to 100 pollution documents (RECOMMENDED)
./cleanup-cortex-pollution.sh --limit 100

# Step 3: Re-sync to Qdrant after cleanup
./sync-cortex-to-qdrant.sh
```

## What It Does

Identifies and removes 4 types of pollution from Cortex:

| Type | Pattern | Example |
|------|---------|---------|
| 🧩 Chunks | Contains "chunk-" or "chunk" | `chunk-20251212-001.md` |
| 🗃️ Supabase | Starts with "supabase" | `Supabase Learning Export` |
| 📋 Verbatim | Starts with Episode-/Pattern-/Learning- | `Episode-1234567890` |
| 📄 .md Dupes | Both "Title" and "Title.md" exist | `Meeting Notes.md` (when `Meeting Notes` exists) |

## Common Commands

```bash
# Dry run - see what would be deleted
./cleanup-cortex-pollution.sh --dry-run

# Clean specific type only
./cleanup-cortex-pollution.sh --type chunks --limit 50
./cleanup-cortex-pollution.sh --type supabase --limit 50
./cleanup-cortex-pollution.sh --type verbatim --limit 50
./cleanup-cortex-pollution.sh --type md-dupes --limit 50

# Clean all pollution (default limit: 100)
./cleanup-cortex-pollution.sh --limit 100

# Clean all pollution (no limit - USE WITH CAUTION!)
./cleanup-cortex-pollution.sh --limit 0
```

## Output

### Console
```
═══════════════════════════════════════════════════════════
🧹 Cortex Pollution Cleanup - Thu Dec 12 14:28:00 PST 2025
═══════════════════════════════════════════════════════════

Configuration:
  Cortex URL: https://cortex.aienablement.academy
  Cleanup type: all
  Dry run: false
  Delete limit: 100

📚 Scanning all notebooks for documents...

🔍 Identifying pollution patterns...

═══════════════════════════════════════════════════════════
📊 Pollution Report
═══════════════════════════════════════════════════════════

Pollution found:
  🧩 Chunk pollution:        15 documents
  🗃️  Supabase dumps:         8 documents
  📋 Verbatim dumps:         23 documents
  📄 .md duplicates:         5 documents

  ⚠️  TOTAL POLLUTION:       51 documents

Legitimate content:
  ✅ Clean documents:        342 documents

🗑️  Processing 15 chunk documents...
  🗑️  Deleting: chunk-20251212-001 (abc123)
    ✅ Deleted successfully
  ...

✅ Cleanup Complete
```

### Log File
Detailed log saved to: `/tmp/cortex-cleanup-TIMESTAMP.log`

Contains:
- All document IDs processed
- Deletion results
- API responses
- Audit trail

## Safety Features

1. **Dry Run Mode** - See exactly what would be deleted
2. **Deletion Limits** - Default 100, prevents mass deletion
3. **Rate Limiting** - 50 docs/batch, 0.5s delay
4. **Authentication** - Cloudflare Zero Trust required
5. **Logging** - Complete audit trail

## Environment Required

```bash
CORTEX_TOKEN=<your-token>
CORTEX_URL=https://cortex.aienablement.academy
CF_ACCESS_CLIENT_ID=<your-client-id>
CF_ACCESS_CLIENT_SECRET=<your-client-secret>
```

These are automatically loaded from `/Users/adamkovacs/Documents/codebuild/.env`

## After Cleanup

```bash
# Re-sync Cortex to Qdrant
./sync-cortex-to-qdrant.sh

# Verify cleanup
./cortex-maintenance.sh --stats
```

## Troubleshooting

| Error | Solution |
|-------|----------|
| `CORTEX_TOKEN not set` | Check `.env` file exists and contains `CORTEX_TOKEN` |
| `CF_ACCESS_CLIENT_ID not set` | Verify Cloudflare service token in `.env` |
| API timeout | Use `--type` to clean smaller batches |
| No pollution found | Already cleaned, or patterns don't match |

## Files

- **Script:** `.claude/skills/memory-sync/scripts/cleanup-cortex-pollution.sh`
- **Guide:** `.claude/skills/memory-sync/scripts/CORTEX-CLEANUP-GUIDE.md`
- **This README:** `.claude/skills/memory-sync/scripts/README-CORTEX-CLEANUP.md`

## Related Scripts

- `sync-cortex-to-qdrant.sh` - Sync Cortex to Qdrant
- `cortex-maintenance.sh` - Cortex health checks
- `sync-from-cortex.sh` - Import curated content

---

**Created:** 2025-12-12
**Location:** `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/`
