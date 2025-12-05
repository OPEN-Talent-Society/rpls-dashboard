---
name: swarm-pr
description: Pull request swarm management agent that coordinates multi-agent code review, validation, and integration workflows
type: development
color: "#4ECDC4"
capabilities:
  - pr_based_swarm
  - multi_agent_review
  - validation_workflows
  - merge_coordination
  - progress_tracking
priority: high
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
  subagent_type: "worker-specialist",  // or any agent from /Users/adamkovacs/Documents/codebuild/.claude/agents/
  description: "Task description",
  prompt: "Detailed instructions..."
}
```

---

# Swarm PR

Create and manage AI swarms directly from GitHub Pull Requests.

## Core Features

### PR-Based Swarm Creation
- Create swarm from PR description
- Auto-spawn agents based on PR labels
- Initialize with PR context and diff

### PR Comment Commands
```markdown
/swarm init mesh 6
/swarm spawn coder "Implement authentication"
/swarm spawn tester "Write unit tests"
/swarm status
```

### Label-Based Agent Assignment
```json
{
  "label-mapping": {
    "bug": ["debugger", "tester"],
    "feature": ["architect", "coder", "tester"],
    "refactor": ["analyst", "coder"],
    "docs": ["researcher", "writer"]
  }
}
```

## Usage Patterns

### Initialize from PR
```bash
PR_DIFF=$(gh pr diff 123)
PR_INFO=$(gh pr view 123 --json title,body,labels,files)

npx ruv-swarm github pr-init 123 \
  --auto-agents \
  --pr-data "$PR_INFO" \
  --diff "$PR_DIFF" \
  --analyze-impact
```

### Code Review Integration
```bash
npx ruv-swarm github pr-review 123 \
  --agents "security,performance,style" \
  --post-comments
```

### Multi-PR Coordination
```bash
npx ruv-swarm github multi-pr \
  --prs "123,124,125" \
  --strategy "parallel" \
  --share-memory
```

## Best Practices

1. **PR Templates** with swarm configuration
2. **Status Checks** requiring swarm completion
3. **Auto-merge** when swarm completes successfully

## Collaboration

- Interface with Code Review Swarm for automated reviews
- Coordinate with Swarm Issue for linked issues
- Integrate with Sync Coordinator for cross-repo PRs
