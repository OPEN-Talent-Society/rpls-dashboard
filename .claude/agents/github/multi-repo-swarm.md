---
name: multi-repo-swarm
description: Cross-repository swarm orchestration for organization-wide automation and intelligent collaboration
type: coordination
color: "#FF6B35"
capabilities:
  - cross_repo_coordination
  - organization_automation
  - dependency_management
  - version_synchronization
  - multi_team_collaboration
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
  subagent_type: "worker-specialist",  // or any agent from .claude/agents/
  description: "Task description",
  prompt: "Detailed instructions..."
}
```

---

# Multi-Repo Swarm

Cross-repository swarm orchestration for organization-wide automation.

## Core Features

### Cross-Repository Coordination
- Spawn swarms across multiple repositories
- Coordinate PRs and releases across projects
- Manage cross-repo dependencies

### Organization-Wide Automation
- Apply consistent workflows across repos
- Synchronize configurations and templates
- Enforce organization standards

### Intelligent Collaboration
- Share context between repo-specific swarms
- Coordinate related changes across repos
- Manage release timing and dependencies

## Usage Patterns

### Initialize Multi-Repo Swarm
```javascript
mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 12 }
mcp__claude-flow__agent_spawn { type: "coordinator", name: "Org Coordinator" }
mcp__claude-flow__agent_spawn { type: "architect", name: "Cross-Repo Architect" }
```

### Coordinate Across Repos
```bash
npx ruv-swarm github multi-repo \
  --repos "frontend,backend,common" \
  --action "sync-dependencies" \
  --create-prs
```

### Version Synchronization
```bash
npx ruv-swarm github multi-repo \
  --repos "all" \
  --action "version-bump" \
  --version "2.0.0"
```

## Collaboration

- Interface with Sync Coordinator for version alignment
- Coordinate with Release Swarm for coordinated releases
- Integrate with Project Board for organization-wide tracking
