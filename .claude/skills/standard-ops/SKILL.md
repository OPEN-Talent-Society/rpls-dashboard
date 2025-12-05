---
name: standard-ops
description: Standard Operating Procedures for all Claude agents. Enforces consistent behavior for task tracking (NocoDB), knowledge management (Cortex/SiYuan), cross-session memory (AgentDB, RuVector, Synapse), and multi-agent coordination. Use this skill at the start of every session and for every significant task to ensure proper logging, documentation, and memory persistence.
status: active
owner: platform
last_reviewed_at: 2025-11-30
tags:
  - sop
  - operations
  - integration
  - memory
  - coordination
dependencies: []
outputs:
  - task-log
  - knowledge-doc
  - memory-entry
---

# Standard Operations Skill

This skill defines the **mandatory operating procedures** for all Claude agents. These behaviors must be followed to ensure:
- Accountability and audit trails
- Cross-session memory
- Multi-agent coordination
- Organizational knowledge capture

## When to Use This Skill

**ALWAYS** - These procedures apply to all significant work:
- Starting a new session
- Beginning any task
- Making decisions
- Discovering new information
- Completing work
- Ending a session

## Mandatory Behaviors

### 1. Session Start
When starting a new session:
```
1. Load session context: memory_search for relevant past work
2. Check Synapse coordination state
3. Review last session summary
4. Announce presence to Synapse
```

### 2. Task Start
Before beginning any significant task:
```
1. Create task in NocoDB
   - Assign to correct agent email
   - Set appropriate priority
   - Link to current sprint
   - Add relevant tags

2. Create planning doc in Cortex
   - Use Projects notebook
   - Include YAML frontmatter
   - Link to NocoDB task ID

3. Load relevant memory
   - Search AgentDB for similar past work
   - Search RuVector for knowledge
   - Check if others are working on related tasks
```

### 3. During Task
While working on a task:
```
1. Log significant actions
   - Decisions made and rationale
   - Findings discovered
   - Learnings captured

2. Update documentation
   - Append to Cortex planning doc
   - Use blocks for referenceable content
   - Add backlinks to related docs

3. Store to memory
   - Key decisions in AgentDB
   - New knowledge to RuVector
   - Status updates to Synapse
```

### 4. Task Complete
Upon completing a task:
```
1. Update NocoDB
   - Status to "Done"
   - Add completion notes
   - Record time if tracked

2. Finalize Cortex doc
   - Add summary section
   - Extract learnings to Resources
   - Add completion metadata

3. Persist memory
   - Store learnings in AgentDB
   - Index to RuVector
   - Release task in Synapse
```

### 5. Session End
Before ending a session:
```
1. Update all in-progress tasks
   - Status reflects current state
   - Notes include stopping point

2. Create session summary
   - What was accomplished
   - What's remaining
   - Key decisions made

3. Persist to memory
   - Session summary to AgentDB
   - Sync all to Synapse
   - Export metrics
```

## Agent Identity

Each Claude variant has a unique identity:

| Variant | Email | Role |
|---------|-------|------|
| claude-code | claude-code@aienablement.academy | Developer |
| claude-flow | claude-flow@aienablement.academy | Orchestrator |
| claude-zai | claude-zai@aienablement.academy | Intelligence |
| claude-zai-flow | claude-zai-flow@aienablement.academy | Hybrid |
| agent-flow | agent-flow@aienablement.academy | Multi-Agent |

## Integration Points

### NocoDB (Task Tracking)
- Base: `pz7wdven8yqgx3r`
- Tasks Table: `mmx3z4zxdj9ysfk`
- Sprints Table: `mtkfphwlmiv8mzp`
- **Always limit fields in queries** (25k token limit)
- **Max 10 records per update**

### Cortex (Knowledge)
- Use full SiYuan features
- YAML frontmatter required
- Tags and backlinks mandatory
- Block-level metadata
- Custom attributes for queries

### AgentDB (Memory)
- Namespace: `learnings/`, `context/`, `decisions/`
- Hierarchical keys
- Include timestamp and agent
- Set appropriate TTL

### RuVector (Knowledge Vectors)
- Index at time of learning
- Rich metadata for filtering
- Consistent tagging

### Synapse (Coordination)
- Announce on session start
- Claim tasks before starting
- Update frequently
- Release when done

## Templates

Use templates from `/Users/adamkovacs/Documents/codebuild/.claude/templates/` for consistency:
- `task-nocodb.json` - NocoDB task creation
- `doc-cortex-task.md` - Cortex task documentation
- `doc-cortex-learning.md` - Cortex learning capture
- `memory-entry.json` - AgentDB memory entry

## Hooks

Use hooks from `/Users/adamkovacs/Documents/codebuild/.claude/hooks/` for automation:
- `session-start.sh` - Initialize session
- `pre-task.sh` - Prepare for task
- `log-action.sh` - Log individual actions
- `post-task.sh` - Complete task logging
- `session-end.sh` - Persist session

## Quick Reference Commands

```bash
# Start session
source /Users/adamkovacs/Documents/codebuild/.claude/hooks/session-start.sh

# Create task
/Users/adamkovacs/Documents/codebuild/.claude/hooks/nocodb-create-task.sh "Task Name" "Description" "P2" "tag1,tag2"

# Log learning
/Users/adamkovacs/Documents/codebuild/.claude/hooks/cortex-log-learning.sh "Topic" "Context" "Discovery" "Insights" "category"

# Store memory
/Users/adamkovacs/Documents/codebuild/.claude/hooks/memory-store.sh "namespace" "key" "value"

# End session
source /Users/adamkovacs/Documents/codebuild/.claude/hooks/session-end.sh
```

## Enforcement

These procedures are **not optional**. Failure to follow them results in:
- Lost organizational knowledge
- Poor multi-agent coordination
- Missing audit trails
- Reduced effectiveness

Every agent is accountable for maintaining these standards.

---

*Standard Operations v1.0 - AI Enablement Academy*
