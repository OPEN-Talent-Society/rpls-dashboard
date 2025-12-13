---
name: supabase-memory-ops
description: High-level operations for managing agent memory in Supabase (patterns and learnings tables). Use this skill for storing, retrieving, and managing reasoning patterns and learning records.
---

# Supabase Memory Operations

## Overview

This skill provides high-level operations for managing agent memory in Supabase, specifically the `patterns` and `learnings` tables. It wraps the low-level supabase-database skill with convenience functions for common memory operations.

## Prerequisites

Environment variables are automatically loaded from `.env` file:
- `PUBLIC_SUPABASE_URL` - https://zxcrbcmdxpqprpxhsntc.supabase.co
- `SUPABASE_SERVICE_ROLE_KEY` - Service role key

## Common Operations

### Store Learning

Store a new learning record in Supabase:

```bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

# Generate unique learning ID
LEARNING_ID="learning-$(date +%s)-$(openssl rand -hex 4)"

supabase_post "/rest/v1/learnings" '{
  "learning_id": "'"$LEARNING_ID"'",
  "topic": "Your learning topic",
  "category": "infrastructure|methodology|development",
  "content": "Detailed description of what was learned",
  "context": "Context in which this learning occurred",
  "agent_id": "claude-code",
  "agent_email": "claude-code@aienablement.academy",
  "tags": ["tag1", "tag2", "tag3"]
}'
```

### Search Learnings

Search for relevant learnings:

```bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

# Search by topic (case-insensitive)
supabase_get "/rest/v1/learnings?select=*&topic=ilike.*docker*&order=created_at.desc"

# Search by category
supabase_get "/rest/v1/learnings?select=*&category=eq.infrastructure&order=created_at.desc"

# Search by tags (contains)
supabase_get "/rest/v1/learnings?select=*&tags=cs.{automation}&order=created_at.desc"

# Recent learnings (last 10)
supabase_get "/rest/v1/learnings?select=*&order=created_at.desc&limit=10"
```

### Store Pattern

Store a successful reasoning pattern:

```bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

# Generate unique pattern ID
PATTERN_ID="pattern-$(date +%s)-$(openssl rand -hex 4)"

supabase_post "/rest/v1/patterns" '{
  "pattern_id": "'"$PATTERN_ID"'",
  "name": "Pattern Name",
  "category": "infrastructure|orchestration|workflow",
  "description": "What this pattern accomplishes",
  "template": {
    "steps": ["step1", "step2", "step3"],
    "tools": ["tool1", "tool2"]
  },
  "use_cases": ["use-case-1", "use-case-2"],
  "success_count": 1
}'
```

### Search Patterns

Find similar patterns for current task:

```bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

# Search by name or description
supabase_get "/rest/v1/patterns?select=*&or=(name.ilike.*deployment*,description.ilike.*deployment*)&order=success_count.desc"

# Get patterns by category
supabase_get "/rest/v1/patterns?select=*&category=eq.infrastructure&order=success_count.desc"

# Get most successful patterns
supabase_get "/rest/v1/patterns?select=*&order=success_count.desc&limit=10"
```

### Update Pattern Success Count

Increment success count when pattern is reused:

```bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

# Get current pattern
PATTERN=$(supabase_get "/rest/v1/patterns?select=success_count&pattern_id=eq.PTN-HIVE-MIND-CRAWL")
CURRENT_COUNT=$(echo "$PATTERN" | jq -r '.[0].success_count')
NEW_COUNT=$((CURRENT_COUNT + 1))

# Update success count
supabase_patch "/rest/v1/patterns?pattern_id=eq.PTN-HIVE-MIND-CRAWL" '{
  "success_count": '"$NEW_COUNT"',
  "updated_at": "'"$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)"'"
}'
```

## Table Schemas

### Learnings Table

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key (auto-generated) |
| `learning_id` | TEXT | Unique learning identifier |
| `topic` | TEXT | Learning topic/title |
| `category` | TEXT | Category (infrastructure, methodology, development) |
| `content` | TEXT | Detailed learning content |
| `context` | TEXT | Context in which learning occurred |
| `agent_id` | TEXT | Agent identifier |
| `agent_email` | TEXT | Agent email |
| `tags` | TEXT[] | Array of tags |
| `related_docs` | TEXT[] | Array of related documentation URLs |
| `metadata` | JSONB | Additional metadata |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

### Patterns Table

| Field | Type | Description |
|-------|------|-------------|
| `id` | UUID | Primary key (auto-generated) |
| `pattern_id` | TEXT | Unique pattern identifier |
| `name` | TEXT | Pattern name |
| `category` | TEXT | Category (infrastructure, orchestration, workflow) |
| `description` | TEXT | Pattern description |
| `template` | JSONB | Pattern template/structure |
| `use_cases` | TEXT[] | Array of use cases |
| `success_count` | INTEGER | Number of successful uses |
| `created_at` | TIMESTAMPTZ | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | Last update timestamp |

## Integration with Memory System

This skill integrates with the broader memory system documented in `.claude/docs/MEMORY-SOP.md`:

- **Supabase** - Cold storage layer for patterns and learnings
- **AgentDB** - Hot storage for reasoning episodes
- **Qdrant** - Semantic search for vectors
- **Cortex** - Knowledge management

Use this skill for:
- Storing successful patterns for reuse
- Recording learnings that should persist across sessions
- Searching historical patterns before attempting new approaches
- Building a knowledge base of proven solutions

## Examples

### Before Starting a Task

Search for similar patterns:

```bash
#!/bin/bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

TASK_DESCRIPTION="deploy docker container to OCI"

# Search patterns
echo "Searching for similar patterns..."
PATTERNS=$(supabase_get "/rest/v1/patterns?select=*&or=(name.ilike.*$TASK_DESCRIPTION*,description.ilike.*$TASK_DESCRIPTION*)&order=success_count.desc&limit=5")

echo "$PATTERNS" | jq -r '.[] | "\(.name): \(.description) (used \(.success_count) times)"'
```

### After Completing a Task

Store the learning:

```bash
#!/bin/bash
source "/Users/adamkovacs/Documents/codebuild/.claude/skills/supabase-scripts/supabase-api.sh"

LEARNING_ID="learning-$(date +%s)-$(openssl rand -hex 4)"

supabase_post "/rest/v1/learnings" '{
  "learning_id": "'"$LEARNING_ID"'",
  "topic": "Task Completion Learning",
  "category": "development",
  "content": "Discovered that X approach works better than Y because...",
  "context": "Completing task: deploy application to production",
  "agent_id": "claude-code",
  "agent_email": "claude-code@aienablement.academy",
  "tags": ["deployment", "best-practice", "automation"]
}'

echo "Learning stored with ID: $LEARNING_ID"
```

## Related Skills

- **supabase-database** - Low-level database operations
- **supabase-auth** - Authentication management
- **memory-sync** - Synchronize across all memory backends
- **agentdb-memory-patterns** - Local reasoning patterns

## Documentation

For more details:
- Repository: https://github.com/Nice-Wolf-Studio/claude-code-supabase-skills
- Memory SOP: `/Users/adamkovacs/Documents/codebuild/.claude/docs/MEMORY-SOP.md`
- Supabase API: https://supabase.com/docs/guides/api
