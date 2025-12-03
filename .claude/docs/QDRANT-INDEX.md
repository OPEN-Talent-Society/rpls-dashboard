# Qdrant Semantic Layer Documentation - Index

**Created:** 2025-12-03
**Status:** Design Complete, Ready for Implementation

---

## Document Overview

This documentation package provides a complete architecture design for integrating Qdrant as a semantic layer in the multi-layer memory system.

### Documentation Structure

```
.claude/docs/
├── QDRANT-INDEX.md (this file)
│   └── Navigation and overview
│
├── QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md
│   └── Complete technical design (15,000+ words)
│       ├── Layer definitions
│       ├── Data flow diagrams
│       ├── Collection schemas
│       ├── Sync strategy
│       ├── Implementation roadmap
│       ├── Operational procedures
│       └── Troubleshooting
│
├── QDRANT-IMPLEMENTATION-CHECKLIST.md
│   └── Phased implementation plan (3,500+ words)
│       ├── Phase 1: Foundation (Week 1)
│       ├── Phase 2: Integration (Week 2)
│       ├── Phase 3: Optimization (Week 3)
│       ├── Phase 4: Advanced Features (Week 4+)
│       ├── Testing procedures
│       └── Success criteria
│
└── QDRANT-QUICK-REFERENCE.md
    └── Command reference and visual guides (2,000+ words)
        ├── Visual architecture diagrams
        ├── Data flow charts
        ├── Collection schemas with examples
        ├── Script commands
        ├── API reference
        └── Troubleshooting quick fixes
```

---

## Quick Navigation

### For First-Time Readers

1. **Start here:** [QDRANT-QUICK-REFERENCE.md](./QDRANT-QUICK-REFERENCE.md)
   - Visual diagrams explain the architecture at a glance
   - Quick command reference for common tasks
   - 5-minute overview

2. **Deep dive:** [QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md)
   - Complete technical specification
   - Design decisions and rationale
   - 30-minute read

3. **Implementation:** [QDRANT-IMPLEMENTATION-CHECKLIST.md](./QDRANT-IMPLEMENTATION-CHECKLIST.md)
   - Step-by-step task lists
   - Testing procedures
   - Track your progress

### For Specific Topics

**Architecture & Design:**
- Layer definitions: [Architecture Doc § 1](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#1-layer-definition)
- Data flow: [Architecture Doc § 2](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#2-data-flow)
- Collection schemas: [Architecture Doc § 3](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#3-collection-schema)

**Implementation:**
- Week 1 tasks: [Checklist § Phase 1](./QDRANT-IMPLEMENTATION-CHECKLIST.md#phase-1-foundation-week-1)
- Week 2 tasks: [Checklist § Phase 2](./QDRANT-IMPLEMENTATION-CHECKLIST.md#phase-2-integration-week-2)
- Week 3 tasks: [Checklist § Phase 3](./QDRANT-IMPLEMENTATION-CHECKLIST.md#phase-3-optimization-week-3)
- Week 4+ tasks: [Checklist § Phase 4](./QDRANT-IMPLEMENTATION-CHECKLIST.md#phase-4-advanced-features-week-4)

**Operations:**
- Scripts: [Quick Ref § Key Scripts](./QDRANT-QUICK-REFERENCE.md#key-scripts)
- Monitoring: [Architecture Doc § 7.4](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#74-monitoring)
- Troubleshooting: [Quick Ref § Troubleshooting](./QDRANT-QUICK-REFERENCE.md#troubleshooting)

**API Reference:**
- Qdrant API: [Quick Ref § Qdrant API](./QDRANT-QUICK-REFERENCE.md#qdrant-api-quick-reference)
- Gemini Embeddings: [Quick Ref § Embedding Model](./QDRANT-QUICK-REFERENCE.md#embedding-model)
- Collection operations: [Architecture Doc § 14.4](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#144-qdrant-api-examples)

---

## Architecture Summary

### Three-Layer Model

```
┌─────────────────────────────────────┐
│  HOT LAYER (Local, Real-time)      │
│  AgentDB, Swarm, Hive-Mind          │
│  Write: Immediate                   │
└─────────────┬───────────────────────┘
              │ (sync every 30 calls/5 min)
              ▼
┌─────────────────────────────────────┐
│  SEMANTIC LAYER (Cloud, Index)      │
│  Qdrant - Vector Embeddings         │
│  Purpose: Semantic search           │
└─────────────┬───────────────────────┘
              │ (reference source)
              ▼
┌─────────────────────────────────────┐
│  COLD LAYER (Cloud, Persistent)     │
│  Supabase, Cortex/SiYuan            │
│  Source of truth                    │
└─────────────────────────────────────┘
```

### Key Insight

**Qdrant is NOT a source of truth.** It's a read-optimized semantic index that enhances pre-task context retrieval by finding conceptually similar content that keyword search misses.

**Example:**
- User prompt: "authentication bug"
- Keyword search: Looks for exact term "authentication bug"
- Semantic search: Finds "login error fix", "session timeout issue", "OAuth token problem" (conceptually similar)

---

## Implementation Timeline

### Week 1: Foundation
- Set up Qdrant collections (learnings, patterns, agent_memory)
- Index existing Supabase data (~323 records)
- Test embedding generation and search

### Week 2: Integration
- Enhance pre-task lookup with semantic search
- Add Qdrant indexing to sync flow
- Update hooks and settings

### Week 3: Optimization
- Implement embedding caching (90% hit rate)
- Add incremental indexing
- Batch processing and monitoring

### Week 4+: Advanced Features
- Semantic code search
- Filtered and hybrid search
- User commands and dashboards

---

## Technical Specifications

### Qdrant Instance
- **URL:** http://qdrant.harbor.fyi
- **Version:** v1.13.4
- **Collections:** agent_memory, learnings, patterns, codebase

### Embedding Model
- **Provider:** Google Gemini
- **Model:** text-embedding-004
- **Dimensions:** 768
- **Cost:** Free tier (1500 req/min)

### Collections

| Collection | Source | Records | Purpose |
|------------|--------|---------|---------|
| agent_memory | Supabase | 218 | Session memories |
| learnings | Supabase | 69 | Captured knowledge |
| patterns | Supabase | 36 | Successful approaches |
| codebase | Local + Cortex | 0 | Code search (future) |

### Performance Targets

| Metric | Baseline | Target |
|--------|----------|--------|
| Pre-task lookup time | 3-5 sec | <2 sec |
| Context relevance | 60% | 85% |
| Qdrant query latency | N/A | <50ms |
| Cache hit rate | N/A | >90% |

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
# Pre-task lookup (automatic on UserPromptSubmit)
.claude/hooks/pre-task-memory-lookup.sh "database optimization"

# Manual semantic search
.claude/skills/memory-sync/scripts/semantic-search.sh "authentication patterns"

# Unified search (all backends)
.claude/skills/memory-sync/scripts/unified-search.sh "query"
```

### Syncing
```bash
# Full sync (HOT → COLD → SEMANTIC)
.claude/skills/memory-sync/scripts/sync-all.sh

# Cold only (skip Qdrant)
.claude/skills/memory-sync/scripts/sync-all.sh --cold-only

# Skip Qdrant (if down)
SKIP_QDRANT=true .claude/skills/memory-sync/scripts/sync-all.sh
```

### Monitoring
```bash
# Collection stats
curl http://qdrant.harbor.fyi/collections | jq '.result.collections'

# Specific collection
curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'

# Memory stats (all backends)
.claude/skills/memory-sync/scripts/memory-stats.sh
```

---

## Quick Start

### Prerequisites
1. **Qdrant running:**
   ```bash
   curl http://qdrant.harbor.fyi/collections
   ```

2. **Gemini API key:**
   ```bash
   echo $GEMINI_API_KEY
   ```

3. **Supabase credentials:**
   ```bash
   echo $SUPABASE_SERVICE_ROLE_KEY
   ```

### Initial Setup (5 minutes)

1. **Update agent_memory collection** (384 → 768 dims):
   ```bash
   curl -X DELETE "http://qdrant.harbor.fyi/collections/agent_memory"
   curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory" \
     -H "Content-Type: application/json" \
     -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
   ```

2. **Create missing collections:**
   ```bash
   curl -X PUT "http://qdrant.harbor.fyi/collections/learnings" \
     -H "Content-Type: application/json" \
     -d '{"vectors": {"size": 768, "distance": "Cosine"}}'

   curl -X PUT "http://qdrant.harbor.fyi/collections/patterns" \
     -H "Content-Type: application/json" \
     -d '{"vectors": {"size": 768, "distance": "Cosine"}}'
   ```

3. **Index existing data:**
   ```bash
   .claude/skills/memory-sync/scripts/index-to-qdrant.sh
   ```

4. **Verify:**
   ```bash
   curl http://qdrant.harbor.fyi/collections/learnings | jq '.result.points_count'
   curl http://qdrant.harbor.fyi/collections/patterns | jq '.result.points_count'
   curl http://qdrant.harbor.fyi/collections/agent_memory | jq '.result.points_count'
   ```

5. **Test search:**
   ```bash
   .claude/skills/memory-sync/scripts/semantic-search.sh "database optimization"
   ```

---

## Decision Log

### Why Qdrant?
- **Already running** on homelab (http://qdrant.harbor.fyi)
- **Production-ready** (v1.13.4, battle-tested)
- **Rich features:** HNSW, quantization, filtering, hybrid search
- **RuVector alternative:** Server not available yet (GitHub issue #20)

### Why Gemini text-embedding-004?
- **Free tier** (1500 req/min, no cost)
- **High quality** (768 dims, comparable to OpenAI)
- **Fast** (~100ms per embedding)
- **No local GPU** needed (API-based)

### Why Middle Layer (not replace HOT/COLD)?
- **HOT layer:** Fast writes, real-time coordination
- **COLD layer:** Persistent storage, source of truth, human-readable
- **SEMANTIC layer:** Read-optimized, semantic search, enhances both

### Why Read-Only Index?
- **Simpler:** No conflict resolution, no writes
- **Safer:** Can't corrupt source data
- **Faster:** Optimized for search only
- **Recoverable:** Rebuild from COLD if lost

---

## Common Questions

### Q: What if Qdrant goes down?
**A:** Pre-task lookup gracefully falls back to keyword search. No impact on core workflows.

### Q: Do we lose data if Qdrant fails?
**A:** No. Qdrant is a read-only index. Source of truth is in HOT (AgentDB) and COLD (Supabase/Cortex).

### Q: How often is Qdrant updated?
**A:** On session end (Stop hook) or manual `/memory-sync` command. During session, only HOT → COLD sync happens.

### Q: Can I search Qdrant directly?
**A:** Yes, via `/semantic-search` command (future) or manually with `curl` to Qdrant API.

### Q: What's the cost?
**A:** $0. Gemini embeddings are free tier. Qdrant is self-hosted on homelab.

### Q: Can I use OpenAI embeddings instead?
**A:** Yes. Update `index-to-qdrant.sh` to use OpenAI API. Cost: $0.02/1M tokens for text-embedding-3-small.

### Q: What about RuVector?
**A:** RuVector server is not available yet (GitHub issue #20). We'll re-evaluate when it ships. Qdrant + RuVector hybrid is possible (Qdrant for vectors, RuVector for graphs).

---

## Related Documentation

### Memory System
- [MEMORY-SOP.md](./MEMORY-SOP.md) - Memory system standard operating procedure
- [MEMORY-SYNC skill](../.claude/skills/memory-sync/SKILL.md) - Memory sync commands

### Existing Research
- [qdrant-vs-ruvector-analysis.md](../../research/qdrant-vs-ruvector-analysis.md) - Qdrant vs RuVector comparison

### Infrastructure
- [infrastructure-context.json](../.claude/memory/infrastructure-context.json) - OCI, homelab, services
- [supabase-config.json](../.claude/.agentdb/supabase-config.json) - Supabase credentials and schema

---

## Support & Feedback

### Found an Issue?
1. Document in `/tmp/qdrant-issues.log`
2. Check [Troubleshooting](./QDRANT-QUICK-REFERENCE.md#troubleshooting)
3. Review [Architecture Doc § 10](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md#10-troubleshooting)

### Have a Suggestion?
1. Update relevant documentation
2. Test with proof-of-concept
3. Document results and propose changes

### Need Help?
- Quick reference: [QDRANT-QUICK-REFERENCE.md](./QDRANT-QUICK-REFERENCE.md)
- Architecture: [QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md](./QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md)
- Checklist: [QDRANT-IMPLEMENTATION-CHECKLIST.md](./QDRANT-IMPLEMENTATION-CHECKLIST.md)

---

## Document Maintenance

### Version History
- **v1.0** (2025-12-03): Initial design document package

### Update Schedule
- **After Phase 1:** Update with actual performance metrics
- **After Phase 2:** Document integration challenges and solutions
- **After Phase 3:** Add optimization learnings
- **After Phase 4:** Document advanced features

### Contributing
When updating these documents:
1. Maintain consistent formatting
2. Update "Last Updated" dates
3. Document breaking changes
4. Keep examples current
5. Test all code snippets

---

## Appendix: File Locations

### Documentation
```
/Users/adamkovacs/Documents/codebuild/.claude/docs/
├── QDRANT-INDEX.md (this file)
├── QDRANT-SEMANTIC-LAYER-ARCHITECTURE.md
├── QDRANT-IMPLEMENTATION-CHECKLIST.md
└── QDRANT-QUICK-REFERENCE.md
```

### Scripts
```
/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/
├── index-to-qdrant.sh
├── semantic-search.sh
├── sync-all.sh
├── sync-agentdb-to-supabase.sh
├── sync-agentdb-to-cortex.sh
├── sync-hivemind-to-cold.sh
└── sync-swarm-to-cold.sh
```

### Hooks
```
/Users/adamkovacs/Documents/codebuild/.claude/hooks/
├── pre-task-memory-lookup.sh
├── incremental-memory-sync.sh
├── memory-sync-hook.sh
├── emergency-memory-flush.sh
└── post-session-qdrant-index.sh (to be created)
```

### Configuration
```
/Users/adamkovacs/Documents/codebuild/
├── .env (Gemini API key, Supabase credentials)
├── .claude/settings.json (hooks configuration)
└── .claude/.agentdb/supabase-config.json (Supabase schema)
```

---

**Last Updated:** 2025-12-03
**Status:** Design Complete, Ready for Implementation
**Next Step:** Review documents and start Phase 1

---

**End of Index**
