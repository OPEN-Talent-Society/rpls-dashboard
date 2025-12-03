# Qdrant Semantic Layer - Implementation Checklist

**Reference:** See `QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md` for full design
**Target:** Week 1-4 rollout
**Owner:** Claude Code + Human Developer

---

## Quick Reference: Data Flow

```
USER PROMPT
    │
    ▼
PRE-TASK LOOKUP (Enhanced)
    │
    ├─── 1. SEMANTIC (Qdrant) ★ NEW
    │    ├─ Embed query (Gemini API)
    │    ├─ Search learnings (top 3)
    │    ├─ Search patterns (top 3)
    │    └─ Search memory (top 3)
    │
    ├─── 2. KEYWORD (AgentDB/Supabase)
    ├─── 3. GRAPH (Swarm/Hive-Mind)
    └─── 4. DOCS (Cortex/SiYuan)
         │
         ▼
    UNIFIED CONTEXT
         │
         ▼
    AGENT STARTS TASK
```

---

## Phase 1: Foundation (Week 1)

### 1.1 Infrastructure Setup

- [ ] **Verify Qdrant instance**
  ```bash
  curl http://qdrant.harbor.fyi/collections
  # Expected: 200 OK, list of collections
  ```

- [ ] **Verify Gemini API key**
  ```bash
  echo $GEMINI_API_KEY
  curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"model": "models/text-embedding-004", "content": {"parts": [{"text": "test"}]}}'
  # Expected: 200 OK, embedding array
  ```

- [ ] **Update agent_memory collection** (migrate from 384 to 768 dims)
  ```bash
  # Delete old collection (WARNING: loses data)
  curl -X DELETE "http://qdrant.harbor.fyi/collections/agent_memory"

  # Recreate with 768 dims
  curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
  ```

- [ ] **Create missing collections**
  ```bash
  # Create learnings collection
  curl -X PUT "http://qdrant.harbor.fyi/collections/learnings" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 768, "distance": "Cosine"}}'

  # Create patterns collection
  curl -X PUT "http://qdrant.harbor.fyi/collections/patterns" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
  ```

### 1.2 Script Updates

- [ ] **Update `index-to-qdrant.sh`**
  - Change embedding model to text-embedding-004 (768 dims)
  - Add batch processing (10 embeddings per API call)
  - Add error handling for API failures
  - Add progress indicators
  - Location: `.claude/skills/memory-sync/scripts/index-to-qdrant.sh`

- [ ] **Test embedding generation**
  ```bash
  # Test single embedding
  .claude/skills/memory-sync/scripts/test-embedding.sh "PostgreSQL optimization"

  # Test batch embedding (create this helper)
  .claude/skills/memory-sync/scripts/test-embedding-batch.sh
  ```

- [ ] **Test indexing script**
  ```bash
  # Dry run (no upsert)
  DRY_RUN=1 .claude/skills/memory-sync/scripts/index-to-qdrant.sh

  # Index learnings only
  .claude/skills/memory-sync/scripts/index-to-qdrant.sh learnings

  # Full index (all collections)
  .claude/skills/memory-sync/scripts/index-to-qdrant.sh
  ```

### 1.3 Initial Data Load

- [ ] **Index existing Supabase data**
  ```bash
  # Expected counts:
  # - learnings: 69 records
  # - patterns: 36 records
  # - agent_memory: 218 records

  .claude/skills/memory-sync/scripts/index-to-qdrant.sh
  ```

- [ ] **Verify indexed data**
  ```bash
  # Check collection sizes
  curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'
  curl http://qdrant.harbor.fyi/collections/patterns | jq '.result.points_count'
  curl http://qdrant.harbor.fyi/collections/agent_memory | jq '.result.points_count'

  # Expected: ~69, ~36, ~218 respectively
  ```

- [ ] **Test search functionality**
  ```bash
  # Manual search test
  .claude/skills/memory-sync/scripts/test-qdrant-search.sh "database optimization"
  ```

### 1.4 Documentation

- [ ] **Update MEMORY-SOP.md**
  - Add Qdrant to architecture diagram
  - Document sync triggers
  - Add troubleshooting section

- [ ] **Create helper scripts**
  - `test-embedding.sh` - Test single embedding generation
  - `test-embedding-batch.sh` - Test batch embedding
  - `test-qdrant-search.sh` - Test semantic search
  - `qdrant-stats.sh` - Show collection statistics

---

## Phase 2: Integration (Week 2)

### 2.1 Pre-Task Lookup Enhancement

- [ ] **Backup existing script**
  ```bash
  cp .claude/hooks/pre-task-memory-lookup.sh .claude/hooks/pre-task-memory-lookup.sh.backup
  ```

- [ ] **Add Qdrant search function**
  ```bash
  # Add to pre-task-memory-lookup.sh
  search_qdrant() {
      local query="$1"
      local limit="${2:-3}"

      # Generate embedding
      local embedding=$(get_embedding "$query")

      # Search each collection
      for collection in learnings patterns agent_memory; do
          curl -s -X POST "http://qdrant.harbor.fyi/collections/${collection}/points/search" \
              -H "Content-Type: application/json" \
              -d "{\"vector\": $embedding, \"limit\": $limit, \"with_payload\": true}"
      done
  }
  ```

- [ ] **Integrate into lookup flow**
  - Add semantic search as FIRST step
  - Keep keyword/graph/docs search as fallback
  - Format output with score thresholds (>0.7)

- [ ] **Test enhanced lookup**
  ```bash
  # Test various query types
  .claude/hooks/pre-task-memory-lookup.sh "database optimization"
  .claude/hooks/pre-task-memory-lookup.sh "authentication bug"
  .claude/hooks/pre-task-memory-lookup.sh "parallel execution pattern"

  # Verify semantic results appear first
  ```

### 2.2 Sync Integration

- [ ] **Create `post-session-qdrant-index.sh` hook**
  ```bash
  # Location: .claude/hooks/post-session-qdrant-index.sh
  # Triggered by Stop hook AFTER sync-all.sh
  # Only indexes NEW/UPDATED records (incremental)
  ```

- [ ] **Update `sync-all.sh`**
  ```bash
  # Add Qdrant indexing step
  if [ "$SKIP_QDRANT" != "true" ]; then
      echo "🔍 Indexing to Qdrant semantic layer..."
      .claude/skills/memory-sync/scripts/index-to-qdrant.sh --incremental
  fi
  ```

- [ ] **Update `.claude/settings.json`**
  ```json
  {
    "hooks": {
      "Stop": [
        {
          "hooks": [
            {"command": "./.claude/hooks/session-end.sh"},
            {"command": "./.claude/skills/memory-sync/scripts/sync-all.sh --cold-only"},
            {"command": "./.claude/hooks/post-session-qdrant-index.sh"}
          ]
        }
      ]
    }
  }
  ```

- [ ] **Test full sync flow**
  ```bash
  # Simulate session end
  .claude/hooks/session-end.sh
  .claude/skills/memory-sync/scripts/sync-all.sh --cold-only
  .claude/hooks/post-session-qdrant-index.sh

  # Verify new data indexed
  curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'
  ```

### 2.3 Error Handling

- [ ] **Add fallback for Qdrant failures**
  ```bash
  # In pre-task-memory-lookup.sh
  if ! curl -s http://qdrant.harbor.fyi/ > /dev/null; then
      echo "⚠️  Qdrant unavailable, using keyword search only"
      SKIP_QDRANT=true
  fi
  ```

- [ ] **Add fallback for Gemini API failures**
  ```bash
  # In index-to-qdrant.sh
  get_embedding() {
      local text="$1"
      local response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_KEY}" ...)

      if [ -z "$response" ] || [ "$response" == "null" ]; then
          echo "⚠️  Embedding generation failed for: $text" >> /tmp/qdrant-errors.log
          return 1
      fi

      echo "$response" | jq -c '.embedding.values'
  }
  ```

- [ ] **Test error scenarios**
  ```bash
  # Test with invalid API key
  GEMINI_API_KEY="invalid" .claude/skills/memory-sync/scripts/index-to-qdrant.sh

  # Test with Qdrant down
  # (temporarily stop Qdrant service)
  .claude/hooks/pre-task-memory-lookup.sh "test query"

  # Expected: Graceful degradation to keyword search
  ```

---

## Phase 3: Optimization (Week 3)

### 3.1 Embedding Caching

- [ ] **Add embedding column to Supabase**
  ```sql
  -- Run in Supabase SQL editor
  ALTER TABLE learnings ADD COLUMN embedding JSONB;
  ALTER TABLE patterns ADD COLUMN embedding JSONB;
  ALTER TABLE agent_memory ADD COLUMN embedding JSONB;

  CREATE INDEX idx_learnings_embedding ON learnings USING GIN (embedding);
  CREATE INDEX idx_patterns_embedding ON patterns USING GIN (embedding);
  CREATE INDEX idx_agent_memory_embedding ON agent_memory USING GIN (embedding);
  ```

- [ ] **Update indexing script to use cache**
  ```bash
  # Check if embedding exists in Supabase
  # If exists AND content_hash matches, reuse
  # If not, generate new embedding and store
  ```

- [ ] **Add content hash tracking**
  ```sql
  ALTER TABLE learnings ADD COLUMN content_hash TEXT;
  ALTER TABLE patterns ADD COLUMN content_hash TEXT;
  ALTER TABLE agent_memory ADD COLUMN content_hash TEXT;
  ```

- [ ] **Test cache hit rate**
  ```bash
  # Run indexing twice, measure API calls
  VERBOSE=1 .claude/skills/memory-sync/scripts/index-to-qdrant.sh > /tmp/index-run1.log
  VERBOSE=1 .claude/skills/memory-sync/scripts/index-to-qdrant.sh > /tmp/index-run2.log

  # Compare API call counts (run2 should be ~90% fewer)
  ```

### 3.2 Incremental Indexing

- [ ] **Add `last_indexed` timestamp**
  ```sql
  ALTER TABLE learnings ADD COLUMN last_indexed_at TIMESTAMPTZ;
  ALTER TABLE patterns ADD COLUMN last_indexed_at TIMESTAMPTZ;
  ALTER TABLE agent_memory ADD COLUMN last_indexed_at TIMESTAMPTZ;
  ```

- [ ] **Update indexing script for incremental mode**
  ```bash
  # Only index records where:
  # - last_indexed_at IS NULL (never indexed)
  # - updated_at > last_indexed_at (modified since last index)
  ```

- [ ] **Test incremental indexing**
  ```bash
  # Full index
  .claude/skills/memory-sync/scripts/index-to-qdrant.sh

  # Add new learning to Supabase
  # Run incremental index
  .claude/skills/memory-sync/scripts/index-to-qdrant.sh --incremental

  # Expected: Only 1 new record indexed
  ```

### 3.3 Batch Processing

- [ ] **Implement batch embedding generation**
  ```bash
  # Generate 10 embeddings per API call
  # Reduces API calls by 10x
  # Trade-off: Slightly higher latency per batch
  ```

- [ ] **Implement batch Qdrant upsert**
  ```bash
  # Upsert 100 points per API call
  # Reduces Qdrant API calls by 100x
  ```

- [ ] **Test batch performance**
  ```bash
  # Measure indexing time for 100 records
  time BATCH_SIZE=1 .claude/skills/memory-sync/scripts/index-to-qdrant.sh
  time BATCH_SIZE=10 .claude/skills/memory-sync/scripts/index-to-qdrant.sh

  # Expected: 10x faster with batching
  ```

### 3.4 Monitoring

- [ ] **Create `qdrant-stats.sh` script**
  ```bash
  # Show:
  # - Collection sizes
  # - Index status
  # - Query latency (from metrics)
  # - Memory usage
  ```

- [ ] **Add to `/memory-stats` command**
  ```bash
  # Update .claude/commands/memory-stats.md
  # Include Qdrant collection counts
  ```

- [ ] **Set up alerts**
  ```bash
  # Alert if:
  # - Qdrant down (health check fails)
  # - Embedding API rate limit hit
  # - Collection size mismatch (Supabase vs Qdrant)
  ```

---

## Phase 4: Advanced Features (Week 4+)

### 4.1 Semantic Code Search

- [ ] **Index codebase to `codebase` collection**
  ```bash
  # Scan .ts, .js, .sh, .md files
  # Extract functions, classes, scripts
  # Generate embeddings for code + docstrings
  ```

- [ ] **Add code search to pre-task lookup**
  ```bash
  # Search for implementation examples
  # "How to implement retry logic?" → Returns code snippets
  ```

- [ ] **Test code search**
  ```bash
  .claude/hooks/pre-task-memory-lookup.sh "database connection pooling"
  # Expected: Code snippets from existing implementations
  ```

### 4.2 Filtered Search

- [ ] **Add category filtering**
  ```bash
  # Search only technical learnings
  curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
    -d '{
      "vector": [...],
      "filter": {"must": [{"key": "category", "match": {"value": "technical"}}]},
      "limit": 5
    }'
  ```

- [ ] **Add date range filtering**
  ```bash
  # Search only recent learnings (last 30 days)
  curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
    -d '{
      "vector": [...],
      "filter": {"must": [{"key": "created_at", "range": {"gte": "2025-11-03"}}]},
      "limit": 5
    }'
  ```

- [ ] **Add agent filtering**
  ```bash
  # Search only my learnings
  curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
    -d '{
      "vector": [...],
      "filter": {"must": [{"key": "agent_email", "match": {"value": "claude-code@aienablement.academy"}}]},
      "limit": 5
    }'
  ```

### 4.3 Hybrid Search

- [ ] **Combine semantic + keyword**
  ```bash
  # 1. Semantic search (Qdrant)
  # 2. Keyword search (Supabase)
  # 3. Merge results (deduplicate by ID)
  # 4. Re-rank by score (semantic) + relevance (keyword)
  ```

- [ ] **Implement reciprocal rank fusion**
  ```bash
  # Combine rankings from multiple sources
  # Score = 1/(k + rank) for each source
  # Sum scores across sources
  ```

- [ ] **Test hybrid search quality**
  ```bash
  # Compare results:
  # - Semantic only
  # - Keyword only
  # - Hybrid (both)

  # Expected: Hybrid has best precision + recall
  ```

### 4.4 User Commands

- [ ] **Create `/semantic-search <query>` command**
  ```bash
  # Location: .claude/commands/semantic-search.md
  # Directly search Qdrant (bypass pre-task lookup)
  # Show detailed results with scores
  ```

- [ ] **Create `/qdrant-stats` command**
  ```bash
  # Location: .claude/commands/qdrant-stats.md
  # Show collection sizes, index status, recent queries
  ```

- [ ] **Update `/memory-sync` command**
  ```bash
  # Add --qdrant-only flag
  # Rebuild Qdrant index without syncing HOT → COLD
  ```

---

## Testing Checklist

### Unit Tests

- [ ] Embedding generation (single)
- [ ] Embedding generation (batch)
- [ ] Qdrant upsert (single)
- [ ] Qdrant upsert (batch)
- [ ] Qdrant search (no filters)
- [ ] Qdrant search (with filters)
- [ ] Content hash calculation
- [ ] Cache hit detection

### Integration Tests

- [ ] Full indexing (learnings)
- [ ] Full indexing (patterns)
- [ ] Full indexing (agent_memory)
- [ ] Incremental indexing
- [ ] Pre-task lookup (with Qdrant)
- [ ] Pre-task lookup (Qdrant fallback)
- [ ] Sync flow (HOT → COLD → SEMANTIC)

### Performance Tests

- [ ] Indexing 100 records (batch vs single)
- [ ] Search latency (<50ms target)
- [ ] Embedding cache hit rate (>90% target)
- [ ] Pre-task lookup time (<2 sec target)

### Error Handling Tests

- [ ] Gemini API down
- [ ] Qdrant down
- [ ] Invalid API key
- [ ] Network timeout
- [ ] Malformed JSON response

---

## Rollback Plan

### If Qdrant Integration Fails

1. **Disable in pre-task lookup**
   ```bash
   # Comment out Qdrant search in script
   sed -i.bak 's/^search_qdrant/# DISABLED: search_qdrant/' .claude/hooks/pre-task-memory-lookup.sh
   ```

2. **Remove from sync flow**
   ```bash
   # Remove post-session-qdrant-index.sh from Stop hook
   # Edit .claude/settings.json
   ```

3. **Revert to keyword-only search**
   ```bash
   # Restore backup
   cp .claude/hooks/pre-task-memory-lookup.sh.backup .claude/hooks/pre-task-memory-lookup.sh
   ```

4. **Document failure**
   ```bash
   echo "$(date): Qdrant integration disabled due to [reason]" >> /tmp/qdrant-rollback.log
   ```

---

## Success Criteria

### Week 1 (Foundation)

- [ ] Qdrant collections created (learnings, patterns, agent_memory)
- [ ] Existing data indexed (69 learnings, 36 patterns, 218 memories)
- [ ] Search functionality tested and working

### Week 2 (Integration)

- [ ] Pre-task lookup enhanced with semantic search
- [ ] Sync flow updated to include Qdrant
- [ ] Error handling tested and working

### Week 3 (Optimization)

- [ ] Embedding caching implemented (>90% hit rate)
- [ ] Incremental indexing working
- [ ] Batch processing optimized

### Week 4 (Advanced)

- [ ] Code search functional
- [ ] Filtered search working
- [ ] Hybrid search implemented
- [ ] User commands created

---

## Next Steps

1. **Review architecture document**
   - Read `QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md`
   - Understand data flow and sync strategy

2. **Start Phase 1**
   - Verify Qdrant instance
   - Test embedding generation
   - Run initial indexing

3. **Monitor progress**
   - Use this checklist to track completion
   - Document issues in `/tmp/qdrant-issues.log`
   - Update architecture doc as needed

4. **Iterate and improve**
   - Collect feedback on search quality
   - Optimize based on performance metrics
   - Add features based on user needs

---

**Last Updated:** 2025-12-03
**Status:** Ready to Start Phase 1
**Estimated Completion:** 4 weeks
