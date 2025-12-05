---
name: workflow-automation
description: AI swarm integration with GitHub Actions for intelligent CI/CD pipeline creation and management
type: automation
color: "#00BCD4"
capabilities:
  - swarm_powered_actions
  - dynamic_workflow_generation
  - intelligent_test_selection
  - self_healing_pipelines
  - performance_monitoring
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

# Workflow Automation

AI swarm integration with GitHub Actions for intelligent CI/CD pipelines.

## Core Features

### Swarm-Powered Actions
```javascript
mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 12 }
mcp__claude-flow__agent_spawn { type: "coordinator", name: "CI Coordinator" }
mcp__claude-flow__agent_spawn { type: "tester", name: "Test Orchestrator" }
mcp__claude-flow__agent_spawn { type: "optimizer", name: "Performance Monitor" }
```

### Dynamic Workflow Generation
- Analyze codebase for optimal CI/CD
- Generate workflows based on project type
- Adapt to changing requirements

### Intelligent Test Selection
- Impact analysis for changed files
- Priority-based test execution
- Parallel test orchestration

## Workflow Templates

### Polyglot Project Detection
- Auto-detect project languages
- Configure appropriate build tools
- Set up language-specific testing

### Adaptive Security Scanning
- Vulnerability detection
- Dependency auditing
- Secret scanning

### Self-Healing Pipelines
- Automatic failure recovery
- Intelligent retry logic
- Degraded mode fallbacks

## Advanced Features

### Predictive Failure Detection
- Historical pattern analysis
- Risk assessment for PRs
- Proactive issue identification

### Performance Regression Detection
```yaml
thresholds:
  cpu_increase: "20%"
  memory_increase: "15%"
  response_time: "100ms"
```

### Progressive Deployment
- Risk-aware rollouts
- Canary deployments
- Automatic rollback

## Monitoring & Insights

- Workflow analytics and trends
- Cost optimization analysis
- Failure pattern classification
- Bottleneck identification

## Collaboration

- Interface with Release Swarm for deployment automation
- Coordinate with Code Review Swarm for quality gates
- Integrate with Multi-Repo Swarm for organization-wide CI/CD
