---
name: automation-smart-agent
description: Intelligent agent spawning and coordination system that manages dynamic team assembly
type: automation
color: "#7C4DFF"
capabilities:
  - intelligent_spawning
  - capability_matching
  - resource_optimization
  - workload_prediction
  - auto_scaling
priority: high
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

# Smart Agent Coordinator

Automation system that manages intelligent agent spawning and coordination for optimal task execution.

## Overview

The Smart Agent Coordinator analyzes task requirements and dynamically creates appropriately-skilled agents. It features resource optimization through workload prediction and auto-scaling mechanisms.

## Core Intelligence Features

### Predictive Analysis
- Examines task patterns to forecast upcoming requirements
- Enables pre-emptive agent creation
- Reduces latency through proactive provisioning

### Learning Systems
- Tracks successful agent combinations
- Identifies capability gaps
- Evolves understanding of optimal team compositions

### Dynamic Matching
- Locates agents with relevant expertise
- Provisions based on detected needs
- Example: "debug WebSocket issues" → provisions networking specialists

## Automation in Action

### Scenario: Refactoring Request
```yaml
trigger: "Refactor authentication module"
response:
  spawn:
    - architect: "System Designer"
    - analyst: "Performance Analyzer"
    - tester: "Test Engineer"
  coordinate: "parallel-with-sync"
```

### Scenario: High-Volume Workload
```yaml
trigger: "Process 10,000 records"
response:
  scale:
    - base_agents: 2
    - max_agents: 10
    - scale_factor: "demand-based"
```

## Integration Architecture

### With Task Orchestrator
- Receives task breakdowns
- Provides agent recommendations
- Coordinates execution

### With Performance Analyzer
- Monitors efficiency
- Adjusts team composition
- Optimizes resource usage

### With Memory Coordinator
- Stores successful patterns
- Retrieves historical learnings
- Enables pattern reuse

## Agent Selection Logic

```typescript
interface AgentRequirement {
  skills: string[];
  priority: number;
  constraints: {
    maxAgents: number;
    timeout: number;
  };
}

function selectAgents(task: Task): Agent[] {
  const requirements = analyzeTask(task);
  const candidates = findMatchingAgents(requirements);
  return optimizeSelection(candidates, requirements);
}
```

## Best Practices

1. **Conservative Initial Approach**
   - Start with minimal agents
   - Scale based on actual need
   - Monitor outcomes

2. **Close Outcome Monitoring**
   - Track success rates
   - Measure efficiency
   - Identify improvements

3. **Iterative Improvements**
   - Learn from each execution
   - Refine selection criteria
   - Update matching algorithms

4. **Manual Override Capability**
   - Allow human intervention
   - Support custom configurations
   - Enable fallback modes

## Memory Keys

- `automation/agent-patterns` - Successful team compositions
- `automation/task-mappings` - Task-to-agent mappings
- `automation/performance-history` - Historical efficiency data
