# Sync AgentDB to Supabase

Syncs local AgentDB JSON files (learnings, patterns) to Supabase cloud storage.

## Usage
- `/sync-agentdb` - Sync all tables (incremental)
- `/sync-agentdb full` - Full sync (all entries)
- `/sync-agentdb learnings` - Sync only learnings
- `/sync-agentdb patterns` - Sync only patterns

## What This Does
1. Reads local `.agentdb/learnings.json` and `.agentdb/patterns.json`
2. Syncs new entries to Supabase cloud via REST API
3. Uses incremental sync by default (only new entries since last sync)
4. Tracks sync state in `/tmp/agentdb-sync-state.json`

## Automatic Sync
This sync runs automatically:
- On session end (via Stop hooks)
- After memory_usage MCP operations (via PostToolUse hooks)

## Manual Sync
Run this command to sync immediately:

```bash
./.claude/hooks/agentdb-supabase-sync.sh $ARGUMENTS
```

Arguments: `[table] [mode]`
- table: `all`, `learnings`, `patterns` (default: all)
- mode: `incremental`, `full` (default: incremental)
