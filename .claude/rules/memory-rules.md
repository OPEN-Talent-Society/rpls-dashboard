# Memory Rules

## Trigger
Apply when completing tasks, storing learnings, or working with knowledge bases.

## Rules

### 1. Pre-Task Memory Recall (AUTOMATIC)
- Memory lookup runs automatically on every task via `pre-task-memory-lookup.sh`
- Searches: AgentDB, Supabase, Swarm, Cortex, Qdrant, Hive-Mind
- Context available at `/tmp/pre-task-context.md`

### 2. Pattern Storage (MANDATORY after significant work)
After completing meaningful tasks, store patterns:
```javascript
mcp__claude-flow__agentdb_pattern_store({
  sessionId: "session-id",
  task: "clear task description",
  reward: 0.9,  // 0-1 success metric
  success: true,
  input: "context provided",
  output: "solution implemented",
  critique: "self-reflection on approach"
})
```

### 3. Qdrant Search Guidelines
When searching for similar solutions:
```javascript
mcp__claude-flow__agentdb_pattern_search({
  task: "task description",
  k: 5,  // number of results
  onlySuccesses: true  // filter to successful patterns
})
```

### 4. Memory Sync Lifecycle
| Phase | Hook | Automatic |
|-------|------|-----------|
| Pre-task | `pre-task-memory-lookup.sh` | Yes (UserPromptSubmit) |
| During | `incremental-memory-sync.sh` | Yes (every 30 calls) |
| Post-task | `session-end.sh` | Yes (Stop hook) |
| Emergency | `emergency-memory-flush.sh` | Manual only |

### 5. When to Store Patterns
ALWAYS store patterns when:
- Solving a complex bug
- Implementing a new feature
- Learning a new approach
- Making architectural decisions
- Completing multi-step tasks

### 6. Memory Commands
```bash
# Search memory
/memory:memory-search "query"

# Check stats
/memory-stats

# Manual sync
bash .claude/skills/memory-sync/scripts/sync-all.sh
```

## Pre-Commit Check
Ensure significant learnings are stored before session end.
