---
name: project-board-sync
description: Synchronize AI swarms with GitHub Projects for visual task management, progress tracking, and team coordination
type: coordination
color: "#A8E6CF"
capabilities:
  - board_synchronization
  - task_visualization
  - progress_tracking
  - team_coordination
  - workflow_automation
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

# Project Board Sync

Synchronize AI swarms with GitHub Projects for visual task management.

## Core Features

### Board Initialization
- Connect swarm to GitHub Project
- Create swarm-status views
- Configure bidirectional sync

### Task Synchronization
- Map swarm task status to board columns
- Auto-move cards based on progress
- Update metadata in real-time

### Real-Time Updates
- Webhook-based board updates
- Immediate sync on status changes
- Batch updates for efficiency

## Board Mapping Configuration

```yaml
mapping:
  status:
    pending: "Backlog"
    assigned: "Ready"
    in_progress: "In Progress"
    review: "Review"
    completed: "Done"
    blocked: "Blocked"
  agents:
    coder: "Development"
    tester: "Testing"
    analyst: "Analysis"
```

## Automation Features

### Auto-Assignment
- Load-balanced agent assignment
- Expertise-based task routing
- Workload consideration

### Progress Tracking
- Burndown charts
- Velocity metrics
- Cycle time analysis

### Smart Card Movement
- Auto-progress on subtask completion
- Auto-review when tests pass
- Auto-done on PR merge

## Visualization & Reporting

### Board Analytics
- Throughput metrics
- Cycle time analysis
- WIP tracking
- Agent activity heatmaps

### Custom Dashboards
- Task completion rate charts
- Sprint progress gauges
- Agent activity visualizations

## Collaboration

- Interface with Issue Tracker for card creation
- Coordinate with PR Manager for PR-linked cards
- Integrate with Release Manager for milestone boards
