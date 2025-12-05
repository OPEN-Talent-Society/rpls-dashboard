# Memory System Quick Reference

> 4-phase lifecycle with exact commands for the 7-backend memory system.

---

## The 4 Phases

```
1. PRE-TASK    → Search all 7 backends (automatic via hook)
2. DURING      → Incremental sync every 30 calls or 5 min (automatic)
3. POST-TASK   → Full cold storage sync (automatic via Stop hook)
4. EMERGENCY   → Manual flush before context compaction
```

---

## 7 Backends Architecture

### HOT (Local)
- **AgentDB** (`agentdb.db`) - Episodes, rewards, critiques
- **Swarm Memory** (`.swarm/memory.db`) - Patterns, trajectories
- **Hive-Mind** (`<project>/.hive-mind/memory.json`) - Per-project state

### SEMANTIC (Cloud)
- **Qdrant** (http://qdrant.harbor.fyi) - Vector embeddings (768-dim)

### COLD (Cloud)
- **Supabase** - Patterns (36), learnings (69), agent_memory (218)
- **Cortex** (https://cortex.aienablement.academy) - SiYuan knowledge base
- **Agent Memory** - Key-value store

---

## Exact Commands

### 1. PRE-TASK (Automatic)

**Hook:** `.claude/hooks/pre-task-memory-lookup.sh`

**Manual search:**
```bash
# Search all backends
/memory:memory-search "topic"

# Or search specific topic
bash .claude/hooks/pre-task-memory-lookup.sh "your task description"
```

**Searches:**
- AgentDB for similar episodes
- Supabase for patterns and learnings
- Swarm Memory for trajectories
- Qdrant for semantic similarity
- Cortex knowledge base
- Hive-Mind per-project memory
- Agent Memory KV store

---

### 2. DURING TASK (Automatic)

**Hook:** `.claude/hooks/incremental-memory-sync.sh`

**Triggers:**
- Every 30 tool calls (Write/Edit/Bash/Task)
- Every 5 minutes
- Immediately on `agentdb_pattern_store`

**What it does:**
- Syncs AgentDB → Supabase (incremental)
- Syncs new patterns only
- Lightweight, non-blocking

---

### 3. POST-TASK (Automatic + Manual)

**Hook (automatic):** Stop hook calls `sync-all.sh --cold-only`

**Manual after completing work:**
```javascript
// Store reasoning pattern
mcp__claude-flow__agentdb_pattern_store({
  sessionId: "session-2025-12-04-HHMMSS",
  task: "What was accomplished (brief description)",
  reward: 0.9,  // 0-1 success metric (1.0 = perfect success)
  success: true,
  critique: "Self-reflection on approach, what worked, what could improve"
})
```

**Full manual sync:**
```bash
# Sync all hot → cold + semantic
bash .claude/skills/memory-sync/scripts/sync-all.sh

# With flags
bash .claude/skills/memory-sync/scripts/sync-all.sh --force  # Force full sync
bash .claude/skills/memory-sync/scripts/sync-all.sh --cold-only  # Skip Qdrant
bash .claude/skills/memory-sync/scripts/sync-all.sh --skip-qdrant  # Faster
```

**Slash command:**
```bash
/memory-sync  # Full sync to cloud + semantic layer
```

---

### 4. EMERGENCY (Manual - CRITICAL)

**Before context compaction (token limit approaching):**
```bash
bash .claude/hooks/emergency-memory-flush.sh
```

**What it does:**
- Forces immediate full sync to all cold backends
- Ensures no data loss from hot layer
- Bypasses incremental checks
- Saves critical session state

**When to use:**
- Context approaching 180k+ tokens
- About to reach token limit
- Long session with important patterns
- Before ending session unexpectedly

---

## Common Operations

### Check Memory Stats
```bash
/memory-stats

# Or manual
bash .claude/skills/memory-sync/scripts/memory-stats.sh
```

**Shows:**
- AgentDB: X episodes
- Supabase: X patterns, X learnings
- Qdrant: X vectors
- Sync state and timestamps

### Search Patterns
```javascript
// Search for similar past work
mcp__claude-flow__agentdb_pattern_search({
  task: "description of what you need",
  k: 5,  // Return top 5 results
  minReward: 0.7,  // Only successful patterns (>0.7)
  onlySuccesses: true  // Only successful episodes
})
```

### Pattern Statistics
```javascript
// Get aggregate stats for a task type
mcp__claude-flow__agentdb_pattern_stats({
  task: "authentication implementation",
  k: 5  // Analyze last 5 patterns
})
```

### Clear Cache
```javascript
// After bulk updates or when debugging
mcp__claude-flow__agentdb_clear_cache({
  confirm: true
})
```

---

## Best Practices

### ✅ DO
- Let hooks handle automatic syncing (they're configured correctly)
- Store patterns after completing significant work (>30 min effort)
- Use descriptive task descriptions for better future retrieval
- Add honest critique for learning
- Use reward scores accurately (0.0-1.0)
- Run emergency flush before context compaction

### ❌ DON'T
- Manually sync during task (use incremental hook)
- Skip storing patterns for significant work
- Use vague task descriptions
- Give perfect 1.0 scores unless truly flawless
- Ignore emergency flush when approaching token limit

---

## Reward Scoring Guide

| Score | Meaning | When to Use |
|-------|---------|-------------|
| 1.0 | Perfect | Flawless execution, all tests pass, no issues |
| 0.9 | Excellent | Works well, minor improvements possible |
| 0.8 | Good | Works correctly, some rough edges |
| 0.7 | Acceptable | Works but has known issues |
| 0.5 | Partial | Incomplete but some value |
| 0.0 | Failed | Did not work, needs complete redo |

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
- Force sync manually: `bash .claude/skills/memory-sync/scripts/sync-all.sh --force`

### Parallel session conflicts
- Check lock: `bash .claude/hooks/session-lock.sh check`
- Review `/tmp/claude-code-session.lock`
- Work in separate project folders (isolated Hive-Mind)

---

## Architecture Diagram

```
PRE-TASK SEARCH (UserPromptSubmit hook)
┌─────────────────────────────────────────┐
│ Search all 7 backends:                  │
│ ✓ AgentDB (episodes)                    │
│ ✓ Supabase (patterns, learnings)        │
│ ✓ Swarm Memory (trajectories)           │
│ ✓ Qdrant (semantic vectors)             │
│ ✓ Cortex (knowledge)                    │
│ ✓ Hive-Mind (project state)             │
│ ✓ Agent Memory (KV store)               │
└─────────────────────────────────────────┘
            ↓
      WORK HAPPENS
            ↓
DURING TASK SYNC (PostToolUse hooks)
┌─────────────────────────────────────────┐
│ Every 30 calls or 5 min:                │
│ AgentDB → Supabase (incremental)        │
└─────────────────────────────────────────┘
            ↓
      MORE WORK
            ↓
POST-TASK SYNC (Stop hook)
┌─────────────────────────────────────────┐
│ Full cold storage sync:                 │
│ AgentDB → Supabase + Cortex + Qdrant    │
│ Swarm → Supabase + Cortex + Qdrant      │
│ Hive-Mind → Supabase + Cortex + Qdrant  │
└─────────────────────────────────────────┘
```

---

**Full SOP:** `.claude/docs/MEMORY-SOP.md`

**Last Updated:** 2025-12-04
**Version:** 1.0 (Quick reference for 4-phase lifecycle)
