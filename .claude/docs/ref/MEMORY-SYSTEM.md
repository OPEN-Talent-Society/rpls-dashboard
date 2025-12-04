# Memory System Reference

> Complete reference for the 7-backend persistent memory system.
> Core principle: **"Learn Once, Remember Forever"**

---

## TL;DR - Memory Quick Reference

**7 Backends, 3 Layers**:
- **Hot (Local)**: AgentDB (episodes), Swarm Memory (tasks), Hive-Mind (per-project)
- **Semantic (Cloud)**: Qdrant (768-dim vectors at http://qdrant.harbor.fyi)
- **Cold (Cloud)**: Supabase (patterns/learnings), Cortex (knowledge docs), Agent Memory (KV)

**Essential Commands**:
```bash
# Before task - search all backends
bash .claude/hooks/pre-task-memory-lookup.sh "task description"
/memory:memory-search "topic"

# After task - store learnings
mcp__claude-flow__agentdb_pattern_store { sessionId, task, reward: 0.9, success: true }

# Sync all
bash .claude/skills/memory-sync/scripts/sync-all.sh
```

**Lifecycle**: PRE-TASK (auto-search) -> DURING (incremental sync every 30 calls) -> POST-TASK (full cold sync)

---

## Architecture Overview (3 Layers, 7 Backends)

```
+-----------------------------------------------------------------------------+
|                         MEMORY LIFECYCLE                                    |
+-----------------------------------------------------------------------------+
|                                                                             |
|  1. PRE-TASK (UserPromptSubmit hook)                                       |
|     └── pre-task-memory-lookup.sh                                          |
|         ├── Search AgentDB for similar episodes                            |
|         ├── Search Supabase for relevant patterns                          |
|         ├── Search Supabase for relevant learnings                         |
|         ├── Search Swarm Memory for trajectories                           |
|         ├── Search Qdrant for semantic similarity                          |
|         ├── Search Cortex (SiYuan) knowledge base                          |
|         ├── Search Hive-Mind memory (per-project)                          |
|         └── Output context for task                                        |
|                                                                             |
|  2. DURING TASK (PostToolUse hooks)                                        |
|     ├── Every Write/Edit/Bash/Task:                                        |
|     │   └── incremental-memory-sync.sh (every 30 calls or 5 min)          |
|     ├── On agentdb_pattern_store:                                          |
|     │   └── Immediate sync to Supabase                                     |
|     └── On memory_usage store:                                             |
|         └── memory-to-learnings-bridge.sh                                  |
|                                                                             |
|  3. POST-TASK (Stop hook) - FULL COLD STORAGE SYNC                         |
|     ├── sync-all.sh --cold-only (orchestrates all syncs)                   |
|     │   ├── AgentDB → Supabase (patterns, learnings)                       |
|     │   ├── AgentDB → Cortex (with SiYuan links/tags/PARA)                 |
|     │   ├── AgentDB → Qdrant (vector embeddings)                           |
|     │   ├── Hive-Mind → Supabase + Cortex + Qdrant                         |
|     │   └── Swarm Memory → Supabase + Cortex + Qdrant                      |
|     └── session-lock.sh release                                            |
|                                                                             |
|  4. EMERGENCY (Manual)                                                     |
|     └── emergency-memory-flush.sh (before context compaction)              |
|                                                                             |
+-----------------------------------------------------------------------------+
```

---

## Hot Layer (Local - Fast, Session)

### Universal (Shared) - CAUTION with parallel sessions

| Database | Path | Contents |
|----------|------|----------|
| **AgentDB** | `agentdb.db` (root) | Episodes, rewards, critiques |
| **Swarm Memory** | `.swarm/memory.db` | Patterns, trajectories, coordination |

### Per-Project (Isolated)

| Database | Path | Contents |
|----------|------|----------|
| **Hive-Mind** | `<project>/.hive-mind/memory.json` | Project-specific session state |

---

## Semantic Layer (Cloud - Vector Search)

| Service | Endpoint | Purpose |
|---------|----------|---------|
| **Qdrant** | http://qdrant.harbor.fyi | Vector embeddings for semantic search |

### Single Collection Architecture

**Collection**: `agent_memory`
- **Vector dimension**: 768 (Google Gemini embeddings)
- **Distance metric**: Cosine similarity
- **Filtering**: Type-based payload filtering (learning, pattern, trajectory, task, decision)
- **Indexes**: Payload indexes on `type` and `source` fields

### Payload Schema
```json
{
  "type": "learning|pattern|trajectory|task|decision",
  "source": "agentdb|supabase|cortex|hivemind|swarm",
  "content": "Full text content",
  "metadata": {
    "timestamp": "ISO-8601",
    "session_id": "string",
    "tags": ["array"],
    "priority": "high|medium|low"
  },
  "parent_id": "optional - for chunked documents",
  "chunk_index": "optional - chunk position in parent"
}
```

### Chunking Strategy (Long Documents)
- **Chunk size**: 400 tokens per chunk
- **Overlap**: 10-15% between chunks (40-60 tokens)
- **Parent-child linking**: All chunks reference parent via `parent_id`

---

## Cold Layer (Cloud - Persistent)

| Service | Tables | Purpose |
|---------|--------|---------|
| **Supabase** | `patterns` (36) | Successful approaches |
| **Supabase** | `learnings` (69) | Knowledge captured |
| **Supabase** | `agent_memory` (218) | Key-value memory |
| **Cortex** | SiYuan blocks | Human-readable knowledge |

---

## Memory Backends Summary (7 Total)

| # | Backend | Layer | Access | Best For |
|---|---------|-------|--------|----------|
| 1 | **AgentDB** | Hot | `mcp__claude-flow__agentdb_*` | Episodes, ReasoningBank |
| 2 | **Swarm Memory** | Hot | `.swarm/memory.db` | Multi-agent state |
| 3 | **Hive-Mind** | Hot | `.hive-mind/memory.json` | Per-project state |
| 4 | **Qdrant** | Semantic | REST API | Semantic similarity search |
| 5 | **Supabase** | Cold | REST API | Patterns, learnings |
| 6 | **Cortex** | Cold | `mcp__cortex__siyuan_*` | Knowledge docs |
| 7 | **Agent Memory** | Cold | Supabase table | Key-value pairs |

---

## Essential Commands

### Before Starting Work - Search Memory (All 7 Backends)
```bash
# Automatic via hook (searches all backends)
bash .claude/hooks/pre-task-memory-lookup.sh "your task description"

# Or search via MCP tools
mcp__claude-flow__agentdb_pattern_search { task: "what you're doing" }

# Or use the slash command (searches all 7 backends)
/memory:memory-search "authentication implementation"
```

### After Completing Work - Store Learnings
```bash
# Store in AgentDB (auto-syncs to cold layer)
mcp__claude-flow__agentdb_pattern_store {
  sessionId: "session-id",
  task: "what you did",
  reward: 0.9,
  success: true,
  critique: "what worked well, what to improve"
}
```

### Semantic Search via Qdrant
```bash
# Query with type filtering
curl -X POST http://qdrant.harbor.fyi/collections/agent_memory/points/search \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [embedding of query],
    "limit": 10,
    "filter": {
      "must": [
        {"key": "type", "match": {"value": "learning"}}
      ]
    }
  }'
```

### Full Sync
```bash
# Full sync all backends
bash .claude/skills/memory-sync/scripts/sync-all.sh

# Cold storage only (used by Stop hook)
bash .claude/skills/memory-sync/scripts/sync-all.sh --cold-only

# Force sync (bypass incremental checks)
bash .claude/skills/memory-sync/scripts/sync-all.sh --force
```

---

## Sync Scripts Reference

| Script | Source | Destination | Features |
|--------|--------|-------------|----------|
| `sync-agentdb-to-supabase.sh` | AgentDB | Supabase patterns/learnings | Incremental |
| `sync-agentdb-to-cortex.sh` | AgentDB | Cortex/SiYuan | Links, tags, PARA |
| `index-to-qdrant.sh` | AgentDB/Supabase | Qdrant | Vector embeddings |
| `sync-hivemind-to-cold.sh` | Hive-Mind | Supabase + Cortex + Qdrant | Knowledge, tasks |
| `sync-swarm-to-cold.sh` | Swarm Memory | Supabase + Cortex + Qdrant | Trajectories |
| `sync-supabase-to-agentdb.sh` | Supabase | AgentDB | Recovery/restore |
| `sync-all.sh` | All Hot | All Cold + Semantic | Master orchestrator |

### Sync Flags
- `--force` - Bypass incremental checks, sync everything
- `--cold-only` - Only sync to cold storage (used by Stop hook)
- `--skip-qdrant` - Skip Qdrant vector indexing (faster)

---

## Sync Schedule

| Trigger | Frequency | What Syncs |
|---------|-----------|------------|
| Tool calls | Every 30 calls | AgentDB → Supabase |
| Time-based | Every 5 minutes | AgentDB → Supabase |
| Pattern store | Immediate | Single pattern → Supabase |
| Session end | Once | Full verification sync |
| Manual | On demand | All backends |

---

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

---

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

3. **Use per-project isolation:**
   - Work in different project folders
   - Each has its own `.hive-mind/memory.json`

---

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

---

## Verification

```bash
# Check all backends
.claude/skills/memory-sync/scripts/memory-stats.sh

# Search across all backends
.claude/skills/memory-sync/scripts/unified-search.sh "query"

# Verify sync state
cat /tmp/claude-memory-sync-state
```

---

## Best Practices

1. **ALWAYS search before starting** - Don't reinvent the wheel (all 7 backends)
2. **ALWAYS store after completing** - Future you will thank you
3. **Use semantic search** - Qdrant finds related work even with different keywords
4. **Tag everything** - Categories and metadata make retrieval easier
5. **Store failures too** - Learning from mistakes is valuable
6. **Check session lock** - Avoid conflicts in parallel sessions

---

## Troubleshooting

### "No context found" on pre-task lookup
- Search uses first 20-30 chars of query
- Try shorter/different keywords
- Check Supabase connection
- Verify Qdrant endpoint: http://qdrant.harbor.fyi

### Sync not happening
- Check `/tmp/claude-memory-sync.log`
- Verify call count: `cat /tmp/claude-memory-sync-state`
- Force sync: `incremental-memory-sync.sh` manually

### Parallel session conflicts
- Check lock: `session-lock.sh check`
- Review `/tmp/claude-code-session.lock`
- Work in separate project folders

---

*Last updated: 2025-12-04 - Full 7-backend memory system with Qdrant semantic layer*
