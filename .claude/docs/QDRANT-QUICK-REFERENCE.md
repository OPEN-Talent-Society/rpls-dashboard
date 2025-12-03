# Qdrant Semantic Layer - Quick Reference

**For Full Details:** See `QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md`
**Implementation:** See `QDRANT-IMPLEMENTATION-CHECKLIST.md`

---

## Visual Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    UNIFIED MEMORY ARCHITECTURE                          │
│                    (3-Layer: HOT → SEMANTIC → COLD)                     │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│  HOT LAYER (Local, Real-time Write)                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  AgentDB                Swarm Memory             Hive-Mind             │
│  (agentdb.db)          (.swarm/memory.db)       (.hive-mind/memory.json)│
│  ├─ episodes           ├─ patterns              ├─ session state       │
│  ├─ rewards            ├─ trajectories          ├─ consensus           │
│  └─ critiques          └─ coordination          └─ per-project         │
│                                                                         │
│  Write: IMMEDIATE                                                       │
│  Sync:  Every 30 calls OR 5 minutes → COLD                            │
│                                                                         │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼ (index on session end)
┌─────────────────────────────────────────────────────────────────────────┐
│  SEMANTIC LAYER (Cloud, Read-Only Index) ★ QDRANT                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Qdrant (qdrant.harbor.fyi)                                           │
│  ├─ Collection: agent_memory (768 dims, Cosine)                       │
│  ├─ Collection: learnings (768 dims, Cosine)                          │
│  ├─ Collection: patterns (768 dims, Cosine)                           │
│  └─ Collection: codebase (768 dims, Cosine) [future]                  │
│                                                                         │
│  Embeddings: Gemini text-embedding-004 (free tier)                    │
│  Purpose:    Semantic similarity search, pre-task context              │
│  Sync:       Rebuilt from COLD on session end                         │
│                                                                         │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │
                                ▼ (reference source)
┌─────────────────────────────────────────────────────────────────────────┐
│  COLD LAYER (Cloud, Persistent Storage)                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Supabase (PostgreSQL)        Cortex/SiYuan (Note DB)                 │
│  ├─ patterns (36)             ├─ Human-readable docs                   │
│  ├─ learnings (69)            ├─ PARA organization                     │
│  └─ agent_memory (218)        └─ Backlinks, tags                       │
│                                                                         │
│  Write: Synced from HOT every 30 calls OR 5 minutes                   │
│  Read:  Source of truth for indexing                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Write Path

```
┌──────────────────────────────────────────────────────────────────┐
│  WRITE: Agent Creates Memory                                     │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────┐
         │  1. Store in HOT Layer           │
         │     (AgentDB, Swarm, Hive-Mind)  │
         │     IMMEDIATE                    │
         └──────────┬───────────────────────┘
                    │
                    ▼
         ┌──────────────────────────────────┐
         │  2. Incremental Sync to COLD     │
         │     Every 30 calls OR 5 minutes  │
         │     HOT → Supabase/Cortex        │
         └──────────┬───────────────────────┘
                    │
                    ▼
         ┌──────────────────────────────────┐
         │  3. Session End: Full Sync       │
         │     HOT → COLD (verify)          │
         │     COLD → SEMANTIC (index)      │
         └──────────┬───────────────────────┘
                    │
                    ▼
         ┌──────────────────────────────────┐
         │  4. Qdrant Indexing              │
         │     Fetch from Supabase          │
         │     Generate embeddings (Gemini) │
         │     Upsert to collections        │
         └──────────────────────────────────┘
```

---

## Data Flow: Read Path (Pre-Task Lookup)

```
┌──────────────────────────────────────────────────────────────────┐
│  READ: User Submits Prompt                                       │
└──────────────────────────────────────────────────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────┐
         │  pre-task-memory-lookup.sh       │
         └──────────┬───────────────────────┘
                    │
        ┌───────────┼───────────┬───────────┬───────────┐
        ▼           ▼           ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐
   │ Qdrant │  │AgentDB │  │Supabase│  │ Swarm  │  │ Cortex │
   │SEMANTIC│  │KEYWORD │  │KEYWORD │  │ GRAPH  │  │  DOCS  │
   └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘  └───┬────┘
       │           │           │           │           │
       │ Vector    │ SQL LIKE  │ SQL LIKE  │Trajectry  │ Search
       │ Search    │ Pattern   │ Pattern   │ Pattern   │  Tags
       │           │           │           │           │
       └───────────┴───────────┴───────────┴───────────┘
                            │
                            ▼
         ┌──────────────────────────────────┐
         │  UNIFIED CONTEXT OUTPUT          │
         │  ├─ Top 3 semantic (score >0.8) │
         │  ├─ Top 5 keyword                │
         │  ├─ Top 3 graph                  │
         │  └─ Top 3 docs                   │
         └──────────────────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────┐
         │  Agent Starts Task with Context  │
         └──────────────────────────────────┘
```

---

## Collections & Schemas

### Collection: `agent_memory`

| Field | Type | Description |
|-------|------|-------------|
| Vector | 768-dim array | Embedding of `key: value` |
| Payload | JSON | `{type, namespace, source, original_id, key, value_preview, created_at, agent_id, ttl_seconds}` |

**Example:**
```json
{
  "id": 12345,
  "vector": [0.1, 0.2, ...],  // 768 dimensions
  "payload": {
    "type": "memory",
    "namespace": "session/2025-12-03",
    "source": "supabase",
    "original_id": "uuid-abc-123",
    "key": "api/rate-limit-strategy",
    "value_preview": "Implemented exponential backoff with jitter...",
    "created_at": "2025-12-03T10:30:00Z",
    "agent_id": "claude-code@aienablement.academy"
  }
}
```

### Collection: `learnings`

| Field | Type | Description |
|-------|------|-------------|
| Vector | 768-dim array | Embedding of `topic: content` |
| Payload | JSON | `{type, category, source, original_id, topic, content_preview, tags, related_docs, created_at, agent_email}` |

**Example:**
```json
{
  "id": 67890,
  "vector": [0.3, 0.4, ...],
  "payload": {
    "type": "learning",
    "category": "technical",
    "source": "supabase",
    "original_id": "uuid-def-456",
    "topic": "PostgreSQL JSONB optimization",
    "content_preview": "Use GIN indexes for JSONB queries to achieve 10-100x speedup...",
    "tags": ["postgres", "performance", "jsonb"],
    "related_docs": ["cortex-doc-id-123"],
    "created_at": "2025-12-03T10:30:00Z",
    "agent_email": "claude-code@aienablement.academy"
  }
}
```

### Collection: `patterns`

| Field | Type | Description |
|-------|------|-------------|
| Vector | 768-dim array | Embedding of `name: description` |
| Payload | JSON | `{type, category, source, original_id, name, description_preview, use_cases, success_count, reward_avg, created_at, updated_at}` |

**Example:**
```json
{
  "id": 11223,
  "vector": [0.5, 0.6, ...],
  "payload": {
    "type": "pattern",
    "category": "workflow",
    "source": "supabase",
    "original_id": "uuid-ghi-789",
    "name": "Multi-agent parallel coordination",
    "description_preview": "Use BatchTool to spawn all agents in one message, coordinate via memory...",
    "use_cases": ["swarm", "parallel-execution", "coordination"],
    "success_count": 12,
    "reward_avg": 0.92,
    "created_at": "2025-12-03T10:30:00Z",
    "updated_at": "2025-12-03T10:30:00Z"
  }
}
```

---

## Key Scripts

### Indexing

```bash
# Full index (all collections)
.claude/skills/memory-sync/scripts/index-to-qdrant.sh

# Specific collection
.claude/skills/memory-sync/scripts/index-to-qdrant.sh learnings

# Incremental (only new/updated)
.claude/skills/memory-sync/scripts/index-to-qdrant.sh --incremental
```

### Searching

```bash
# Pre-task lookup (automatic)
# Triggered by UserPromptSubmit hook

# Manual semantic search
.claude/skills/memory-sync/scripts/semantic-search.sh "database optimization"

# Unified search (all backends)
.claude/skills/memory-sync/scripts/unified-search.sh "authentication patterns"
```

### Syncing

```bash
# Full sync (HOT → COLD → SEMANTIC)
.claude/skills/memory-sync/scripts/sync-all.sh

# Cold only (HOT → COLD, skip SEMANTIC)
.claude/skills/memory-sync/scripts/sync-all.sh --cold-only

# Skip Qdrant indexing
SKIP_QDRANT=true .claude/skills/memory-sync/scripts/sync-all.sh
```

### Monitoring

```bash
# Collection stats
curl http://qdrant.harbor.fyi/collections | jq '.result.collections'

# Specific collection
curl http://qdrant.harbor.fyi/collections/learnings | jq '.result'

# Memory stats (all backends)
.claude/skills/memory-sync/scripts/memory-stats.sh

# Qdrant stats (future)
.claude/skills/memory-sync/scripts/qdrant-stats.sh
```

---

## Sync Triggers

| Trigger | Frequency | What Syncs | Script |
|---------|-----------|------------|--------|
| **Tool calls** | Every 30 calls | HOT → COLD | `incremental-memory-sync.sh` |
| **Time-based** | Every 5 minutes | HOT → COLD | `incremental-memory-sync.sh` |
| **Pattern store** | Immediate | Single pattern → Supabase | `sync-agentdb-to-supabase.sh --single` |
| **Session end** | Once | HOT → COLD → SEMANTIC | `sync-all.sh` + `index-to-qdrant.sh` |
| **Manual** | On demand | All layers | `/memory-sync` command |

---

## Embedding Model

**Provider:** Google Gemini
**Model:** text-embedding-004
**Dimensions:** 768
**Distance:** Cosine similarity
**Cost:** Free tier (1500 req/min)

**API Example:**
```bash
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "models/text-embedding-004",
    "content": {"parts": [{"text": "your text here"}]}
  }'
```

**Response:**
```json
{
  "embedding": {
    "values": [0.1, 0.2, 0.3, ..., 0.768]  // 768 dimensions
  }
}
```

---

## Qdrant API Quick Reference

### Create Collection

```bash
curl -X PUT "http://qdrant.harbor.fyi/collections/learnings" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    }
  }'
```

### Upsert Points

```bash
curl -X PUT "http://qdrant.harbor.fyi/collections/learnings/points" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": 1,
        "vector": [0.1, 0.2, ...],
        "payload": {"topic": "Test", "category": "technical"}
      }
    ]
  }'
```

### Search

```bash
curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5,
    "with_payload": true,
    "score_threshold": 0.7
  }'
```

### Search with Filter

```bash
curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.1, 0.2, ...],
    "limit": 5,
    "with_payload": true,
    "filter": {
      "must": [
        {"key": "category", "match": {"value": "technical"}}
      ]
    }
  }'
```

---

## Hook Integration

### UserPromptSubmit (Pre-Task)

```bash
# .claude/hooks/pre-task-memory-lookup.sh
# 1. Generate embedding for user prompt
# 2. Search Qdrant (learnings, patterns, agent_memory)
# 3. Search AgentDB (keyword)
# 4. Search Supabase (keyword)
# 5. Search Swarm/Hive-Mind (graph)
# 6. Search Cortex (docs)
# 7. Output unified context
```

### Stop (Session End)

```bash
# .claude/hooks/session-end.sh
# 1. Sync HOT → COLD (verify)
# 2. Index COLD → SEMANTIC (Qdrant)
# 3. Release session lock
```

**Hook Configuration (.claude/settings.json):**
```json
{
  "hooks": {
    "UserPromptSubmit": [
      {"command": "./.claude/hooks/pre-task-memory-lookup.sh \"{{user_prompt}}\""}
    ],
    "Stop": [
      {"command": "./.claude/hooks/session-end.sh"},
      {"command": "./.claude/skills/memory-sync/scripts/sync-all.sh --cold-only"},
      {"command": "./.claude/hooks/post-session-qdrant-index.sh"}
    ]
  }
}
```

---

## Performance Targets

| Metric | Target | Rationale |
|--------|--------|-----------|
| Embedding generation | 100ms/text | Gemini API latency |
| Qdrant search | <50ms | HNSW index, local network |
| Indexing 100 records | <30 sec | Batched embeddings |
| Pre-task lookup | <2 sec | Parallel searches |
| Cache hit rate | >90% | Embedding reuse |

---

## Troubleshooting

### Qdrant Not Responding

```bash
# Check if running
curl http://qdrant.harbor.fyi/

# If down, fallback to keyword search
SKIP_QDRANT=true .claude/hooks/pre-task-memory-lookup.sh "query"
```

### Embedding Generation Fails

```bash
# Check API key
echo $GEMINI_API_KEY

# Test API
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model": "models/text-embedding-004", "content": {"parts": [{"text": "test"}]}}'
```

### Search Returns No Results

```bash
# Check collection size
curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'

# Re-index if empty
.claude/skills/memory-sync/scripts/index-to-qdrant.sh learnings
```

---

## Next Steps

1. **Read architecture document**: `QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md`
2. **Follow checklist**: `QDRANT-IMPLEMENTATION-CHECKLIST.md`
3. **Verify Qdrant running**: `curl http://qdrant.harbor.fyi/collections`
4. **Test embedding API**: `curl https://generativelanguage.googleapis.com/...`
5. **Run initial indexing**: `.claude/skills/memory-sync/scripts/index-to-qdrant.sh`

---

**Last Updated:** 2025-12-03
**Status:** Ready for Implementation
**Estimated Time:** 4 weeks (phased rollout)
