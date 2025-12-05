---
name: nocodb-tasks
description: "AI Enablement Academy's task management system. NocoDB is for human task tracking and agent accountability (human-in-the-loop observability). Development subtasks belong in epic documents with checkbox formatting, not as separate NocoDB tasks."
---

# NocoDB Task Management Skill

## Purpose & Philosophy

**NocoDB is AI Enablement Academy's central task management system for:**
- **Human task tracking** - Primary use case for team members
- **Agent accountability** - Agents log work here for human-in-the-loop observability
- **Sprint planning** - High-level work items and milestones
- **Audit trail** - What was done, when, and by whom

**NocoDB is NOT for:**
- Granular development subtasks (use epic documents instead)
- Every small step in an implementation (overkill and cumbersome)
- Temporary work items that don't need human visibility

---

## When to Create a NocoDB Task

| Scenario | Create NocoDB Task? | Alternative |
|----------|---------------------|-------------|
| New feature request | ✅ Yes | - |
| Bug report | ✅ Yes | - |
| Sprint work item | ✅ Yes | - |
| Agent starting significant work | ✅ Yes (for observability) | - |
| Implementation subtasks for an epic | ❌ No | Epic doc with checkboxes |
| Small code changes within a task | ❌ No | Update task description |
| Debugging steps | ❌ No | Log in task comments |

---

## Development Work Pattern

For epics and complex development work:

### 1. Create ONE NocoDB Task for the Epic
```bash
bash .claude/skills/nocodb-tasks/scripts/create-task.sh "Epic: User Authentication System" "In Progress" "P1"
```

### 2. Track Subtasks in Task Description (Checkbox Format)
Update the task description with checkbox-formatted subtasks:

```markdown
## Subtasks
- [x] Design authentication flow
- [x] Set up JWT library
- [ ] Implement login endpoint
- [ ] Implement registration endpoint
- [ ] Add password reset flow
- [ ] Write unit tests
- [ ] Integration testing

## Progress Notes
- 2025-12-04: Completed JWT setup, moving to endpoints
```

### 3. Update NocoDB Status as Work Progresses
```bash
# When starting
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "In Progress"

# When done
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "Done"
```

---

## Token Types (Important!)

NocoDB uses **two different token types**:

| Token | Environment Variable | Header | Purpose |
|-------|---------------------|--------|---------|
| **API Token** | `NOCODB_API_TOKEN` | `xc-token` | REST API v2/v3 calls |
| **MCP Token** | `NOCODB_MCP_TOKEN` | `xc-mcp-token` | MCP remote protocol |

**Critical**: The MCP token does NOT work with REST API calls. You must have `NOCODB_API_TOKEN` set for Tier 1 operations.

## Configuration

```bash
# Required environment variables in .env:
NOCODB_URL=https://ops.aienablement.academy
NOCODB_API_TOKEN=<your-api-token>          # For REST API (Tier 1)
NOCODB_MCP_TOKEN=<your-mcp-token>          # For MCP protocol (Tier 2)
NOCODB_DATABASE_ID=pz7wdven8yqgx3r         # Required for v3 API path
NOCODB_TASKS_TABLE_ID=mmx3z4zxdj9ysfk
NOCODB_SPRINTS_TABLE_ID=mtkfphwlmiv8mzp
```

## API Version

**Scripts use NocoDB API v3** (as of 2025-12-04)

v3 API benefits over v2:
- **Embedded relations**: Sprint data returned inline (no separate calls)
- **Unified record linking**: Link records in create/update calls
- **Standardized responses**: Consistent `{records: [...]}` format
- **Quoted where clauses**: Better special character handling

v3 endpoint pattern: `/api/v3/data/{baseId}/{tableId}/records`

---

## Tier 1: Simple Operations (No MCP - Saves ~3k tokens)

### Create Task
```bash
bash .claude/skills/nocodb-tasks/scripts/create-task.sh "Task title" "To Do" "P2"
```

### Update Task Status
```bash
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "Done"
```

### List Tasks
```bash
# All tasks
bash .claude/skills/nocodb-tasks/scripts/list-tasks.sh

# By status
bash .claude/skills/nocodb-tasks/scripts/list-tasks.sh "In Progress"
```

### Raw curl Examples (API v3)

```bash
source /Users/adamkovacs/Documents/codebuild/.env

# Create task (v3 uses "fields" wrapper)
curl -X POST "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${NOCODB_TASKS_TABLE_ID}/records" \
  -H "xc-token: ${NOCODB_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"fields": {"task name": "New task title", "Status": "To Do", "Assignee": [{"id": "uskfxdybo8kofowf"}]}}'

# Update task description (v3 uses array of {id, fields})
curl -X PATCH "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${NOCODB_TASKS_TABLE_ID}/records" \
  -H "xc-token: ${NOCODB_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[{"id": 123, "fields": {"Description": "## Subtasks\n- [x] Step 1\n- [ ] Step 2"}}]'

# Update task status
curl -X PATCH "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${NOCODB_TASKS_TABLE_ID}/records" \
  -H "xc-token: ${NOCODB_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[{"id": 123, "fields": {"Status": "Done"}}]'

# List tasks with filter (v3 supports quoted where values)
curl -X GET "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${NOCODB_TASKS_TABLE_ID}/records?where=(Status,eq,\"Done\")&limit=50" \
  -H "xc-token: ${NOCODB_API_TOKEN}"
```

---

## Tier 2: Enable MCP for Complex Operations

For batch operations requiring:
- Bulk updates (10+ records)
- Complex queries with pagination
- Sprint management
- Dependency tracking

### Enable MCP Temporarily

```bash
# Add NocoDB MCP to current session
claude mcp add nocodb-base-ops -- pnpm dlx mcp-remote "${NOCODB_URL}/mcp/ncmvk15tvewrerlg" --header "xc-mcp-token: ${NOCODB_MCP_TOKEN}"

# After task, remove to restore token savings
claude mcp remove nocodb-base-ops
```

### MCP Constraints (Critical!)

- **Response Token Limit**: 25,000 tokens max
- **Batch Update Limit**: 10 records per call
- **Always use `fields` parameter** to reduce response size

---

## Agent Accountability Pattern

When agents work on tasks, they should:

1. **Log start of work** - Create or update task to "In Progress"
2. **Update description** - Add progress notes and checkbox items
3. **Mark completion** - Update status to "Done" when finished

This provides human-in-the-loop visibility into agent activities without creating excessive task overhead.

```bash
# Agent starting work
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "In Progress"

# Agent logging progress (update description)
# Use curl to update Description field with progress notes

# Agent completing work
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "Done"
```

---

## Helper Scripts

Located in `.claude/skills/nocodb-tasks/scripts/`:

| Script | Usage |
|--------|-------|
| `create-task.sh` | `./create-task.sh "Title" "Status" "Priority"` |
| `update-status.sh` | `./update-status.sh <task_id> "New Status"` |
| `list-tasks.sh` | `./list-tasks.sh [optional_status]` |

---

## Related Resources

- **Hooks**: `nocodb-create-task.sh`, `nocodb-update-status.sh`
- **Config**: Environment variables in `.env`
- **CLAUDE.md**: NocoDB MCP constraints section
- **API Docs**: https://ops.aienablement.academy/api/v2/meta/bases/pz7wdven8yqgx3r/swagger
