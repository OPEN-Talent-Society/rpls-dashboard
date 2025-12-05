---
description: "Search across ALL memory backends (Supabase, AgentDB, Swarm, Cortex, Qdrant)"
allowed-tools:
  - Bash
  - mcp__claude-flow__qdrant_search
  - mcp__claude-flow__qdrant_hybrid_search
---

# Unified Memory Search

Search across all 6 memory backends: Supabase (patterns, learnings, agent_memory), AgentDB, Swarm Memory, Cortex, and Qdrant (semantic search).

## Quick Search

```bash
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS"
```

## Backend-Specific Search

```bash
# Search only Supabase
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS" supabase

# Search only AgentDB
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS" agentdb

# Search only Swarm Memory
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS" swarm

# Search only Cortex
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS" cortex

# Search only Qdrant (semantic)
.claude/skills/memory-sync/scripts/unified-search.sh "$ARGUMENTS" qdrant
```

## Semantic Search with Qdrant

Qdrant provides vector-based semantic search for finding conceptually similar memories, not just keyword matches.

### Using MCP Tools (Recommended)

```bash
# Semantic search - finds conceptually similar results
mcp__claude-flow__qdrant_search \
  --collection "memories" \
  --query "authentication implementation patterns" \
  --limit 10

# Hybrid search - combines semantic + keyword matching
mcp__claude-flow__qdrant_hybrid_search \
  --collection "memories" \
  --query "user login JWT tokens" \
  --limit 10 \
  --filter '{"must": [{"key": "type", "match": {"value": "pattern"}}]}'
```

### Semantic Search Results Format

Qdrant results are highlighted separately to show semantic relevance:

```
🔍 SEMANTIC SEARCH RESULTS (Qdrant)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📊 Score: 0.94 | Type: pattern | Date: 2025-12-01
─────────────────────────────────────────────────
Content: JWT authentication with refresh tokens
Tags: auth, security, tokens
Context: Implemented in user-service API
─────────────────────────────────────────────────

📊 Score: 0.89 | Type: learning | Date: 2025-11-28
─────────────────────────────────────────────────
Content: bcrypt rounds=12 optimal for password hashing
Tags: security, performance, passwords
Context: Security audit recommendations
─────────────────────────────────────────────────
```

### Pre-Task Memory Lookup Hook

The pre-task hook automatically searches Qdrant for relevant context:

```bash
# Automatic semantic search before tasks
.claude/hooks/pre-task-memory-lookup.sh "implement user authentication"

# Returns: Relevant patterns, learnings, and previous implementations
```

## Memory Statistics

```bash
.claude/skills/memory-sync/scripts/memory-stats.sh
```
