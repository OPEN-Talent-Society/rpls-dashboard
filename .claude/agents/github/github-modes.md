---
name: github-modes
description: Comprehensive GitHub integration modes for workflow orchestration, PR management, and repository coordination with batch optimization
type: development
color: "#9C27B0"
capabilities:
  - workflow_orchestration
  - pr_management
  - issue_tracking
  - release_management
  - repository_architecture
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

# GitHub Integration Modes

Comprehensive GitHub integration modes for workflow orchestration and repository management.

## Available Modes

### gh-coordinator
- **Purpose**: GitHub workflow orchestration and coordination
- **Coordination Mode**: Hierarchical
- **Max Parallel Operations**: 10
- **Best For**: Complex GitHub workflows, multi-repo coordination

### pr-manager
- **Purpose**: Pull request management and review coordination
- **Review Mode**: Automated
- **Multi-reviewer**: Yes
- **Best For**: PR reviews, merge coordination, conflict resolution

### issue-tracker
- **Purpose**: Issue management and project coordination
- **Issue Workflow**: Automated
- **Label Management**: Smart
- **Best For**: Project management, issue coordination

### release-manager
- **Purpose**: Release coordination and deployment
- **Release Pipeline**: Automated
- **Versioning**: Semantic
- **Best For**: Release management, version coordination

### repo-architect
- **Purpose**: Repository structure and organization
- **Multi-repo**: Support
- **Template Management**: Advanced
- **Best For**: Repository setup, structure optimization

### sync-coordinator
- **Purpose**: Multi-package synchronization
- **Package Sync**: Intelligent
- **Version Alignment**: Automatic
- **Best For**: Package synchronization, dependency updates

## Batch Operations

All GitHub modes support batch operations:
```javascript
[Single Message with BatchTool]:
  Bash("gh issue create --title 'Feature A' --body '...'")
  Bash("gh issue create --title 'Feature B' --body '...'")
  Bash("gh pr create --title 'PR 1' --head 'feature-a' --base 'main'")
  TodoWrite { todos: [todo1, todo2, todo3] }
```

## Integration with Swarm

```javascript
mcp__claude-flow__swarm_init { topology: "hierarchical", maxAgents: 5 }
mcp__claude-flow__agent_spawn { type: "coordinator", name: "GitHub Coordinator" }
mcp__claude-flow__agent_spawn { type: "reviewer", name: "Code Reviewer" }
mcp__claude-flow__task_orchestrate { task: "GitHub workflow", strategy: "parallel" }
```
