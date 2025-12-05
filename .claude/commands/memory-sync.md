---
description: "Sync memory across all backends (AgentDB, Supabase, Cortex, RuVector)"
allowed-tools:
  - Bash
  - Read
  - mcp__cortex__siyuan_search
  - mcp__claude-flow__agentdb_stats
---

# Memory Sync Command

Synchronize memory across all 6 storage backends.

## Usage

Run the unified memory sync:

```bash
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-all.sh
```

## Quick Actions

**View Stats:**
```bash
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/memory-stats.sh
```

**Sync specific direction:**
```bash
# AgentDB → Supabase
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh

# Supabase → AgentDB
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-supabase-to-agentdb.sh

# To/From Cortex
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-from-cortex.sh

# Index to RuVector
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/index-to-ruvector.sh
```

**Search unified memory:**
```bash
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/unified-search.sh "your query"
```

## Backends

| Backend | Records | Status |
|---------|---------|--------|
| AgentDB | Check with `agentdb_stats` | Local |
| Supabase | 3 tables | Cloud |
| Cortex | Knowledge base | Cloud |
| RuVector | Vector index | Local |
