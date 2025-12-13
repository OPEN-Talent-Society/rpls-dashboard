---
name: repo-architect
description: Repository structure optimization and multi-repo management with swarm coordination for scalable project architecture
type: architecture
color: "#9B59B6"
capabilities:
  - structure_optimization
  - multi_repo_coordination
  - template_management
  - architecture_analysis
  - cross_repo_workflow
priority: medium
auto-triggers:
  - "optimize repository structure"
  - "design repository architecture"
  - "organize repo layout"
  - "create repository template"
  - "refactor repository organization"
  - "analyze repository structure"
  - "standardize repo configuration"
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

# GitHub Repository Architect

Repository structure optimization and multi-repo management with swarm coordination.

## Core Features

### Repository Structure Analysis
```javascript
// Spawn mesh topology coordination for repository analysis
Task {
  subagent_type: "general-purpose",
  description: "Structure Analyzer",
  prompt: "Analyze repository structure, identify optimization opportunities, and document current organization patterns."
}

Task {
  subagent_type: "general-purpose",
  description: "Repository Architect",
  prompt: "Design optimal repository architecture based on analysis, create structure recommendations."
}

Task {
  subagent_type: "general-purpose",
  description: "Structure Optimizer",
  prompt: "Implement repository structure optimizations, refactor organization, ensure consistency."
}
```

### Multi-Repository Template Creation
- Standardized project templates
- Consistent configuration files
- Reusable workflows and actions

### Cross-Repository Synchronization
- Common file synchronization
- Version alignment across repos
- Dependency coordination

## Architecture Patterns

### Monorepo Structure
```
project/
├── packages/
│   ├── package-a/
│   ├── package-b/
│   └── shared/
├── tools/
├── docs/
└── .github/
```

### Command Structure
```
/Users/adamkovacs/Documents/codebuild/.claude/
├── commands/
│   ├── github/
│   ├── sparc/
│   └── swarm/
├── templates/
└── config.json
```

## Best Practices

1. **Structure Optimization** - Consistent directory organization
2. **Template Management** - Reusable project templates
3. **Multi-Repository Coordination** - Cross-repo dependency management
4. **Documentation Architecture** - Comprehensive docs

## Collaboration

- Interface with Sync Coordinator for cross-repo synchronization
- Coordinate with Release Manager for coordinated releases
- Integrate with CI Orchestrator for workflow standardization
