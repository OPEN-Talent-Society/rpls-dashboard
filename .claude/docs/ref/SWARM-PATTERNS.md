# Swarm Orchestration Patterns

> Complete reference for swarm patterns, multi-agent coordination, and parallel execution.
> Core principle: **Agentic-Flow coordinates, Claude Code creates!**

---

## TL;DR - Parallel Execution Rules

**THE GOLDEN RULE**: If you need X operations, do them in 1 message, not X messages.

**Topologies**: mesh (peer-to-peer), hierarchical (queen-led), ring (circular), star (central hub)

**Quick Pattern**:
```javascript
// CORRECT: Everything in ONE message
mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
mcp__claude-flow__agent_spawn { type: "researcher" }
mcp__claude-flow__agent_spawn { type: "coder" }
TodoWrite { todos: [...] }
Write "file1.js"
Write "file2.js"
```

**Agent Types**: architect, coder, analyst, tester, researcher, coordinator

---

## When to Use Multi-Agent Coordination

Use swarms, hives, and subagents for:
- **Complex tasks** requiring multiple perspectives (architecture + implementation + testing)
- **Parallel workstreams** that can run simultaneously
- **Large codebases** where different areas need exploration
- **Research + Implementation** combinations

---

## The Golden Rule: Batch Everything

```
If you need to do X operations, they should be in 1 message, not X messages
```

### Correct (Parallel)
```javascript
[Single Message with BatchTool]:
  mcp__claude-flow__swarm_init { topology: "mesh", maxAgents: 6 }
  mcp__claude-flow__agent_spawn { type: "researcher" }
  mcp__claude-flow__agent_spawn { type: "coder" }
  mcp__claude-flow__agent_spawn { type: "analyst" }
  TodoWrite { todos: [todo1, todo2, todo3] }
  Bash "mkdir -p app/{src,tests,docs}"
  Write "app/package.json"
```

### Wrong (Sequential - NEVER DO THIS)
```javascript
Message 1: mcp__claude-flow__swarm_init
Message 2: mcp__claude-flow__agent_spawn
Message 3: TodoWrite (one todo)
// This is 3x slower!
```

---

## Batch Operations by Type

**File Operations (Single Message):**
- Read 10 files? -> One message with 10 Read calls
- Write 5 files? -> One message with 5 Write calls
- Edit 1 file many times? -> One MultiEdit call

**Swarm Operations (Single Message):**
- Need 8 agents? -> One message with swarm_init + 8 agent_spawn calls
- Multiple memories? -> One message with all memory_usage calls
- Task + monitoring? -> One message with task_orchestrate + swarm_monitor

**Command Operations (Single Message):**
- Multiple directories? -> One message with all mkdir commands
- Install + test + lint? -> One message with all pnpm commands
- Git operations? -> One message with all git commands

---

## Mandatory Swarm Pattern Template

```
STEP 1: IMMEDIATE PARALLEL SPAWN (Single Message!)
[BatchTool]:
  - mcp__claude-flow__swarm_init { topology: "hierarchical", maxAgents: 8, strategy: "parallel" }
  - mcp__claude-flow__agent_spawn { type: "architect", name: "System Designer" }
  - mcp__claude-flow__agent_spawn { type: "coder", name: "API Developer" }
  - mcp__claude-flow__agent_spawn { type: "coder", name: "Frontend Dev" }
  - mcp__claude-flow__agent_spawn { type: "analyst", name: "DB Designer" }
  - mcp__claude-flow__agent_spawn { type: "tester", name: "QA Engineer" }
  - TodoWrite { todos: [multiple todos at once] }

STEP 2: PARALLEL TASK EXECUTION (Single Message!)
[BatchTool]:
  - mcp__claude-flow__task_orchestrate { task: "main task", strategy: "parallel" }
  - mcp__claude-flow__memory_usage { action: "store", key: "init", value: {...} }
  - Multiple Read/Write operations
  - Multiple Bash commands

STEP 3: CONTINUE PARALLEL WORK (Never Sequential!)
```

---

## Agent Coordination Protocol

### Before Starting Work
```bash
/opt/homebrew/bin/claude-flow hooks pre-task --description "[agent task]" --auto-spawn-agents false
/opt/homebrew/bin/claude-flow hooks session-restore --session-id "swarm-[id]" --load-memory true
```

### During Work (After EVERY Major Step)
```bash
# Store progress after each file operation
/opt/homebrew/bin/claude-flow hooks post-edit --file "[filepath]" --memory-key "swarm/[agent]/[step]"

# Store decisions and findings
/opt/homebrew/bin/claude-flow hooks notification --message "[what was done]" --telemetry true

# Check coordination with other agents
/opt/homebrew/bin/claude-flow hooks pre-search --query "[what to check]" --cache-results true
```

### After Completing Work
```bash
/opt/homebrew/bin/claude-flow hooks post-task --task-id "[task]" --analyze-performance true
/opt/homebrew/bin/claude-flow hooks session-end --export-metrics true --generate-summary true
```

---

## Agent Prompt Template

When spawning agents, include these coordination instructions:

```
You are the [Agent Type] agent in a coordinated swarm.

MANDATORY COORDINATION:
1. START: Run `/opt/homebrew/bin/claude-flow hooks pre-task --description "[your task]"`
2. DURING: After EVERY file operation, run `/opt/homebrew/bin/claude-flow hooks post-edit --file "[file]" --memory-key "agent/[step]"`
3. MEMORY: Store ALL decisions using `/opt/homebrew/bin/claude-flow hooks notification --message "[decision]"`
4. END: Run `/opt/homebrew/bin/claude-flow hooks post-task --task-id "[task]" --analyze-performance true`

Your specific task: [detailed task description]

REMEMBER: Coordinate with other agents by checking memory BEFORE making decisions!
```

---

## Memory Coordination Pattern

```javascript
// After each major decision or implementation
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm-{id}/agent-{name}/{step}",
  value: {
    timestamp: Date.now(),
    decision: "what was decided",
    implementation: "what was built",
    nextSteps: ["step1", "step2"],
    dependencies: ["dep1", "dep2"]
  }
}

// To retrieve coordination data
mcp__claude-flow__memory_usage {
  action: "retrieve",
  key: "swarm-{id}/agent-{name}/{step}"
}

// To check all swarm progress
mcp__claude-flow__memory_usage {
  action: "list",
  pattern: "swarm-{id}/*"
}
```

---

## Hive-Mind Pattern

For queen-led collective intelligence with consensus:

```javascript
// Initialize hive with queen coordination
mcp__claude-flow__swarm_init {
  topology: "hierarchical",
  maxAgents: 8,
  strategy: "consensus"
}
// Queen agent coordinates, workers execute
// All agents share memory via .hive-mind/memory.json
```

---

## Visual Task Tracking Format

```
Progress Overview
   |-- Total Tasks: X
   |-- Completed: X (X%)
   |-- In Progress: X (X%)
   |-- Todo: X (X%)
   |-- Blocked: X (X%)

Todo (X)
   |-- 001: [Task description] [PRIORITY]

In progress (X)
   |-- 002: [Task description] -> X deps
   |-- 003: [Task description] [PRIORITY]

Completed (X)
   |-- 004: [Task description]
   |-- ... (more completed tasks)

Priority: HIGH/CRITICAL, MEDIUM, LOW
Dependencies: -> X deps | Actionable: >
```

---

## Visual Swarm Status

```
Swarm Status: ACTIVE
|-- Topology: hierarchical
|-- Agents: 6/8 active
|-- Mode: parallel execution
|-- Tasks: 12 total (4 complete, 6 in-progress, 2 pending)
|-- Memory: 15 coordination points stored

Agent Activity:
|-- architect: Designing database schema...
|-- coder-1: Implementing auth endpoints...
|-- coder-2: Building user CRUD operations...
|-- analyst: Optimizing query performance...
|-- tester: Waiting for auth completion...
|-- coordinator: Monitoring progress...
```

---

## Real Example: Full-Stack App Development

**Task**: "Build a complete REST API with authentication, database, and tests"

```javascript
// CORRECT: SINGLE MESSAGE with ALL operations
[BatchTool - Message 1]:
  // Initialize and spawn ALL agents at once
  mcp__claude-flow__swarm_init { topology: "hierarchical", maxAgents: 8, strategy: "parallel" }
  mcp__claude-flow__agent_spawn { type: "architect", name: "System Designer" }
  mcp__claude-flow__agent_spawn { type: "coder", name: "API Developer" }
  mcp__claude-flow__agent_spawn { type: "coder", name: "Auth Expert" }
  mcp__claude-flow__agent_spawn { type: "analyst", name: "DB Designer" }
  mcp__claude-flow__agent_spawn { type: "tester", name: "Test Engineer" }
  mcp__claude-flow__agent_spawn { type: "coordinator", name: "Lead" }

  // Update ALL todos at once
  TodoWrite { todos: [
    { content: "Design API architecture", status: "in_progress" },
    { content: "Implement authentication", status: "pending" },
    { content: "Design database schema", status: "pending" },
    { content: "Build REST endpoints", status: "pending" },
    { content: "Write comprehensive tests", status: "pending" }
  ]}

  // Start orchestration
  mcp__claude-flow__task_orchestrate { task: "Build REST API", strategy: "parallel" }

[BatchTool - Message 2]:
  // Create ALL directories at once
  Bash("mkdir -p test-app/{src,tests,docs,config}")
  Bash("mkdir -p test-app/src/{models,routes,middleware,services}")

  // Write ALL base files at once
  Write("test-app/package.json", packageJsonContent)
  Write("test-app/.env.example", envContent)
  Write("test-app/src/server.js", serverContent)

[BatchTool - Message 3]:
  // Read multiple files for context
  Read("test-app/package.json")
  Read("test-app/src/server.js")

  // Run multiple commands
  Bash("cd test-app && pnpm add")
  Bash("cd test-app && pnpm test")
```

---

## Performance Tips

1. **Batch Everything**: Never operate on single files when multiple are needed
2. **Parallel First**: Always think "what can run simultaneously?"
3. **Memory is Key**: Use memory for ALL cross-agent coordination
4. **Monitor Progress**: Use `mcp__claude-flow__swarm_monitor` for real-time tracking
5. **Auto-Optimize**: Let hooks handle topology and agent selection

---

## Claude Flow v2.0.0 Features

- **GitHub Integration** - Deep repository management
- **Project Templates** - Quick-start for common projects
- **Advanced Analytics** - Detailed performance insights
- **Custom Agent Types** - Domain-specific coordinators
- **Workflow Automation** - Reusable task sequences
- **Enhanced Security** - Safer command execution

---

## Performance Benefits

When using Claude Flow coordination with Claude Code:
- **84.8% SWE-Bench solve rate** - Better problem-solving through coordination
- **32.3% token reduction** - Efficient task breakdown reduces redundancy
- **2.8-4.4x speed improvement** - Parallel coordination strategies
- **27+ neural models** - Diverse cognitive approaches
