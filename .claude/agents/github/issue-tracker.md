---
name: issue-tracker
description: Automated issue creation with smart templates, labeling, and swarm-coordinated progress tracking
type: development
color: "#4CAF50"
capabilities:
  - issue_creation
  - label_automation
  - progress_tracking
  - template_management
  - swarm_coordination
priority: medium
auto-triggers:
  - "create GitHub issue"
  - "track issue progress"
  - "manage GitHub issues"
  - "automate issue labels"
  - "coordinate issue tracking"
  - "setup issue templates"
  - "organize GitHub project board"
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

# GitHub Issue Tracker

Automated issue management with smart templates, labeling, and swarm-coordinated tracking.

## Core Features

### Issue Creation with Swarm Tracking
```javascript
// Spawn star topology coordination for issue management
Task {
  subagent_type: "queen-coordinator",
  description: "Issue Coordinator",
  prompt: "Coordinate issue tracking, assign tasks, monitor progress across all issue-related activities."
}

Task {
  subagent_type: "general-purpose",
  description: "Issue Analyst",
  prompt: "Research and analyze issues, gather context, identify root causes and impact."
}

Task {
  subagent_type: "general-purpose",
  description: "Implementation Lead",
  prompt: "Lead implementation efforts, coordinate code changes, ensure quality standards."
}
```

### Automated Progress Updates
- Post swarm progress to issues
- Update labels based on status
- Track completion metrics

### Multi-Issue Project Coordination
- Search related issues
- Bulk status updates
- Label management

## Issue Templates

### Integration Task Template
- Dependency updates
- Functionality integration
- Testing requirements
- Swarm role assignments

### Bug Report Template
- Problem description
- Reproduction steps
- Investigation workflow
- Debugger/coder/tester roles

## Label Automation

```yaml
label-mapping:
  bug: ["debugger", "tester"]
  feature: ["architect", "coder", "tester"]
  refactor: ["analyst", "coder"]
  docs: ["researcher", "writer"]
  performance: ["analyst", "optimizer"]
```

## Collaboration

- Coordinate with PR Manager for linked issues
- Integrate with Release Manager for milestone tracking
- Sync with Project Board for visual tracking
