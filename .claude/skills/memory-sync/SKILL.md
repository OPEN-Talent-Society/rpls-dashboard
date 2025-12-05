---
name: "memory-sync"
description: "Unified memory synchronization across all storage backends: AgentDB/ReasoningBank (local SQLite), Supabase (cloud), Swarm Memory, Hive-Mind JSON, and RuVector (vector search). Use for syncing learnings, patterns, and episodes between local and cloud storage."
---

# Memory Sync - Unified Memory Synchronization

## Overview

Synchronizes memory across 6 storage backends:

| Backend | Type | Purpose | Sync Direction |
|---------|------|---------|----------------|
| **AgentDB/ReasoningBank** | Local SQLite | Episodes, patterns, rewards | Bi-directional |
| **Supabase** | Cloud PostgreSQL | Persistent cloud storage | Bi-directional |
| **Cortex (SiYuan)** | Cloud Note DB | Knowledge base, docs, learnings | Bi-directional |
| **Swarm Memory** | Local SQLite | Agent coordination state | Export only |
| **Hive-Mind** | Local JSON | Session memory | Export only |
| **RuVector** | Vector DB | Semantic search index | Index from all |

## Quick Commands

### Sync All Systems
```bash
# Full sync: Local → Supabase → RuVector
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-all.sh

# Sync specific backend
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-agentdb-to-supabase.sh
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-supabase-to-agentdb.sh
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/index-to-ruvector.sh
```

### Query Unified Memory
```bash
# Search across all backends
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/unified-search.sh "query text"

# Get memory stats
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/memory-stats.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UNIFIED MEMORY LAYER                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐ │
│  │   AgentDB    │────▶│   Supabase   │────▶│   RuVector   │ │
│  │  (episodes)  │◀────│  (patterns)  │     │  (vectors)   │ │
│  └──────────────┘     └──────────────┘     └──────────────┘ │
│         │                    │                    ▲          │
│         ▼                    ▼                    │          │
│  ┌──────────────┐     ┌──────────────┐           │          │
│  │ Swarm Memory │────▶│  Hive-Mind   │───────────┘          │
│  │    (.db)     │     │   (.json)    │                      │
│  └──────────────┘     └──────────────┘                      │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Table Mapping

| AgentDB Table | Supabase Table | RuVector Collection |
|---------------|----------------|---------------------|
| `episodes` | `patterns` | `agent_patterns` |
| (critique field) | `learnings` | `agent_learnings` |
| (memory namespace) | `agent_memory` | `agent_memory` |

## Hooks Integration (Progressive Sync)

Automatic sync prevents data loss from context compaction:

| Hook | Trigger | Action |
|------|---------|--------|
| `PostToolUse` | Write/Edit/Bash/Task | `incremental-memory-sync.sh` (every 30 calls or 5 min) |
| `PostToolUse` | `agentdb_pattern_store` | Immediate sync to Supabase |
| `PostToolUse` | `memory_usage` store | Bridge to learnings/patterns |
| `Stop` | Session end | Final sync verification |
| **Manual** | `/memory-sync` | Full sync all backends |

### Emergency Flush
```bash
# Run before context compaction or major operations
/Users/adamkovacs/Documents/codebuild/.claude/hooks/emergency-memory-flush.sh
```

## Environment Variables

```bash
# Supabase (from .env)
SUPABASE_PROJECT_ID=zxcrbcmdxpqprpxhsntc
PUBLIC_SUPABASE_URL=https://zxcrbcmdxpqprpxhsntc.supabase.co
SUPABASE_SERVICE_ROLE_KEY=sb_secret_...

# Local paths
AGENTDB_PATH=./claude-flow/agentdb.db
SWARM_MEMORY_PATH=./.swarm/memory.db
HIVEMIND_MEMORY_PATH=./.hive-mind/memory.json

# RuVector
RUVECTOR_COLLECTION=agent_memory
```

## Data Transformations

### AgentDB Episode → Supabase Pattern
```javascript
{
  // AgentDB episode
  sessionId: "session-123",
  task: "Fix authentication bug",
  reward: 0.95,
  success: true,
  critique: "Good approach, consider edge cases"
}
// ↓ Transforms to ↓
{
  // Supabase pattern
  pattern_id: "episode-session-123",
  name: "Fix authentication bug",
  category: "task_completion",
  description: "Good approach, consider edge cases",
  template: { reward: 0.95, success: true },
  success_count: 1
}
```

### Supabase Learning → RuVector Vector
```javascript
{
  // Supabase learning
  topic: "PostgreSQL JSONB optimization",
  content: "Use GIN indexes for JSONB queries..."
}
// ↓ Indexed as ↓
{
  // RuVector vector
  id: "learning-87cdb242",
  embedding: [0.1, 0.2, ...], // 1536 dimensions
  metadata: { source: "supabase", type: "learning" }
}
```

## CLI Usage

```bash
# Initialize RuVector collection
pnpm dlx ruvector init --collection agent_memory --dim 1536

# Index all learnings
pnpm dlx ruvector index --source supabase --table learnings

# Semantic search
pnpm dlx ruvector search "authentication patterns" --k 5

# Export to Supabase
pnpm dlx ruvector export --target supabase --table agent_memory
```

## Troubleshooting

### Sync Conflicts
- AgentDB is source of truth for episodes
- Supabase is source of truth for learnings/patterns
- RuVector is read-only index (rebuild from sources)

### Missing Data
```bash
# Verify all backends
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/verify-sync.sh

# Force full resync
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-all.sh --force
```
