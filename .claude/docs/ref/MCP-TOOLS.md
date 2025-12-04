# MCP Tools Reference

> Complete reference for Claude Flow MCP tools and coordination capabilities.
> Core principle: **MCP tools coordinate, Claude Code creates!**

---

## TL;DR - MCP Tool Categories

**Coordination**: `swarm_init`, `agent_spawn`, `task_orchestrate` - Set up multi-agent workflows
**Memory**: `memory_usage`, `agentdb_pattern_store/search` - Persistent state across sessions
**Agentic Flow**: `agentic_flow_agent`, `agentic_flow_list_agents` - 72 specialized agents
**Agent Booster**: `agent_booster_edit_file` - 352x faster code editing
**GitHub**: `github_swarm`, `repo_analyze`, `pr_enhance` - Repository management

**Key Rule**: MCP tools DO NOT write code. They coordinate Claude Code's actions.

**Setup**: `claude mcp add agentic-flow /opt/homebrew/bin/agentic-flow mcp start`

---

## Responsibility Separation

### Claude Code Handles
- ALL file operations (Read, Write, Edit, MultiEdit)
- ALL code generation and development tasks
- ALL bash commands and system operations
- ALL actual implementation work
- Project navigation and code analysis

### Claude Flow MCP Tools Handle
- **Coordination only** - Orchestrating Claude Code's actions
- **Memory management** - Persistent state across sessions
- **Neural features** - Cognitive patterns and learning
- **Performance tracking** - Monitoring and metrics
- **Swarm orchestration** - Multi-agent coordination
- **GitHub integration** - Advanced repository management

---

## Quick Setup (Stdio MCP)

```bash
# Add Agentic Flow MCP server (RECOMMENDED)
claude mcp add agentic-flow /opt/homebrew/bin/agentic-flow mcp start

# Or base Claude Flow if needed
claude mcp add claude-flow /opt/homebrew/bin/claude-flow mcp start
```

---

## Coordination Tools

### Swarm Management
- `mcp__claude-flow__swarm_init` - Set up coordination topology
  - Topologies: mesh, hierarchical, ring, star
  - Parameters: `{ topology, maxAgents, strategy }`
- `mcp__claude-flow__swarm_status` - Monitor coordination effectiveness
- `mcp__claude-flow__swarm_monitor` - Real-time coordination tracking

### Agent Management
- `mcp__claude-flow__agent_spawn` - Create cognitive patterns
  - Parameters: `{ type, name }`
  - Types: architect, coder, analyst, tester, researcher, coordinator
- `mcp__claude-flow__agent_list` - View active cognitive patterns
- `mcp__claude-flow__agent_metrics` - Track coordination performance

### Task Orchestration
- `mcp__claude-flow__task_orchestrate` - Break down and coordinate tasks
  - Parameters: `{ task, strategy }`
  - Strategies: parallel, adaptive, sequential
- `mcp__claude-flow__task_status` - Check workflow progress
- `mcp__claude-flow__task_results` - Review coordination outcomes

---

## Memory & Neural Tools

### Memory Management
- `mcp__claude-flow__memory_usage` - Persistent memory operations
  - Actions: store, retrieve, list
  - Parameters: `{ action, key, value, pattern }`

### Neural Features
- `mcp__claude-flow__neural_status` - Neural pattern effectiveness
- `mcp__claude-flow__neural_train` - Improve coordination patterns
- `mcp__claude-flow__neural_patterns` - Analyze thinking approaches

---

## GitHub Integration Tools

- `mcp__claude-flow__github_swarm` - Create GitHub management swarms
  - Parameters: `{ repository, agents, focus }`
- `mcp__claude-flow__repo_analyze` - Deep repository analysis
  - Parameters: `{ deep, include }`
- `mcp__claude-flow__pr_enhance` - AI-powered PR improvements
  - Parameters: `{ pr_number, add_tests, improve_docs }`
- `mcp__claude-flow__issue_triage` - Intelligent issue classification
- `mcp__claude-flow__code_review` - Automated code review with swarms

---

## AgentDB Tools

### Pattern Storage
- `mcp__claude-flow__agentdb_pattern_store` - Store reasoning patterns
  - Parameters: `{ sessionId, task, reward, success, critique }`
- `mcp__claude-flow__agentdb_pattern_search` - Search similar patterns
  - Parameters: `{ task, k, minReward, onlySuccesses }`
- `mcp__claude-flow__agentdb_pattern_stats` - Get pattern statistics
  - Parameters: `{ task, k }`

### Database Operations
- `mcp__claude-flow__agentdb_stats` - Database statistics
- `mcp__claude-flow__agentdb_clear_cache` - Clear query cache

---

## Agentic Flow Tools

### Agent Management
- `mcp__claude-flow__agentic_flow_agent` - Execute agent with task
  - Parameters: `{ agent, task, provider, model, temperature }`
- `mcp__claude-flow__agentic_flow_list_agents` - List all 66+ agents
- `mcp__claude-flow__agentic_flow_agent_info` - Get agent details
- `mcp__claude-flow__agentic_flow_create_agent` - Create custom agent
- `mcp__claude-flow__agentic_flow_list_all_agents` - List all agents with source
- `mcp__claude-flow__agentic_flow_check_conflicts` - Check agent conflicts

### Model Optimization
- `mcp__claude-flow__agentic_flow_optimize_model` - Auto-select optimal model
  - Priorities: quality, balanced, cost, speed, privacy

### Agent Booster (Ultra-Fast Editing)
- `mcp__claude-flow__agent_booster_edit_file` - 352x faster code editing
  - Parameters: `{ target_filepath, instructions, code_edit }`
- `mcp__claude-flow__agent_booster_batch_edit` - Multi-file editing
- `mcp__claude-flow__agent_booster_parse_markdown` - Parse markdown code blocks

---

## System Tools

- `mcp__claude-flow__benchmark_run` - Measure coordination efficiency
- `mcp__claude-flow__features_detect` - Available capabilities

---

## Workflow Examples

### Research Coordination

**Step 1:** Set up research coordination
```javascript
mcp__claude-flow__swarm_init {
  topology: "mesh",
  maxAgents: 5,
  strategy: "balanced"
}
```

**Step 2:** Define research perspectives
```javascript
mcp__claude-flow__agent_spawn { type: "researcher", name: "Literature Review" }
mcp__claude-flow__agent_spawn { type: "analyst", name: "Data Analysis" }
```

**Step 3:** Coordinate research execution
```javascript
mcp__claude-flow__task_orchestrate {
  task: "Research neural architecture search papers",
  strategy: "adaptive"
}
```

### Development Coordination

**Step 1:** Set up development coordination
```javascript
mcp__claude-flow__swarm_init {
  topology: "hierarchical",
  maxAgents: 8,
  strategy: "specialized"
}
```

**Step 2:** Define development perspectives
```javascript
mcp__claude-flow__agent_spawn { type: "architect", name: "System Design" }
```

**Step 3:** Coordinate implementation
```javascript
mcp__claude-flow__task_orchestrate {
  task: "Implement user authentication with JWT",
  strategy: "parallel"
}
```

---

## Best Practices

### DO
- Use MCP tools to coordinate Claude Code's approach
- Let the swarm break down problems into manageable pieces
- Use memory tools to maintain context across sessions
- Monitor coordination effectiveness with status tools
- Train neural patterns for better coordination over time

### DON'T
- Expect agents to write code (Claude Code does all implementation)
- Use MCP tools for file operations (use Claude Code's native tools)
- Try to make agents execute bash commands (Claude Code handles this)
- Confuse coordination with execution (MCP coordinates, Claude executes)

---

## Hooks Integration

### Pre-Operation Hooks
- Auto-assign agents before file edits based on file type
- Validate commands before execution for safety
- Prepare resources automatically for complex operations
- Optimize topology based on task complexity analysis
- Cache searches for improved performance

### Post-Operation Hooks
- Auto-format code using language-specific formatters
- Train neural patterns from successful operations
- Update memory with operation context
- Analyze performance and identify bottlenecks
- Track token usage for efficiency metrics

### Session Management
- Generate summaries at session end
- Persist state across Claude Code sessions
- Track metrics for continuous improvement
- Restore previous session context automatically
- Export workflows for reuse

---

## Performance Benefits

- **84.8% SWE-Bench solve rate** - Better problem-solving through coordination
- **32.3% token reduction** - Efficient task breakdown reduces redundancy
- **2.8-4.4x speed improvement** - Parallel coordination strategies
- **27+ neural models** - Diverse cognitive approaches

---

## Agentic-Flow Enhancements (over base claude-flow)

- **66 specialized agents** vs base agent types
- **213 MCP tools** vs 101 base tools
- **ReasoningBank** - Decision pattern storage
- **Agent Booster** - Performance optimization
- **QUIC transport** - Faster agent communication
- **Multi-model router** - Cost-optimized model selection
