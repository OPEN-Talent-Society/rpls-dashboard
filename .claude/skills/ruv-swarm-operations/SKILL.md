---
name: ruv-swarm-operations
description: RuV Swarm operations for DAA (Decentralized Autonomous Agents), neural patterns, and high-performance swarm coordination. Load on-demand when needing advanced swarm features.
category: orchestration
tags: [swarm, daa, neural, agents, coordination, memory]
version: 1.0.0
mcp_install: |
  # To enable ruv-swarm MCP temporarily:
  claude mcp add ruv-swarm node /Users/adamkovacs/Library/pnpm/global/5/node_modules/ruv-swarm/bin/ruv-swarm-secure.js mcp start
---

# RuV Swarm Operations

Advanced swarm orchestration with DAA (Decentralized Autonomous Agents), neural pattern recognition, and cognitive behavior analysis. This is an on-demand skill - the MCP server is not always loaded to save tokens.

## When to Use

Load this skill when you need:
- **DAA (Decentralized Autonomous Agents)** - Self-learning, self-coordinating agents
- **Neural Training** - Train agents with cognitive patterns
- **Meta-Learning** - Cross-domain knowledge transfer
- **Advanced Workflows** - DAA-orchestrated autonomous workflows

## Installation (On-Demand)

```bash
# Add MCP server when needed
claude mcp add ruv-swarm node /Users/adamkovacs/Library/pnpm/global/5/node_modules/ruv-swarm/bin/ruv-swarm-secure.js mcp start

# Remove when done to save tokens
claude mcp remove ruv-swarm
```

## Core Features

### 1. DAA Agent Creation

```javascript
mcp__ruv-swarm__daa_agent_create({
  id: "agent-001",
  capabilities: ["analysis", "coding", "testing"],
  cognitivePattern: "adaptive", // convergent, divergent, lateral, systems, critical
  enableMemory: true,
  learningRate: 0.1
})
```

### 2. Cognitive Patterns

| Pattern | Best For |
|---------|----------|
| `convergent` | Problem-solving, optimization |
| `divergent` | Brainstorming, creative work |
| `lateral` | Innovation, novel solutions |
| `systems` | Architecture, complex systems |
| `critical` | Review, analysis, validation |
| `adaptive` | Auto-selects based on task |

### 3. DAA Workflows

```javascript
// Create autonomous workflow
mcp__ruv-swarm__daa_workflow_create({
  id: "workflow-001",
  name: "Autonomous Development",
  steps: [
    { id: "design", action: "design_system", agent: "architect" },
    { id: "implement", action: "write_code", agent: "coder", depends_on: ["design"] },
    { id: "test", action: "run_tests", agent: "tester", depends_on: ["implement"] }
  ],
  strategy: "adaptive"
})

// Execute with autonomous coordination
mcp__ruv-swarm__daa_workflow_execute({
  workflowId: "workflow-001",
  agentIds: ["agent-001", "agent-002"],
  parallelExecution: true
})
```

### 4. Knowledge Sharing

```javascript
// Share knowledge between agents
mcp__ruv-swarm__daa_knowledge_share({
  sourceAgentId: "expert-agent",
  targetAgentIds: ["learner-1", "learner-2"],
  knowledgeDomain: "api-design",
  knowledgeContent: {
    patterns: [...],
    bestPractices: [...],
    antiPatterns: [...]
  }
})
```

### 5. Meta-Learning

```javascript
// Enable cross-domain learning
mcp__ruv-swarm__daa_meta_learning({
  sourceDomain: "backend-development",
  targetDomain: "frontend-development",
  transferMode: "adaptive",
  agentIds: ["agent-001"]
})
```

### 6. Agent Adaptation

```javascript
// Trigger learning from feedback
mcp__ruv-swarm__daa_agent_adapt({
  agentId: "agent-001",
  feedback: "Excellent code quality",
  performanceScore: 0.95,
  suggestions: ["Consider more edge cases", "Add performance tests"]
})
```

## Neural Features

### Training

```javascript
mcp__ruv-swarm__neural_train({
  agentId: "agent-001",
  iterations: 50
})
```

### Pattern Analysis

```javascript
mcp__ruv-swarm__neural_patterns({
  pattern: "all" // or specific: convergent, divergent, etc.
})
```

### Status

```javascript
mcp__ruv-swarm__neural_status({
  agentId: "agent-001" // optional - all agents if omitted
})
```

## Performance Metrics

```javascript
mcp__ruv-swarm__daa_performance_metrics({
  category: "all", // system, performance, efficiency, neural
  timeRange: "24h" // 1h, 24h, 7d
})
```

## Integration with claude-flow

RuV Swarm complements the base claude-flow MCP:

| Feature | claude-flow | ruv-swarm |
|---------|-------------|-----------|
| Basic swarms | ✅ | ✅ |
| Task orchestration | ✅ | ✅ |
| Memory | ✅ | ✅+ (with learning) |
| DAA | ❌ | ✅ |
| Neural training | Basic | Advanced |
| Meta-learning | ❌ | ✅ |
| Cognitive patterns | Basic | Full suite |

## Best Practices

1. **Load on-demand** - Only enable when using DAA/neural features
2. **Use claude-flow for basics** - Standard swarms don't need ruv-swarm
3. **Enable learning** - Set `enableMemory: true` for agents that learn
4. **Match patterns** - Use appropriate cognitive pattern for task type
5. **Share knowledge** - Leverage DAA knowledge sharing between agents

## Example: Full DAA Workflow

```javascript
// 1. Initialize DAA service
mcp__ruv-swarm__daa_init({
  enableLearning: true,
  enableCoordination: true,
  persistenceMode: "disk"
})

// 2. Create specialized agents
mcp__ruv-swarm__daa_agent_create({
  id: "architect",
  cognitivePattern: "systems",
  capabilities: ["design", "planning"]
})

mcp__ruv-swarm__daa_agent_create({
  id: "coder",
  cognitivePattern: "convergent",
  capabilities: ["implementation", "optimization"]
})

// 3. Create and execute workflow
mcp__ruv-swarm__daa_workflow_create({...})
mcp__ruv-swarm__daa_workflow_execute({...})

// 4. Review learning progress
mcp__ruv-swarm__daa_learning_status({ detailed: true })
```

## Removal

When done with advanced swarm features:

```bash
claude mcp remove ruv-swarm
```

This restores token efficiency while keeping base swarm capabilities via claude-flow.

---

*Skill: ruv-swarm-operations | Version: 1.0.0 | Status: On-demand*
