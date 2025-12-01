# Comprehensive Tool Reference for Claude Agents

This document provides deep understanding of all tools, their purposes, usage patterns, templates, SOPs, and best practices.

---

## Table of Contents

1. [NocoDB - Task Tracking](#nocodb)
2. [Cortex/SiYuan - Knowledge Management](#cortex-siyuan)
3. [AgentDB - Agent Memory](#agentdb)
4. [RuVector - Vector Knowledge Base](#ruvector)
5. [Synapse - Multi-Agent Coordination](#synapse)
6. [Claude Flow - Swarm Orchestration](#claude-flow)

---

## NocoDB - Task Tracking {#nocodb}

### What It Is
NocoDB is an open-source Airtable alternative that serves as our **universal task tracking and project management platform**. It provides a structured database for all work items, sprints, and organizational tasks.

### Why We Use It
1. **Accountability** - Every piece of work is tracked and assigned
2. **Visibility** - Humans and agents can see what everyone is working on
3. **Audit Trail** - Complete history of all work performed
4. **Sprint Management** - Organize work into time-boxed iterations
5. **Cross-Agent Coordination** - Agents know what others are doing/have done
6. **Dependencies** - Track which tasks block or depend on others

### How We Use It

**MCP Server**: `nocodb-base-ops`

**Key Tables**:
- `TASKS` (mmx3z4zxdj9ysfk) - All work items
- `SPRINTS` (mtkfphwlmiv8mzp) - Sprint definitions

**Key Operations**:
```javascript
// Create a task
mcp__nocodb-base-ops__createRecords({
  tableId: "mmx3z4zxdj9ysfk",
  records: [{
    fields: {
      "task name": "Task title",
      "Description": "Detailed description",
      "Status": "To Do",  // To Do, In Progress, Review/QA, Done, Blocked, Backlog
      "Priority": "P2",   // P1 (Critical), P2 (High), P3 (Medium), P4 (Low)
      "Assignee": [{"id": "uskfxdybo8kofowf", "email": "agent@email"}],
      "SPRINTS_id": 1,    // Link to sprint
      "Tags": "tag1, tag2"
    }
  }]
})

// Query tasks
mcp__nocodb-base-ops__queryRecords({
  tableId: "mmx3z4zxdj9ysfk",
  fields: ["Id", "task name", "Status", "Priority"],  // ALWAYS limit fields!
  where: "(Status,eq,In Progress)",
  pageSize: 50
})

// Update task
mcp__nocodb-base-ops__updateRecords({
  tableId: "mmx3z4zxdj9ysfk",
  records: [{"id": 123, "fields": {"Status": "Done"}}]
})
```

### Critical Constraints
1. **Max 25,000 tokens** in query response - always specify `fields` parameter
2. **Max 10 records** per update - batch large updates
3. **Always assign** tasks to the appropriate agent email
4. **Always link** to active sprint

### Template: Task Creation
```json
{
  "task name": "[Category] Task Title",
  "Description": "## Objective\n\n## Acceptance Criteria\n\n## Notes",
  "Status": "To Do",
  "Priority": "P2",
  "Assignee": [{"id": "{{AGENT_USER_ID}}", "email": "{{AGENT_EMAIL}}"}],
  "SPRINTS_id": "{{CURRENT_SPRINT_ID}}",
  "Tags": "automated, {{CATEGORY}}"
}
```

### SOP: Task Lifecycle
1. **Create** - Log task before starting work
2. **Start** - Update status to "In Progress"
3. **Document** - Link to Cortex docs if needed
4. **Complete** - Update status to "Done" immediately
5. **Never batch** - Update status as you go, not at the end

### Best Practices
- Use descriptive task names with category prefix: `[Dev] Fix auth bug`
- Always include acceptance criteria in description
- Link related tasks using Dependencies field
- Update status in real-time, not after the fact
- Use Tags for categorization and searchability

---

## Cortex/SiYuan - Knowledge Management {#cortex-siyuan}

### What It Is
Cortex (powered by SiYuan) is our **knowledge management system**. It's a block-based note-taking platform with powerful features for linking, tagging, and organizing information.

### Why We Use It
1. **Institutional Memory** - Capture all learnings for future reference
2. **Cross-Session Context** - Information persists beyond single sessions
3. **Human-Agent Knowledge Sharing** - Both humans and agents contribute
4. **Semantic Organization** - Tags, backlinks, and blocks enable rich connections
5. **PARA Methodology** - Organized into Projects, Areas, Resources, Archives

### How We Use It

**MCP Server**: `cortex`

**Notebooks (PARA)**:
- `projects` (20231114112233) - Active project documentation
- `areas` (20231114112234) - Ongoing responsibilities
- `resources` (20231114112235) - Reference materials, learnings
- `archives` (20231114112236) - Completed work (>30 days old)
- `agent_logs` (20231114112237) - Automated agent activity logs

**Key Operations**:
```javascript
// Create document
mcp__cortex__siyuan_create_doc({
  notebook: "20231114112235-resources",
  path: "Learnings/2024-11/technical-discovery",
  markdown: "# Title\n\nContent with [[backlinks]] and #tags"
})

// Set block attributes (metadata)
mcp__cortex__siyuan_set_block_attrs({
  id: "block-id",
  attrs: {
    "custom-status": "active",
    "custom-priority": "high",
    "custom-agent": "claude-code",
    "custom-nocodb-task": "123"
  }
})

// Append content
mcp__cortex__siyuan_append_block({
  id: "parent-block-id",
  data: "## New Section\n\nContent here",
  dataType: "markdown"
})

// SQL Query (powerful!)
mcp__cortex__siyuan_sql_query({
  stmt: "SELECT * FROM blocks WHERE content LIKE '%learning%' LIMIT 10"
})

// Export as markdown
mcp__cortex__siyuan_export_markdown({ id: "doc-id" })
```

### SiYuan Feature Usage

**Block References**: `((block-id))` - Reference any block inline
**Block Embedding**: `{{block-id}}` - Embed block content
**Tags**: `#tag-name` - Categorical organization
**Backlinks**: `[[Document Name]]` - Link to other documents
**Forward Links**: Automatic from backlinks
**Templates**: Use template syntax for consistency

**Attributes (Custom Metadata)**:
```markdown
{: custom-status="active" custom-priority="high" custom-agent="claude-code" }
```

**YAML Frontmatter**:
```yaml
---
title: Document Title
created: 2024-11-30
agent: claude-code
task_id: 123
tags: [learning, technical]
---
```

### Template: Learning Document
```markdown
---
title: Learning - {{TOPIC}}
created: {{DATE}}
agent: {{AGENT}}
type: learning
tags: [learning, {{CATEGORY}}]
---

# {{TOPIC}}

## Context
What prompted this learning?

## Discovery
What was learned?

## Implementation
How was it applied?

## Key Insights
- Insight 1
- Insight 2

## Related
- [[Related Doc 1]]
- [[Related Doc 2]]

## Tags
#learning #{{CATEGORY}} #{{AGENT}}

---
*Logged by {{AGENT}} on {{DATE}}*
{: custom-agent="{{AGENT}}" custom-type="learning" }
```

### Template: Task Log Document
```markdown
---
title: Task - {{TASK_NAME}}
created: {{DATE}}
agent: {{AGENT}}
nocodb_id: {{TASK_ID}}
status: {{STATUS}}
---

# {{TASK_NAME}}

## Objective
{{DESCRIPTION}}

## Work Performed
### Actions
1. Action 1
2. Action 2

### Decisions Made
- Decision 1: Rationale
- Decision 2: Rationale

### Files Changed
- `path/to/file.ts` - Description

## Findings
- Finding 1
- Finding 2

## Learnings
- [[Learning-Topic-1]]
- [[Learning-Topic-2]]

## Status
{{STATUS}} - {{SUMMARY}}

---
NocoDB Task: #{{TASK_ID}}
Agent: {{AGENT}}
{: custom-nocodb-task="{{TASK_ID}}" custom-status="{{STATUS}}" }
```

### SOP: Documentation Workflow
1. **Start Task** → Create planning doc in Projects notebook
2. **During Work** → Append findings, decisions, learnings
3. **Complete Task** → Update status, add summary
4. **Extract Learnings** → Create separate learning docs in Resources
5. **Archive** → Move to Archives after 30 days

### Best Practices
- **Use blocks** - Break content into referenceable blocks
- **Always tag** - Every doc should have relevant tags
- **Backlink liberally** - Connect related concepts
- **Custom attributes** - Add metadata for queries
- **SQL queries** - Use for dashboards and reports
- **Templates** - Maintain consistency
- **Daily logs** - Create daily agent activity summaries

---

## AgentDB - Agent Memory {#agentdb}

### What It Is
AgentDB is a **vector-enabled database for agent memory and learning storage**. It provides persistent memory that survives across sessions.

### Why We Use It
1. **Cross-Session Memory** - Remember context between conversations
2. **Learning Persistence** - Store and retrieve past learnings
3. **Pattern Recognition** - Find similar past experiences
4. **Agent Coordination** - Share memory between agents
5. **Semantic Search** - Find relevant memories by meaning

### How We Use It

**Key Patterns**:
```javascript
// Store a memory
mcp__claude-flow__memory_usage({
  action: "store",
  namespace: "learnings",
  key: "topic/subtopic/specific",
  value: JSON.stringify({
    content: "What was learned",
    context: "When/why it was learned",
    agent: "claude-code",
    timestamp: "2024-11-30T12:00:00Z"
  }),
  ttl: 2592000  // 30 days
})

// Retrieve a memory
mcp__claude-flow__memory_usage({
  action: "retrieve",
  namespace: "learnings",
  key: "topic/subtopic/specific"
})

// Search memories
mcp__claude-flow__memory_search({
  pattern: "topic/*",
  namespace: "learnings",
  limit: 10
})
```

### Namespace Convention
- `session/` - Current session state
- `learnings/` - Persistent learnings
- `context/` - Project/task context
- `decisions/` - Architectural decisions
- `patterns/` - Recognized patterns
- `errors/` - Error resolutions

### Template: Memory Entry
```json
{
  "type": "learning|decision|context|pattern|error",
  "content": "The actual content",
  "context": "Why/when this was captured",
  "agent": "claude-code",
  "session_id": "session-123",
  "timestamp": "2024-11-30T12:00:00Z",
  "related": ["key1", "key2"],
  "tags": ["tag1", "tag2"]
}
```

### SOP: Memory Management
1. **Session Start** → Load relevant memories from namespaces
2. **During Work** → Store significant learnings immediately
3. **Decision Made** → Store with rationale
4. **Error Resolved** → Store resolution pattern
5. **Session End** → Persist session summary

### Best Practices
- Use hierarchical keys: `domain/topic/specific`
- Always include timestamp and agent
- Link related memories
- Set appropriate TTL (default 30 days)
- Search before storing to avoid duplicates

---

## RuVector - Vector Knowledge Base {#ruvector}

### What It Is
RuVector is a **semantic vector knowledge base** for intelligent information retrieval based on meaning, not just keywords.

### Why We Use It
1. **Semantic Search** - Find relevant info by meaning
2. **Knowledge Graphs** - Understand relationships
3. **Similarity Matching** - Find related past work
4. **Context Retrieval** - Get relevant context for tasks
5. **Pattern Discovery** - Identify recurring themes

### How We Use It

**Key Operations**:
```javascript
// Index knowledge
mcp__ruv-swarm__neural_train({
  pattern_type: "prediction",
  training_data: JSON.stringify({
    content: "The knowledge to index",
    metadata: { source: "cortex", type: "learning" }
  })
})

// Search knowledge
mcp__ruv-swarm__neural_patterns({
  action: "analyze",
  operation: "search",
  metadata: { query: "search query" }
})
```

### Template: Knowledge Entry
```json
{
  "content": "The content to vectorize",
  "metadata": {
    "source": "cortex|session|external",
    "type": "learning|decision|pattern|reference",
    "agent": "claude-code",
    "timestamp": "2024-11-30T12:00:00Z",
    "tags": ["tag1", "tag2"]
  }
}
```

### SOP: Knowledge Indexing
1. **New Learning** → Index to RuVector immediately
2. **Document Created** → Index key content
3. **Pattern Found** → Index for future matching
4. **Before Task** → Search for relevant past knowledge

### Best Practices
- Index at time of learning (freshness)
- Include rich metadata for filtering
- Use consistent tagging
- Regular knowledge graph updates

---

## Synapse - Multi-Agent Coordination {#synapse}

### What It Is
Synapse is the **coordination layer for multi-agent systems**. It manages state, communication, and synchronization between Claude agents.

### Why We Use It
1. **State Sharing** - Agents know what others are doing
2. **Conflict Prevention** - Avoid duplicate work
3. **Handoff Support** - Smooth transitions between agents
4. **Collective Intelligence** - Aggregate insights
5. **Workflow Coordination** - Complex multi-step processes

### How We Use It

**Key Operations**:
```javascript
// Sync coordination state
mcp__claude-flow__coordination_sync({
  swarmId: "current-swarm"
})

// Update agent status
mcp__claude-flow__agent_metrics({
  agentId: "claude-code"
})

// Broadcast to other agents
mcp__claude-flow__daa_communication({
  from: "claude-code",
  to: "claude-flow",
  message: { type: "update", content: "Status update" }
})
```

### Template: Coordination Message
```json
{
  "type": "status|handoff|query|response",
  "from": "claude-code",
  "to": "claude-flow|all",
  "content": {
    "action": "completed|started|blocked|query",
    "task": "task-name",
    "details": "Additional context"
  },
  "timestamp": "2024-11-30T12:00:00Z"
}
```

### SOP: Agent Coordination
1. **Session Start** → Announce presence to Synapse
2. **Task Start** → Claim task to prevent conflicts
3. **Significant Progress** → Broadcast updates
4. **Blocked** → Request assistance
5. **Complete** → Release task, share learnings

### Best Practices
- Claim before starting
- Update frequently
- Release when done
- Share learnings
- Respond to queries from other agents

---

## Claude Flow - Swarm Orchestration {#claude-flow}

### What It Is
Claude Flow is the **swarm intelligence orchestration platform**. It enables multi-agent coordination, parallel execution, and intelligent task distribution.

### Why We Use It
1. **Parallel Execution** - Multiple agents working simultaneously
2. **Intelligent Routing** - Right agent for right task
3. **Load Balancing** - Distribute work efficiently
4. **Memory Management** - Persistent swarm state
5. **Performance Optimization** - Token efficiency, speed

### How We Use It

**Key Operations**:
```javascript
// Initialize swarm
mcp__claude-flow__swarm_init({
  topology: "hierarchical",  // mesh, ring, star
  maxAgents: 8,
  strategy: "balanced"
})

// Spawn agents
mcp__claude-flow__agent_spawn({
  type: "researcher|coder|analyst|tester",
  name: "Agent Name",
  capabilities: ["capability1", "capability2"]
})

// Orchestrate task
mcp__claude-flow__task_orchestrate({
  task: "Task description",
  strategy: "parallel|sequential|adaptive",
  priority: "high"
})

// Monitor swarm
mcp__claude-flow__swarm_status({ swarmId: "current" })
```

### Topology Selection Guide
- **Hierarchical** - Complex projects with clear structure
- **Mesh** - Collaborative research, exploration
- **Ring** - Sequential pipelines
- **Star** - Centralized coordination

### SOP: Swarm Operations
1. **Assess Task** → Determine if swarm is needed
2. **Select Topology** → Based on task structure
3. **Initialize** → Create swarm with appropriate config
4. **Spawn Agents** → Create specialized agents
5. **Orchestrate** → Distribute tasks
6. **Monitor** → Track progress
7. **Cleanup** → Destroy swarm when complete

### Best Practices
- Batch all swarm operations in single message
- Use parallel execution by default
- Store coordination state in memory
- Monitor token usage
- Clean up after completion

---

## Integration Checklist

For every significant task:

- [ ] **NocoDB** - Task created and assigned
- [ ] **Cortex** - Documentation started
- [ ] **AgentDB** - Context loaded from memory
- [ ] **RuVector** - Relevant knowledge searched
- [ ] **Synapse** - Coordination state checked

After every significant task:

- [ ] **NocoDB** - Status updated to Done
- [ ] **Cortex** - Documentation completed with learnings
- [ ] **AgentDB** - Learnings stored
- [ ] **RuVector** - New knowledge indexed
- [ ] **Synapse** - State updated, task released

---

## Quick Reference: Agent Emails

| Variant | Email | User ID |
|---------|-------|---------|
| claude-code | claude-code@aienablement.academy | uskfxdybo8kofowf |
| claude-flow | claude-flow@aienablement.academy | uskflow001 |
| claude-zai | claude-zai@aienablement.academy | uskzai001 |
| claude-zai-flow | claude-zai-flow@aienablement.academy | uskzaiflow001 |
| agent-flow | agent-flow@aienablement.academy | uskagentflow001 |

---

*Last Updated: 2024-11-30*
*Maintained by: AI Enablement Academy*
