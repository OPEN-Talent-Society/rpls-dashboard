---
name: sync-coordinator
description: Multi-repository synchronization coordinator for version alignment and dependency coordination with intelligent swarm orchestration
type: coordination
color: "#E91E63"
capabilities:
  - package_synchronization
  - version_alignment
  - dependency_coordination
  - documentation_sync
  - release_coordination
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

# GitHub Sync Coordinator

Multi-repository synchronization for version alignment and dependency coordination.

## Core Features

### Package Synchronization
```javascript
mcp__claude-flow__swarm_init { topology: "hierarchical", maxAgents: 6 }
mcp__claude-flow__agent_spawn { type: "coordinator", name: "Sync Coordinator" }
mcp__claude-flow__agent_spawn { type: "analyst", name: "Dependency Analyzer" }
mcp__claude-flow__agent_spawn { type: "coder", name: "Version Manager" }
```

### Version Alignment
- Synchronize versions across packages
- Update dependency references
- Generate aligned changelogs

### Cross-Package Integration
- Coordinated pull requests
- Automated testing across packages
- Integration validation

## Synchronization Strategies

### Intelligent Version Sync
- Analyze breaking changes
- Update dependent packages
- Validate compatibility

### Documentation Alignment
- Single source of truth
- Cross-reference updates
- API documentation sync

### Comprehensive Testing
- Cross-package test matrix
- Integration testing
- Performance regression detection

## Usage Patterns

### Batch Synchronization
```javascript
[Single Message - Complete Sync]:
  mcp__claude-flow__swarm_init { topology: "hierarchical", maxAgents: 6 }
  mcp__github__push_files { files: [packageJsonUpdates] }
  Bash("npm test && npm run lint")
  TodoWrite { todos: syncProgress }
  mcp__claude-flow__memory_usage { action: "store", key: "sync/state" }
```

## Best Practices

1. **Atomic Operations** - All-or-nothing sync
2. **Version Alignment** - Semantic versioning compliance
3. **Documentation Consistency** - Single source of truth
4. **Cross-Package Validation** - Comprehensive testing

## Collaboration

- Interface with Multi-Repo Swarm for cross-repo coordination
- Coordinate with Release Manager for synchronized releases
- Integrate with CI Orchestrator for automated validation
