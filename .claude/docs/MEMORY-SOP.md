# Memory System Standard Operating Procedure (SOP)

## Overview

This document defines the complete memory lifecycle for Claude Code sessions in `/codebuild`.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MEMORY LIFECYCLE                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. PRE-TASK (UserPromptSubmit hook)                                       │
│     └── pre-task-memory-lookup.sh                                          │
│         ├── Search AgentDB for similar episodes                            │
│         ├── Search Supabase for relevant patterns                          │
│         ├── Search Supabase for relevant learnings                         │
│         ├── Search Swarm Memory for trajectories                           │
│         ├── Search Qdrant for semantic similarity ★NEW                     │
│         ├── Search Cortex (SiYuan) knowledge base                          │
│         ├── Search Hive-Mind memory (per-project)                          │
│         └── Output context for task                                        │
│                                                                             │
│  2. DURING TASK (PostToolUse hooks)                                        │
│     ├── Every Write/Edit/Bash/Task:                                        │
│     │   └── incremental-memory-sync.sh (every 30 calls or 5 min)          │
│     ├── On agentdb_pattern_store:                                          │
│     │   └── Immediate sync to Supabase                                     │
│     └── On memory_usage store:                                             │
│         └── memory-to-learnings-bridge.sh                                  │
│                                                                             │
│  3. POST-TASK (Stop hook) - FULL COLD STORAGE SYNC                         │
│     ├── sync-all.sh --cold-only (orchestrates all syncs)                   │
│     │   ├── AgentDB → Supabase (patterns, learnings)                       │
│     │   ├── AgentDB → Cortex (with SiYuan links/tags/PARA)                 │
│     │   ├── AgentDB → Qdrant (vector embeddings) ★NEW                      │
│     │   ├── Hive-Mind → Supabase + Cortex + Qdrant ★NEW                    │
│     │   └── Swarm Memory → Supabase + Cortex + Qdrant ★NEW                 │
│     └── session-lock.sh release                                            │
│                                                                             │
│  4. EMERGENCY (Manual)                                                     │
│     └── emergency-memory-flush.sh (before context compaction)              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Hot Layer (Local)

### Universal (Shared) - CAUTION with parallel sessions

| Database | Path | Contents |
|----------|------|----------|
| AgentDB | `agentdb.db` (root) | Episodes, rewards, critiques |
| Swarm Memory | `.swarm/memory.db` | Patterns, trajectories, coordination |

### Per-Project (Isolated)

| Database | Path | Contents |
|----------|------|----------|
| Hive-Mind | `<project>/.hive-mind/memory.json` | Project-specific session state |

## Semantic Layer (Cloud)

| Service | Endpoint | Purpose |
|---------|----------|---------|
| Qdrant | http://qdrant.harbor.fyi | Vector embeddings for semantic search |

**Collections:**
- `patterns` - Embedded successful approaches
- `learnings` - Embedded knowledge and insights
- `trajectories` - Embedded decision paths

## Cold Layer (Cloud)

| Service | Tables | Purpose |
|---------|--------|---------|
| Supabase | `patterns` (36) | Successful approaches |
| Supabase | `learnings` (69) | Knowledge captured |
| Supabase | `agent_memory` (218) | Key-value memory |
| Cortex | SiYuan blocks | Human-readable knowledge |

## Hooks Configuration

### UserPromptSubmit (Pre-Task)
```json
{
  "hooks": [
    {"command": "pre-task-memory-lookup.sh \"{{user_prompt}}\""}
  ]
}
```

### PostToolUse (During Task)
```json
{
  "matcher": "Write|Edit|Bash|Task",
  "hooks": [
    {"command": "incremental-memory-sync.sh"}
  ]
},
{
  "matcher": "mcp__claude-flow__agentdb_pattern_store",
  "hooks": [
    {"command": "sync-agentdb-to-supabase.sh --single"}
  ]
}
```

### Stop (Post-Task)
```json
{
  "hooks": [
    {"command": "agentdb-supabase-sync.sh all incremental"},
    {"command": "session-lock.sh release"}
  ]
}
```

## Sync Scripts

| Script | Source | Destination | Features |
|--------|--------|-------------|----------|
| `sync-agentdb-to-supabase.sh` | AgentDB | Supabase patterns/learnings | Incremental |
| `sync-agentdb-to-cortex.sh` | AgentDB | Cortex/SiYuan | Links, tags, PARA |
| `index-to-qdrant.sh` | AgentDB/Supabase | Qdrant | Vector embeddings ★NEW |
| `sync-hivemind-to-cold.sh` | Hive-Mind | Supabase + Cortex + Qdrant | Knowledge, tasks, consensus |
| `sync-swarm-to-cold.sh` | Swarm Memory | Supabase + Cortex + Qdrant | Trajectories, patterns |
| `sync-supabase-to-agentdb.sh` | Supabase | AgentDB | Recovery/restore |
| `sync-all.sh` | All Hot | All Cold + Semantic | Master orchestrator |

### Sync Flags

- `--force` - Bypass incremental checks, sync everything
- `--cold-only` - Only sync to cold storage (used by Stop hook)
- `--skip-qdrant` - Skip Qdrant vector indexing (faster)

## Commands

| Command | Purpose |
|---------|---------|
| `/memory-search <query>` | Search all 7 backends (includes Qdrant) |
| `/memory-sync` | Full sync to cloud + semantic layer |
| `/memory-stats` | Show statistics across all layers |

## Semantic Search via Qdrant

Qdrant provides vector-based semantic search for finding conceptually similar memories:

**Features:**
- **Semantic similarity** - Find related concepts, not just keyword matches
- **Cross-collection search** - Search patterns, learnings, and trajectories together
- **Scoring & ranking** - Results ordered by semantic relevance
- **Fast retrieval** - Optimized for large-scale vector search

**Usage in Pre-Task Lookup:**
```bash
# Semantic search via Qdrant (automatic in pre-task-memory-lookup.sh)
curl -X POST http://qdrant.harbor.fyi/collections/patterns/points/search \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [embedding of query],
    "limit": 10,
    "with_payload": true
  }'
```

**Integration:**
- Pre-task hook queries Qdrant for semantically similar past work
- Results include patterns, learnings, and decision trajectories
- Complements keyword-based searches from other backends

## Parallel Sessions

**Problem:** Universal hot layer databases (AgentDB, Swarm) have no locking.

**Solutions:**

1. **Check before starting:**
   ```bash
   .claude/hooks/session-lock.sh check
   ```

2. **Acquire lock:**
   ```bash
   .claude/hooks/session-lock.sh acquire
   ```

3. **Force acquire (dangerous):**
   ```bash
   .claude/hooks/session-lock.sh acquire --force
   ```

4. **Use per-project isolation:**
   - Work in different project folders
   - Each has its own `.hive-mind/memory.json`

## Sync Schedule

| Trigger | Frequency | What Syncs |
|---------|-----------|------------|
| Tool calls | Every 30 calls | AgentDB → Supabase |
| Time-based | Every 5 minutes | AgentDB → Supabase |
| Pattern store | Immediate | Single pattern → Supabase |
| Session end | Once | Full verification sync |
| Manual | On demand | All backends |

## Emergency Procedures

### Before Context Compaction
```bash
.claude/hooks/emergency-memory-flush.sh
```

### Force Full Sync
```bash
.claude/skills/memory-sync/scripts/sync-all.sh --force
```

### Rebuild from Cloud
```bash
.claude/skills/memory-sync/scripts/sync-supabase-to-agentdb.sh
```

## Verification

```bash
# Check all backends
.claude/skills/memory-sync/scripts/memory-stats.sh

# Search for specific content
.claude/skills/memory-sync/scripts/unified-search.sh "query"

# Verify sync state
cat /tmp/claude-memory-sync-state
```

## Troubleshooting

### "No context found" on pre-task lookup
- Search uses first 20-30 chars of query
- Try shorter/different keywords
- Check Supabase connection
- Verify Qdrant endpoint: http://qdrant.harbor.fyi
- Check if Qdrant collections are indexed

### Sync not happening
- Check `/tmp/claude-memory-sync.log`
- Verify call count: `cat /tmp/claude-memory-sync-state`
- Force sync: `incremental-memory-sync.sh` manually

### Parallel session conflicts
- Check lock: `session-lock.sh check`
- Review `/tmp/claude-code-session.lock`
- Work in separate project folders

## Qdrant Collection Details

### Collection Structure

Each Qdrant collection stores vector embeddings with metadata:

**patterns collection:**
- Vector dimension: 1536 (OpenAI ada-002)
- Payload: task, approach, reward, timestamp, session_id
- Distance metric: Cosine similarity

**learnings collection:**
- Vector dimension: 1536
- Payload: category, insight, source, tags, timestamp
- Distance metric: Cosine similarity

**trajectories collection:**
- Vector dimension: 1536
- Payload: decision_path, outcome, context, session_id
- Distance metric: Cosine similarity

### Indexing Process

1. **Extraction**: Sync scripts pull text from source (AgentDB/Supabase)
2. **Embedding**: Text converted to vectors using OpenAI embeddings
3. **Upload**: Vectors + metadata stored in Qdrant collections
4. **Verification**: Collection stats checked for successful indexing

---

*Last updated: 2025-12-03*
