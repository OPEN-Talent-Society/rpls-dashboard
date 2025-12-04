# NocoDB & Cortex Protocols

> Complete reference for NocoDB project planning and Cortex knowledge management.
> These are MANDATORY systems - all work must be tracked here.

---

## TL;DR - Business Task Tracking

**NocoDB** = High-level business task tracking (client deliverables, milestones, sprints)
**Cortex** = Knowledge management (documentation, learnings, PARA methodology)

**NocoDB Config**: Database `pz7wdven8yqgx3r` | Tasks `mmx3z4zxdj9ysfk` | Sprints `mtkfphwlmiv8mzp`

**Mandatory Fields**:
- Assignee: `claude-code@aienablement.academy` (ID: `uskfxdybo8kofowf`)
- Sprint: Link via `SPRINTS_id` based on due date
- Dependencies: `{"Dependencies": [141, 142]}`

**MCP Limits**: 25K tokens max response | 10 records max per update batch

**Cortex URL**: https://cortex.aienablement.academy (use CORTEX_TOKEN from .env)

---

## NocoDB Project Planning

**NocoDB is the UNIVERSAL platform for ALL project planning.**

### Database Configuration
- **Database**: `pz7wdven8yqgx3r`
- **Table**: `TASKS` (`mmx3z4zxdj9ysfk`)
- **Sprints**: `SPRINTS` (`mtkfphwlmiv8mzp`)

### Mandatory Assignee
ALL tasks MUST be assigned to `claude-code@aienablement.academy`:
- User ID: `uskfxdybo8kofowf`
- Format: `{"Assignee": [{"id": "uskfxdybo8kofowf", "email": "claude-code@aienablement.academy"}]}`

### Mandatory Sprint Assignment
ALL tasks MUST be assigned to a sprint based on due date:
- Use `SPRINTS_id` field (foreign key) to link tasks to sprints
- Match task due date to sprint Start Date/End Date range
- Tasks without due dates -> Assign to current active sprint
- Query SPRINTS table: `(Status,eq,Active)`
- Format: `{"SPRINTS_id": <sprint_id>}`

### Mandatory Dependencies Tracking
Link related tasks using Dependencies field:
- Use `Dependencies` field (Links type)
- Format: `{"Dependencies": [141, 142]}`
- Track: Plan -> Build -> Test -> Deploy relationships

### Status Maintenance
Keep task statuses current:
- To Do -> In Progress -> Review/QA -> Done
- Use "Backlog" for duplicate/deprioritized tasks
- Use "Blocked" for external dependencies

---

## NocoDB MCP Constraints

### Response Token Limit: 25,000 Tokens
- `queryRecords` responses cannot exceed 25,000 tokens
- **Solution**: Use pagination, filtering, or limit response fields
- **Example**: `{"fields": ["Id", "task name", "Status"]}`
- **Pagination**: Use `page` and `pageSize` (default: 50, max: 100)

### Batch Update Limit: 10 Records Maximum
- `updateRecords` can only update **10 records per call**
- **Solution**: Split large updates into batches of 10 or fewer

### Recommended Patterns

```javascript
// CORRECT: Query with field limits
mcp__nocodb-base-ops__queryRecords({
  tableId: "mmx3z4zxdj9ysfk",
  fields: ["Id", "task name", "Status", "Priority"],
  pageSize: 50
})

// CORRECT: Batch updates (max 10 records)
mcp__nocodb-base-ops__updateRecords({
  tableId: "mmx3z4zxdj9ysfk",
  records: [
    {"id": 135, "fields": {"Status": "Done"}},
    // ... up to 10 records total
  ]
})

// WRONG: Query all fields (exceeds token limit)
mcp__nocodb-base-ops__queryRecords({
  tableId: "mmx3z4zxdj9ysfk",
  where: "(Assignee,like,%claude-code%)",
  pageSize: 100
})

// WRONG: Update more than 10 records
mcp__nocodb-base-ops__updateRecords({
  tableId: "mmx3z4zxdj9ysfk",
  records: [/* 15 records */]  // Will fail!
})
```

### Pro Tips
1. Use agents for large batch operations
2. Count before querying with `countRecords`
3. Always specify `fields` parameter
4. Verify batches before proceeding
5. Document successful patterns in Cortex

---

## Cortex Knowledge Management

**Cortex is the SINGLE source of truth for ALL knowledge and documentation.**

### Access
- URL: https://cortex.aienablement.academy
- API: Use `CORTEX_TOKEN` from `.env` + Cloudflare credentials

### Notebooks Structure (PARA Methodology)
- **Projects** (`20231114112233-projects`): Active project work
- **Areas** (`20231114112234-areas`): Ongoing responsibilities
- **Resources** (`20231114112235-resources`): Reference materials and learnings
- **Archives** (`20231114112236-archives`): Completed work (>30 days)

### MCP Tools
- `mcp__cortex__siyuan_create_doc` - Create documents
- `mcp__cortex__siyuan_set_block_attrs` - Tag with metadata
- `mcp__cortex__siyuan_sql_query` - Query knowledge base
- `mcp__cortex__siyuan_list_notebooks` - List notebooks

---

## Cortex Operations Agent

Use the `cortex-ops` agent to automate knowledge capture:
- **Agent**: `.claude/agents/cortex-ops.md`
- **Skill**: `.claude/skills/cortex-task-log.md`

### Task Logging
```
user: "Log task #226 to Cortex"

cortex-ops agent:
- Queries task from NocoDB
- Creates document in appropriate notebook
- Tags with metadata (priority, sprint, tags)
- Links back to NocoDB
```

### Batch Task Logging
```
user: "Log all tasks completed today to Cortex"

cortex-ops agent:
- Queries NocoDB: Status=Done, UpdatedAt=today
- Creates documents for each task (batched)
- Tags and links all tasks
```

---

## Task Document Template

```markdown
# Task: [Task Name]

**Status**: Done
**Priority**: [P1/P2/P3]
**Sprint**: [Sprint Name]
**NocoDB ID**: [ID]

## Description
[What was done]

## Implementation
[Technical details]

## Key Learnings
[Insights captured]

## Related Tasks
[[Task-XXX]]
```

---

## Knowledge Management Slash Commands

### Task Workflow Commands (Integrated NocoDB + Cortex)
- `/task-start` - Create task in NocoDB + planning document in Cortex
- `/task-update` - Update progress (NocoDB) + log learnings (Cortex)
- `/task-complete` - Mark done (NocoDB) + archive knowledge (Cortex)

### NocoDB Commands
- `/nocodb-create` - Create simple task without Cortex (for <30 min work)
- `/nocodb-status` - Quick status updates
- `/nocodb-sprint` - Sprint management and reporting

### Cortex Commands
- `/cortex-log` - Create standalone documentation
- `/cortex-search` - Search knowledge base

---

## Hook System Architecture

### Pre-Task Hooks (Task Creation)
- `pre-task-nocodb.sh` - Create task with dependencies and sprint assignment
- `pre-task-cortex.sh` - Create detailed planning document

### In-Task Hooks (During Work)
- `in-task-nocodb.sh` - Update progress and status
- `in-task-cortex.sh` - Capture findings, learnings, decisions, blockers

### Post-Task Hooks (Completion)
- `post-task-status-update.sh` - Mark task as Done
- `post-task-cortex-log.sh` - Extract learnings and create completion doc

---

## Finding Types in Cortex

- `learning` - New knowledge or discoveries
- `decision` - Architectural or implementation decisions
- `blocker` - Issues preventing progress
- `tool` - New tools, patterns, or utilities created
- `finding` - General observations

---

## Universal Workflow Protocol

1. **Plan**: Create tasks in NocoDB first
2. **Execute**: Do the work using Claude Code capabilities
3. **Document**: Store ALL knowledge in Cortex
4. **Link**: Connect NocoDB tasks to Cortex documents
5. **Repeat**: No work happens outside this system

---

## Critical Rules

- NEVER store knowledge in local files only
- NEVER do work without logging it in NocoDB
- NEVER create documentation without putting it in Cortex
- ALWAYS use Cortex API for knowledge storage
- ALWAYS use NocoDB for project management
- ALWAYS link tasks to knowledge documents
