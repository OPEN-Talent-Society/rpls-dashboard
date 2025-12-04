# Memory Operations Skill

## Overview
Unified interface for managing the 7-backend memory system. Provides high-level operations for search, sync, verification, and maintenance.

## Usage

```
skill: "memory-ops"
```

## Capabilities

### 1. Search Memory
Search across all memory backends with a single command.

```bash
bash .claude/skills/memory-ops/scripts/search.sh "query"
```

### 2. Sync Memory
Sync hot layer to cold storage and semantic layer.

```bash
# Full sync
bash .claude/skills/memory-ops/scripts/sync.sh

# Incremental sync
bash .claude/skills/memory-ops/scripts/sync.sh --incremental

# Force sync
bash .claude/skills/memory-ops/scripts/sync.sh --force
```

### 3. Check Health
Verify all memory backends are accessible and functioning.

```bash
bash .claude/skills/memory-ops/scripts/health.sh
```

### 4. Store Learning
Store a new learning across all backends.

```bash
bash .claude/skills/memory-ops/scripts/store-learning.sh "topic" "content"
```

## Environment Variables Required

```bash
# Supabase
PUBLIC_SUPABASE_URL=https://zxcrbcmdxpqprpxhsntc.supabase.co
PUBLIC_SUPABASE_ANON_KEY=<key>

# Cortex
CORTEX_URL=https://cortex.aienablement.academy
CORTEX_TOKEN=<token>
CF_ACCESS_CLIENT_ID=<id>
CF_ACCESS_CLIENT_SECRET=<secret>

# Qdrant
QDRANT_URL=https://qdrant.harbor.fyi
QDRANT_API_KEY=<key>
```

## Scripts

All scripts are located in `.claude/skills/memory-ops/scripts/`:

| Script | Purpose | Usage |
|--------|---------|-------|
| `search.sh` | Search all backends | `search.sh "query" [backend] [limit]` |
| `sync.sh` | Sync hot to cold | `sync.sh [--incremental\|--force]` |
| `health.sh` | Check backend health | `health.sh` |
| `store-learning.sh` | Store new learning | `store-learning.sh "topic" "content"` |

## Examples

### Search for past work
```bash
bash .claude/skills/memory-ops/scripts/search.sh "MCP token optimization"
```

### Sync all memory
```bash
bash .claude/skills/memory-ops/scripts/sync.sh
```

### Check system health
```bash
bash .claude/skills/memory-ops/scripts/health.sh
```

### Store a new learning
```bash
bash .claude/skills/memory-ops/scripts/store-learning.sh \
  "Qdrant HTTPS Requirement" \
  "Qdrant API requires HTTPS and api-key header for authentication"
```

## Notes

- Scripts use existing memory-sync scripts under the hood
- All operations log to `/tmp/memory-ops.log`
- Failed operations are logged to `/tmp/memory-ops-errors.log`
- Progress updates provided for long-running operations
