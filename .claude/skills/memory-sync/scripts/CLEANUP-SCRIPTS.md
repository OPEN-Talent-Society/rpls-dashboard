# Memory System Cleanup Scripts

Quick reference for cleaning up pollution and duplicates in the memory system.

## Overview

These scripts remove polluted/duplicate data from Qdrant and Supabase caused by sync errors, chunking issues, and cross-collection pollution.

## Scripts

### 1. cleanup-qdrant-pollution.sh

Cleans up Qdrant vector database pollution from chunking and sync issues.

**Location:** `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/cleanup-qdrant-pollution.sh`

**What it cleans:**
- Topics containing "chunk-", "supabase", "Episode-", "Pattern-" (pollution patterns)
- Source IDs containing "supabase" (sync errors)
- Low-reward entries in agent_memory (< 0.3 score)
- Cortex knowledge entries in wrong collection

**Usage:**
```bash
# Dry run (see what would be deleted, no changes)
bash cleanup-qdrant-pollution.sh --dry-run

# Dry run with limit
bash cleanup-qdrant-pollution.sh --dry-run --limit 10

# Actually delete (LIVE mode)
bash cleanup-qdrant-pollution.sh

# Delete with limit for safety
bash cleanup-qdrant-pollution.sh --limit 100
```

**Collections cleaned:**
- `cortex` - Knowledge base vectors
- `agent_memory` - Agent learning/episode vectors

**Output:**
- Summary of deleted/remaining points per collection
- Log file: `/tmp/cleanup-qdrant-YYYYMMDD-HHMMSS.log`

---

### 2. cleanup-supabase-pollution.sh

Cleans up Supabase database pollution from sync errors.

**Location:** `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/cleanup-supabase-pollution.sh`

**What it cleans:**
- Learnings table: topics starting with "supabase", "chunk", "Episode-"
- Patterns table: names starting with "supabase", "Episode-"
- Polluted agent_episodes in patterns table (should be in agent_memory)

**Usage:**
```bash
# Dry run (see what would be deleted, no changes)
bash cleanup-supabase-pollution.sh --dry-run

# Dry run with limit
bash cleanup-supabase-pollution.sh --dry-run --limit 10

# Actually delete (LIVE mode)
bash cleanup-supabase-pollution.sh

# Delete with limit for safety
bash cleanup-supabase-pollution.sh --limit 100
```

**Tables cleaned:**
- `learnings` - Agent learning records
- `patterns` - Reasoning patterns

**Output:**
- Summary of deleted/remaining rows per table
- Log file: `/tmp/cleanup-supabase-YYYYMMDD-HHMMSS.log`

---

### 3. cleanup-cortex-pollution.sh

Cleans up Cortex (SiYuan) notebook pollution (if this script exists).

**Location:** `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/cleanup-cortex-pollution.sh`

---

## Safety Features

All scripts include:

1. **Dry-run mode** - Preview changes without modifying data
2. **Limit parameter** - Cap deletions per operation for safety
3. **Detailed logging** - All operations logged to `/tmp/cleanup-*.log`
4. **Summary reports** - Before/after counts per collection/table
5. **Error handling** - Failed deletes don't crash the script

## Common Workflows

### Initial Discovery
```bash
# See what pollution exists (no changes)
bash cleanup-qdrant-pollution.sh --dry-run
bash cleanup-supabase-pollution.sh --dry-run
```

### Safe Incremental Cleanup
```bash
# Delete in small batches
bash cleanup-qdrant-pollution.sh --limit 50
bash cleanup-supabase-pollution.sh --limit 50

# Repeat until clean
```

### Full Cleanup
```bash
# Remove all pollution at once
bash cleanup-qdrant-pollution.sh
bash cleanup-supabase-pollution.sh
```

### Check Logs
```bash
# View latest cleanup logs
ls -lt /tmp/cleanup-*.log | head -5
cat /tmp/cleanup-qdrant-YYYYMMDD-HHMMSS.log
```

## Environment Variables

Scripts extract these from `/Users/adamkovacs/Documents/codebuild/.env`:

**Qdrant:**
- `QDRANT_URL` - Qdrant server URL
- `QDRANT_API_KEY` - Qdrant authentication key

**Supabase:**
- `PUBLIC_SUPABASE_URL` - Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Supabase admin key

## Pollution Patterns Detected

### Common Topics/Names to Remove:
- `chunk-*` - Chunking IDs leaked into topics
- `supabase*` - Supabase metadata leaked into content
- `Episode-*` - AgentDB episodes in wrong collection
- `Pattern-*` - Pattern metadata in content fields

### Source Pollution:
- `source_id` containing "supabase"
- `category` = "agent_episode" in patterns table (wrong place)

### Quality Issues:
- `reward < 0.3` in agent_memory (low-value learning)
- Cortex knowledge in agent_memory (wrong collection)

## Testing

All scripts tested with:
- Dry-run mode validation
- Small limit testing (--limit 5)
- Error handling verification
- Log output validation

## Maintenance

Run cleanup after:
- Major sync operations
- Detecting slow search performance
- Finding duplicate/polluted search results
- Weekly maintenance (recommended)

Add to cron for automated cleanup:
```bash
# Weekly cleanup (Sundays at 3 AM)
0 3 * * 0 /path/to/cleanup-qdrant-pollution.sh --limit 1000 >> /var/log/cleanup.log 2>&1
0 3 * * 0 /path/to/cleanup-supabase-pollution.sh --limit 1000 >> /var/log/cleanup.log 2>&1
```

---

**Last Updated:** 2025-12-12
**Author:** Claude Code
**Version:** 1.0
