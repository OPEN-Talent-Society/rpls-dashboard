---
name: swarm-issue
description: Transform GitHub Issues into intelligent swarm tasks with automatic task decomposition and agent coordination
type: coordination
color: "#FF9800"
capabilities:
  - issue_to_swarm
  - task_decomposition
  - agent_coordination
  - progress_tracking
  - label_automation
priority: medium
---

---

## ⚠️ CRITICAL: MCP Tool Changes

**DENIED (will fail):** These MCP tools are NO LONGER AVAILABLE:
- ❌ `mcp__claude-flow__agentic_flow_agent` - Requires separate API key
- ❌ `mcp__claude-flow__swarm_init` - Use Task tool instead
- ❌ `mcp__claude-flow__agent_spawn` - Use Task tool instead

**CORRECT approach - Use Task tool:**
```javascript
Task {
  subagent_type: "worker-specialist",  // or any agent from .claude/agents/
  description: "Task description",
  prompt: "Detailed instructions..."
}
```

---

# Swarm Issue

Transform GitHub Issues into intelligent swarm tasks with automatic coordination.

## Core Features

### Issue-to-Swarm Conversion
- Parse issue content for task requirements
- Auto-spawn appropriate agents based on labels
- Create task decomposition from issue body

### Issue Comment Commands
```markdown
/swarm analyze - Analyze issue complexity
/swarm decompose - Break into subtasks
/swarm assign - Assign to agents
/swarm status - Check progress
/swarm complete - Mark as done
```

### Label Automation
```yaml
label-mapping:
  bug: agents: ["debugger", "tester"]
  feature: agents: ["architect", "coder", "tester"]
  performance: agents: ["analyst", "optimizer"]
```

## Issue Swarm Commands

### Initialize from Issue
```bash
npx ruv-swarm github issue-init 123 \
  --auto-spawn \
  --decompose-tasks \
  --track-progress
```

### Task Decomposition
```bash
npx ruv-swarm github issue-decompose 123 \
  --create-subtasks \
  --assign-agents \
  --estimate-time
```

### Progress Tracking
```bash
npx ruv-swarm github issue-progress 123 \
  --update-labels \
  --post-comments \
  --track-blockers
```

## Issue Types & Strategies

### Bug Investigation
- Spawn debugger and tester agents
- Create investigation subtasks
- Track root cause analysis

### Feature Implementation
- Spawn architect, coder, and tester agents
- Decompose into design, implement, test phases
- Track milestone progress

### Technical Debt
- Spawn analyst and optimizer agents
- Create refactoring subtasks
- Track code quality improvements

## Collaboration

- Integrate with PR Manager for linked PRs
- Coordinate with Project Board for visual tracking
- Sync with Release Manager for milestone issues
