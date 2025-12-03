# Qdrant Semantic Layer Architecture

**Version:** 1.0
**Date:** 2025-12-03
**Status:** Design Document
**Qdrant Instance:** http://qdrant.harbor.fyi (v1.13.4)

---

## Executive Summary

This document defines Qdrant's role as the **SEMANTIC LAYER** in the multi-layer memory architecture, bridging HOT (local) and COLD (cloud) storage with intelligent semantic search capabilities.

**Key Decision:** Qdrant serves as a **read-optimized semantic index** that enhances pre-task context retrieval through vector similarity search, complementing keyword-based search from other layers.

---

## 1. Layer Definition

### 1.1 Three-Layer Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                         MEMORY ARCHITECTURE                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  HOT LAYER (Local, Real-time)                                         │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ AgentDB (agentdb.db)          - Episodes, rewards, critiques │    │
│  │ Swarm Memory (.swarm/memory.db) - Patterns, trajectories     │    │
│  │ Hive-Mind (.hive-mind/memory.json) - Per-project state       │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                               │                                        │
│                               ▼ (sync)                                 │
│  SEMANTIC LAYER (Cloud, Index) ★ NEW                                  │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Qdrant (qdrant.harbor.fyi)   - Vector embeddings             │    │
│  │ Collections: agent_memory, learnings, patterns, codebase     │    │
│  │ Purpose: Semantic search, similarity matching                │    │
│  │ Sync: Read-only index rebuilt from HOT/COLD                  │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                               │                                        │
│                               ▼ (reference)                            │
│  COLD LAYER (Cloud, Persistent)                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Supabase (PostgreSQL)        - Patterns, learnings, memory   │    │
│  │ Cortex/SiYuan (Note DB)      - Human-readable knowledge      │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Qdrant Role

**Position:** Between HOT and COLD
**Type:** Semantic index (read-optimized)
**Purpose:** Intelligent context retrieval via vector similarity
**Data Flow:** HOT/COLD → Qdrant (index) → Pre-task lookup (query)

**Key Characteristics:**
- **Read-Only Index:** No source of truth, rebuilt from other layers
- **Eventual Consistency:** Synced on session end or manual trigger
- **Vector-First:** Embeddings for semantic similarity search
- **Metadata-Rich:** Payloads enable filtering and hybrid search

---

## 2. Data Flow

### 2.1 Write Path (Indexing)

```
┌─────────────────────────────────────────────────────────────────┐
│                      WRITE PATH: HOT → SEMANTIC → COLD          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. DURING TASK (Real-time)                                     │
│     Agent stores → AgentDB/Swarm/Hive-Mind (HOT)               │
│     ├─ agentdb_pattern_store()                                 │
│     ├─ memory_usage store()                                    │
│     └─ Hive-Mind consensus                                     │
│                                                                 │
│  2. INCREMENTAL SYNC (Every 30 calls or 5 min)                 │
│     HOT → Supabase (COLD)                                      │
│     └─ incremental-memory-sync.sh                              │
│        └─ sync-agentdb-to-supabase.sh                          │
│                                                                 │
│  3. SESSION END (Full sync)                                    │
│     HOT → COLD → SEMANTIC                                      │
│     ├─ sync-all.sh --cold-only                                 │
│     │  ├─ AgentDB → Supabase                                   │
│     │  ├─ AgentDB → Cortex                                     │
│     │  ├─ Hive-Mind → Supabase + Cortex                        │
│     │  └─ Swarm → Supabase + Cortex                            │
│     │                                                           │
│     └─ index-to-qdrant.sh (after sync)                         │
│        ├─ Fetch from Supabase (learnings, patterns, memory)   │
│        ├─ Generate embeddings (Gemini text-embedding-004)      │
│        └─ Upsert to Qdrant collections                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Read Path (Pre-Task Lookup)

```
┌─────────────────────────────────────────────────────────────────┐
│                   READ PATH: SEMANTIC LOOKUP                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  USER PROMPT SUBMITTED                                          │
│       │                                                         │
│       ▼                                                         │
│  pre-task-memory-lookup.sh                                      │
│       │                                                         │
│       ├─────────────────────────┬───────────────┬──────────────┤
│       ▼                         ▼               ▼              ▼
│  1. SEMANTIC (Qdrant)      2. KEYWORD      3. GRAPH      4. DOCS │
│     Vector search          AgentDB/        Swarm/        Cortex  │
│     ├─ Embed query         Supabase        Hive-Mind     SiYuan  │
│     ├─ Search learnings    SQL LIKE        Trajectories  Search  │
│     ├─ Search patterns     Pattern match   Patterns      Tags    │
│     └─ Search memory       Reward > 0.8    Consensus             │
│                                                                 │
│       │                         │               │              │
│       └─────────────────────────┴───────────────┴──────────────┘
│                               ▼                                 │
│                   UNIFIED CONTEXT OUTPUT                        │
│                   (Top 5 from each backend)                     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Key Insight:** Qdrant provides semantic matches that keyword search misses (e.g., "authentication bug" → "login error fix" via embeddings).

---

## 3. Collection Schema

### 3.1 Collection Design

Qdrant hosts **4 primary collections**, each serving a specific memory type:

| Collection | Source | Vector Dim | Distance | Purpose |
|------------|--------|------------|----------|---------|
| **agent_memory** | Supabase agent_memory | 768 | Cosine | General session memories |
| **learnings** | Supabase learnings | 768 | Cosine | Captured knowledge/insights |
| **patterns** | Supabase patterns | 768 | Cosine | Successful approaches |
| **codebase** | Local files + Cortex | 768 | Cosine | Code snippets for semantic code search |

**Embedding Model:** Google Gemini `text-embedding-004` (768 dimensions)
**Rationale:** Free tier, high quality, API-based (no local GPU needed)

### 3.2 Collection: `agent_memory`

**Purpose:** Session-level memories and key-value context

**Vector Source:** Embedding of `key: value`
**Payload Schema:**
```json
{
  "type": "memory",
  "namespace": "default",
  "source": "supabase",
  "original_id": "uuid-from-supabase",
  "key": "session/context/decision",
  "value_preview": "First 200 chars of value",
  "created_at": "2025-12-03T10:30:00Z",
  "agent_id": "claude-code@aienablement.academy",
  "ttl_seconds": 86400
}
```

**Search Use Case:**
Query: "How did we handle rate limiting last time?"
→ Returns memories with keys like `"api/rate-limit-strategy"`

**Current Status:** 0 vectors (needs initial indexing)

### 3.3 Collection: `learnings`

**Purpose:** Captured insights, TILs, and knowledge

**Vector Source:** Embedding of `topic: content`
**Payload Schema:**
```json
{
  "type": "learning",
  "category": "technical|workflow|tool|pattern",
  "source": "supabase",
  "original_id": "uuid-from-supabase",
  "topic": "PostgreSQL JSONB optimization",
  "content_preview": "First 300 chars",
  "tags": ["postgres", "performance", "jsonb"],
  "related_docs": ["cortex-doc-id-123"],
  "created_at": "2025-12-03T10:30:00Z",
  "agent_email": "claude-code@aienablement.academy"
}
```

**Search Use Case:**
Query: "database indexing best practices"
→ Returns learnings about GIN indexes, JSONB, query optimization

**Current Status:** Collection exists, needs indexing from Supabase (69 learnings)

### 3.4 Collection: `patterns`

**Purpose:** Reusable successful approaches and templates

**Vector Source:** Embedding of `name: description`
**Payload Schema:**
```json
{
  "type": "pattern",
  "category": "architecture|workflow|deployment|testing",
  "source": "supabase",
  "original_id": "uuid-from-supabase",
  "name": "Multi-agent coordination pattern",
  "description_preview": "First 300 chars",
  "use_cases": ["swarm", "parallel-execution"],
  "success_count": 12,
  "reward_avg": 0.92,
  "created_at": "2025-12-03T10:30:00Z",
  "updated_at": "2025-12-03T10:30:00Z"
}
```

**Search Use Case:**
Query: "parallel task execution strategies"
→ Returns patterns like "BatchTool pattern", "Swarm coordination"

**Current Status:** Collection exists, needs indexing from Supabase (36 patterns)

### 3.5 Collection: `codebase`

**Purpose:** Semantic code search for implementation examples

**Vector Source:** Embedding of code snippet + docstring
**Payload Schema:**
```json
{
  "type": "code",
  "language": "typescript|bash|python|markdown",
  "source": "cortex|local-file",
  "file_path": "/path/to/file.ts",
  "function_name": "syncMemoryToSupabase",
  "code_snippet": "First 500 chars of code",
  "docstring": "Function documentation",
  "imports": ["axios", "supabase"],
  "related_files": ["/path/to/related.ts"],
  "last_modified": "2025-12-03T10:30:00Z"
}
```

**Search Use Case:**
Query: "How to implement retry logic with exponential backoff?"
→ Returns code snippets from hooks, skills, or Cortex docs

**Current Status:** Collection exists, empty (future enhancement)

---

## 4. Sync Strategy

### 4.1 Sync Triggers

| Trigger | Frequency | What Syncs | Script |
|---------|-----------|------------|--------|
| **Tool calls** | Every 30 calls | HOT → COLD (incremental) | `incremental-memory-sync.sh` |
| **Time-based** | Every 5 minutes | HOT → COLD (incremental) | `incremental-memory-sync.sh` |
| **Pattern store** | Immediate | Single pattern → Supabase | `sync-agentdb-to-supabase.sh --single` |
| **Session end** | Once per session | HOT → COLD → SEMANTIC (full) | `sync-all.sh --cold-only` + `index-to-qdrant.sh` |
| **Manual** | On demand | All layers | `/memory-sync` command |

### 4.2 Incremental vs Full Sync

**Incremental Sync (During Session):**
- HOT → COLD only
- Skips Qdrant (too frequent for embedding generation)
- Tracks sync state in `/tmp/claude-memory-sync-state`

**Full Sync (Session End):**
- HOT → COLD (verification)
- COLD → SEMANTIC (rebuild index)
- Generates embeddings for new/updated records
- Updates all Qdrant collections

### 4.3 Embedding Generation

**Provider:** Google Gemini (text-embedding-004)
**Rate Limit:** 1500 requests/min (generous free tier)
**Cost:** $0.00 (free tier)
**Batch Size:** 10 embeddings per API call
**Fallback:** Skip embedding if API fails (log warning)

**Optimization:**
- Cache embeddings in Supabase (add `embedding` JSONB column)
- Only generate embeddings for new/updated records
- Use content hash to detect changes

### 4.4 Sync Script Updates

**New Hook: `post-session-qdrant-index.sh`**

```bash
#!/bin/bash
# Triggered by Stop hook AFTER sync-all.sh --cold-only
# Indexes all new/updated content to Qdrant

# 1. Fetch records modified since last index
# 2. Generate embeddings (batch API calls)
# 3. Upsert to Qdrant collections
# 4. Update last_indexed timestamp
```

**Updated: `sync-all.sh`**

```bash
# Add Qdrant indexing step
if [ "$SKIP_QDRANT" != "true" ]; then
    echo "🔍 Indexing to Qdrant semantic layer..."
    .claude/skills/memory-sync/scripts/index-to-qdrant.sh
fi
```

---

## 5. Pre-Task Semantic Lookup

### 5.1 Enhanced `pre-task-memory-lookup.sh`

**Current Behavior:** Searches AgentDB, Supabase, Swarm, Hive-Mind, Cortex (keyword-based)

**Enhanced Behavior:** Adds Qdrant semantic search as first step

```bash
#!/bin/bash
# pre-task-memory-lookup.sh (ENHANCED)

QUERY="$1"
LIMIT=5

echo "🔍 Pre-Task Memory Lookup: \"$QUERY\""
echo ""

# ★ NEW: 1. SEMANTIC SEARCH (Qdrant)
echo "🎯 Semantic Matches (Qdrant):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Generate embedding for query
QUERY_EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/text-embedding-004\", \"content\": {\"parts\": [{\"text\": \"$QUERY\"}]}}" \
    | jq -c '.embedding.values')

# Search each collection
for COLLECTION in learnings patterns agent_memory; do
    RESULTS=$(curl -s -X POST "http://qdrant.harbor.fyi/collections/${COLLECTION}/points/search" \
        -H "Content-Type: application/json" \
        -d "{\"vector\": $QUERY_EMBEDDING, \"limit\": 3, \"with_payload\": true}")

    # Display results
    echo "$RESULTS" | jq -r '.result[] |
        "📝 [\(.payload.type)] \(.payload.topic // .payload.name // .payload.key)
         💡 Score: \(.score | tostring[0:5])
         🔗 \(.payload.source): \(.payload.original_id)
        "'
done

# 2. KEYWORD SEARCH (AgentDB)
# [existing code...]

# 3. PATTERN SEARCH (Supabase)
# [existing code...]

# 4. TRAJECTORY SEARCH (Swarm)
# [existing code...]

# 5. KNOWLEDGE SEARCH (Cortex)
# [existing code...]
```

### 5.2 Hybrid Search Strategy

**Combine semantic + keyword for best results:**

| Search Type | Strength | Weakness | When to Use |
|-------------|----------|----------|-------------|
| **Semantic (Qdrant)** | Finds conceptually similar content | May miss exact matches | Exploratory queries, "how did we..." |
| **Keyword (SQL LIKE)** | Fast, exact matches | Misses synonyms | Known terms, IDs, specific names |
| **Graph (Swarm/Hive)** | Relationships, dependencies | Limited to session/project | Coordination, trajectories |
| **Full-text (Cortex)** | Human-readable context | Slower, less structured | Documentation, SOPs, ADRs |

**Optimal Flow:**
1. Qdrant semantic search (top 3 per collection)
2. AgentDB keyword search (top 5 episodes)
3. Supabase pattern search (top 5 patterns)
4. Swarm/Hive trajectory search (session-specific)
5. Cortex knowledge search (if needed)

**Output Format:**
```
🎯 Context for Task: "optimize database queries"

Semantic Matches (Score > 0.8):
├─ [learning] PostgreSQL JSONB optimization (0.92)
├─ [pattern] Index creation workflow (0.87)
└─ [memory] query/performance-tuning (0.84)

Keyword Matches:
├─ Episode: "Add GIN index to metadata column" (reward: 0.95)
└─ Pattern: "Database indexing checklist" (success: 12x)

✅ 8 relevant contexts found
```

---

## 6. Implementation Roadmap

### Phase 1: Foundation (Week 1)

**Goal:** Basic Qdrant indexing functional

- [ ] Update `index-to-qdrant.sh` for all collections
- [ ] Add embedding caching to Supabase schema
- [ ] Test embedding generation with Gemini API
- [ ] Verify Qdrant collection creation
- [ ] Index existing Supabase data (69 learnings, 36 patterns, 218 memories)

### Phase 2: Integration (Week 2)

**Goal:** Pre-task lookup uses Qdrant

- [ ] Enhance `pre-task-memory-lookup.sh` with semantic search
- [ ] Add Qdrant step to `sync-all.sh`
- [ ] Create `post-session-qdrant-index.sh` hook
- [ ] Update `.claude/settings.json` Stop hook
- [ ] Document in MEMORY-SOP.md

### Phase 3: Optimization (Week 3)

**Goal:** Production-ready performance

- [ ] Implement embedding caching (avoid re-embedding)
- [ ] Add incremental indexing (only new/updated)
- [ ] Batch embedding generation (10 per API call)
- [ ] Add retry logic for Gemini API failures
- [ ] Monitor Qdrant performance (query latency)

### Phase 4: Advanced Features (Week 4+)

**Goal:** Semantic code search and filtering

- [ ] Index codebase to `codebase` collection
- [ ] Add filtered search (by category, date, agent)
- [ ] Implement hybrid search (vector + keyword)
- [ ] Create `/semantic-search <query>` command
- [ ] Add Qdrant stats to `/memory-stats`

---

## 7. Operational Procedures

### 7.1 Initial Indexing

```bash
# First time setup
cd /Users/adamkovacs/Documents/codebuild

# Index all existing data
.claude/skills/memory-sync/scripts/index-to-qdrant.sh

# Verify collections
curl http://qdrant.harbor.fyi/collections | jq '.result.collections'

# Check counts
curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'
curl http://qdrant.harbor.fyi/collections/patterns | jq '.result.points_count'
curl http://qdrant.harbor.fyi/collections/agent_memory | jq '.result.points_count'
```

### 7.2 Manual Sync

```bash
# Full sync (HOT → COLD → SEMANTIC)
.claude/skills/memory-sync/scripts/sync-all.sh

# Qdrant only (rebuild index)
.claude/skills/memory-sync/scripts/index-to-qdrant.sh

# Specific collection
.claude/skills/memory-sync/scripts/index-to-qdrant.sh learnings
```

### 7.3 Testing Semantic Search

```bash
# Test embedding generation
curl -X POST "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model": "models/text-embedding-004", "content": {"parts": [{"text": "test query"}]}}'

# Test Qdrant search
curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
  -H "Content-Type: application/json" \
  -d '{"vector": [0.1, 0.2, ...], "limit": 5, "with_payload": true}'

# End-to-end test
.claude/hooks/pre-task-memory-lookup.sh "database optimization"
```

### 7.4 Monitoring

```bash
# Check Qdrant health
curl http://qdrant.harbor.fyi/

# Collection stats
curl http://qdrant.harbor.fyi/collections/learnings | jq '.'

# Memory usage
curl http://qdrant.harbor.fyi/metrics | grep qdrant_app_memory

# Query performance
curl http://qdrant.harbor.fyi/metrics | grep qdrant_search_duration
```

---

## 8. Security & Access Control

### 8.1 Qdrant Access

**Current:** Open HTTP (no authentication)
**Location:** Homelab (192.168.50.x → qdrant.harbor.fyi)
**Recommendation:** Add API key when exposing externally

**Future Security:**
```yaml
# docker-compose.yml (Qdrant)
environment:
  - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}
```

### 8.2 Gemini API Key

**Storage:** `.env` file (gitignored)
**Rotation:** Every 90 days
**Rate Limits:** 1500 req/min (free tier)

```bash
# .env
GEMINI_API_KEY=AIzaSy...
```

### 8.3 Data Privacy

**Sensitive Data Handling:**
- Do NOT embed PII (emails, passwords, tokens)
- Filter sensitive keys before indexing
- Use Qdrant payload filtering for RBAC

**Exclusion List:**
```bash
# Keys to exclude from embedding
EXCLUDE_KEYS=(
    "password"
    "token"
    "secret"
    "api_key"
    "private_key"
)
```

---

## 9. Performance Benchmarks

### 9.1 Expected Performance

| Metric | Target | Rationale |
|--------|--------|-----------|
| Embedding generation | 100ms/text | Gemini API latency |
| Qdrant search | <50ms | HNSW index, local network |
| Indexing 100 records | <30 sec | Batched embeddings |
| Pre-task lookup | <2 sec | Parallel searches |

### 9.2 Optimization Strategies

**Embedding Caching:**
- Store embeddings in Supabase (add `embedding` JSONB column)
- Only re-generate if content hash changes
- Reduces API calls by ~90%

**Qdrant Optimization:**
- Use HNSW config: `ef_construct=100, m=16`
- Enable `on_disk_payload` for memory efficiency
- Set `quantization` for large collections (>100k vectors)

**Batch Processing:**
- Generate embeddings in batches of 10
- Upsert to Qdrant in batches of 100
- Use async/parallel processing

---

## 10. Troubleshooting

### 10.1 Common Issues

**Issue: Qdrant collection not found**
```bash
# Solution: Recreate collection
curl -X PUT "http://qdrant.harbor.fyi/collections/learnings" \
  -H "Content-Type: application/json" \
  -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
```

**Issue: Embedding generation fails**
```bash
# Check Gemini API key
echo $GEMINI_API_KEY

# Test API
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"model": "models/text-embedding-004", "content": {"parts": [{"text": "test"}]}}'
```

**Issue: Search returns no results**
```bash
# Check collection size
curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'

# Re-index if empty
.claude/skills/memory-sync/scripts/index-to-qdrant.sh learnings
```

**Issue: Slow indexing**
```bash
# Enable verbose logging
DEBUG=1 .claude/skills/memory-sync/scripts/index-to-qdrant.sh

# Check network latency
ping qdrant.harbor.fyi

# Reduce batch size
BATCH_SIZE=5 .claude/skills/memory-sync/scripts/index-to-qdrant.sh
```

---

## 11. Future Enhancements

### 11.1 Advanced Features (Post-MVP)

**Hybrid Search (Vector + Keyword):**
```bash
# Combine semantic and keyword for best precision
curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
  -d '{
    "vector": [...],
    "filter": {
      "must": [
        {"key": "category", "match": {"value": "technical"}},
        {"key": "created_at", "range": {"gte": "2025-12-01"}}
      ]
    }
  }'
```

**Code Similarity Search:**
- Index all `.ts`, `.js`, `.sh`, `.md` files
- Search for implementation examples by natural language
- "How to implement retry logic?" → Returns relevant code snippets

**Multi-Modal Embeddings:**
- Embed screenshots from Playwright (using vision models)
- Embed diagrams from Cortex (using OCR + embedding)
- Search by visual similarity

**Personalized Ranking:**
- Track which results were useful (click-through rate)
- Re-rank search results based on historical usage
- Train a ranking model on user feedback

### 11.2 Integration with Other Tools

**Cortex/SiYuan:**
- Embed SiYuan blocks (backlinks, tags, PARA)
- Search Cortex by semantic similarity
- Sync Qdrant results back to Cortex as "Related Docs"

**RuVector (Future):**
- Evaluate RuVector when server ships (GitHub issue #20)
- Compare Qdrant vs RuVector for graph queries
- Consider hybrid: Qdrant (vectors) + RuVector (graphs)

**AgentDB/ReasoningBank:**
- Embed episode trajectories (sequences of actions)
- Search for similar problem-solving approaches
- Learn from successful patterns via semantic clustering

---

## 12. Success Metrics

### 12.1 Quantitative Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Pre-task lookup time | 3-5 sec | <2 sec | Hook execution time |
| Context relevance | 60% | 85% | Manual review of top 5 results |
| Embedding cache hit rate | N/A | >90% | Cache hits / total queries |
| Qdrant query latency | N/A | <50ms | Qdrant metrics endpoint |
| False negatives | N/A | <10% | Queries with no results (should have) |

### 12.2 Qualitative Metrics

**Developer Experience:**
- "I found exactly what I needed in the pre-task context"
- "Semantic search found a solution I forgot about"
- "The context was more relevant than keyword search"

**System Reliability:**
- Zero data loss from Qdrant downtime (COLD layer is source of truth)
- Graceful degradation (fallback to keyword search if Qdrant fails)
- No performance regressions in core workflows

---

## 13. Rollout Plan

### 13.1 Phases

**Phase 1: Silent Launch (Week 1)**
- Deploy Qdrant indexing (session end only)
- Monitor embedding generation success rate
- Do NOT add to pre-task lookup yet
- Goal: Validate infrastructure

**Phase 2: Beta Testing (Week 2)**
- Add Qdrant to pre-task lookup (optional flag)
- Test with 10 sessions
- Compare semantic vs keyword results
- Goal: Validate search quality

**Phase 3: General Availability (Week 3)**
- Enable Qdrant by default in pre-task lookup
- Document in MEMORY-SOP.md
- Announce in project README
- Goal: Production deployment

**Phase 4: Optimization (Week 4+)**
- Implement embedding caching
- Add hybrid search
- Index codebase
- Goal: Enhanced features

### 13.2 Rollback Plan

**If Qdrant fails or causes issues:**

1. Disable Qdrant in pre-task lookup (comment out in script)
2. Fallback to keyword search (existing behavior)
3. Log error to `/tmp/qdrant-error.log`
4. Continue session normally (zero impact)

**Rollback Script:**
```bash
# .claude/hooks/disable-qdrant.sh
sed -i.bak 's/^# SEMANTIC SEARCH/# DISABLED: SEMANTIC SEARCH/' .claude/hooks/pre-task-memory-lookup.sh
echo "⚠️  Qdrant disabled, using keyword search only"
```

---

## 14. Appendix

### 14.1 Qdrant Configuration

**Current Setup:**
- Instance: http://qdrant.harbor.fyi
- Version: v1.13.4
- Storage: On-disk (persistent)
- HNSW: m=16, ef_construct=100

**Collections:**
- agent_memory: 384 dims (legacy, needs migration to 768)
- learnings: Not created yet
- patterns: Not created yet
- codebase: Not created yet

### 14.2 Embedding Models Comparison

| Model | Dimensions | Cost | Quality | Speed |
|-------|------------|------|---------|-------|
| Gemini text-embedding-004 | 768 | Free | High | 100ms |
| OpenAI text-embedding-3-small | 1536 | $0.02/1M | High | 150ms |
| OpenAI text-embedding-3-large | 3072 | $0.13/1M | Highest | 200ms |
| Sentence-BERT (local) | 384 | Free | Medium | 50ms |

**Recommendation:** Start with Gemini (free, high quality, 768 dims). Migrate to OpenAI if quality issues arise.

### 14.3 SQL Queries for Data Export

**Export Supabase learnings:**
```sql
SELECT id, topic, content, category, tags, created_at
FROM learnings
WHERE created_at > NOW() - INTERVAL '30 days'
ORDER BY created_at DESC;
```

**Export Supabase patterns:**
```sql
SELECT id, name, description, category, success_count, created_at
FROM patterns
WHERE success_count > 0
ORDER BY success_count DESC;
```

**Export Supabase agent_memory:**
```sql
SELECT id, key, value, namespace, created_at
FROM agent_memory
WHERE expires_at IS NULL OR expires_at > NOW()
ORDER BY created_at DESC;
```

### 14.4 Qdrant API Examples

**Create collection:**
```bash
curl -X PUT "http://qdrant.harbor.fyi/collections/learnings" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    },
    "optimizers_config": {
      "indexing_threshold": 10000
    },
    "hnsw_config": {
      "m": 16,
      "ef_construct": 100
    }
  }'
```

**Upsert points:**
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

**Search:**
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

---

## 15. Conclusion

Qdrant's role as the **SEMANTIC LAYER** bridges HOT (local) and COLD (cloud) storage, enabling intelligent pre-task context retrieval through vector similarity search. By indexing memories, learnings, patterns, and code, Qdrant transforms keyword-based search into semantic understanding, helping agents find relevant context even when exact terms don't match.

**Key Takeaways:**
1. Qdrant is a **read-only index**, not a source of truth
2. Data flows **HOT → COLD → SEMANTIC** (one-way)
3. Sync happens **on session end** (incremental during session goes to COLD only)
4. Pre-task lookup uses **hybrid search** (semantic + keyword + graph)
5. Embeddings are cached in Supabase to avoid re-generation

**Next Steps:**
1. Run initial indexing: `.claude/skills/memory-sync/scripts/index-to-qdrant.sh`
2. Test semantic search manually
3. Enhance pre-task lookup script
4. Deploy to production with rollback plan
5. Monitor performance and iterate

---

**Document Version:** 1.0
**Last Updated:** 2025-12-03
**Author:** Claude Code
**Status:** Ready for Implementation
