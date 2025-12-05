# Multi-Agent Orchestration Patterns

> Complete reference for parallel worker coordination using the Task tool.
> Core principle: **Spawn workers with Task tool, not MCP swarm tools (DENIED).**

---

## TL;DR - Parallel Execution Rules

**THE GOLDEN RULE**: If you need X operations, do them in 1 message, not X messages.

**Worker Spawning**: Use Task tool with `subagent_type` parameter

**Quick Pattern**:
```javascript
// CORRECT: Everything in ONE message
Task({ subagent_type: "general-purpose", description: "Research", prompt: "..." })
Task({ subagent_type: "general-purpose", description: "Implementation", prompt: "..." })
Task({ subagent_type: "Explore", description: "Code analysis", prompt: "..." })
TodoWrite({ todos: [...] })
```

**Available subagent_types**: general-purpose, Explore, Plan, or any agent name from `.claude/agents/`

---

## When to Use Multi-Agent Coordination

Use parallel workers for:
- **Complex tasks** requiring multiple perspectives (research + implementation + testing)
- **Parallel workstreams** that can run simultaneously
- **Large codebases** where different areas need exploration
- **Research + Implementation** combinations

---

## The Golden Rule: Batch Everything

```
If you need to do X operations, they should be in 1 message, not X messages
```

### ✅ Correct (Parallel)
```javascript
[Single Message]:
  Task({ subagent_type: "general-purpose", description: "Researcher", prompt: "Research topic X" })
  Task({ subagent_type: "general-purpose", description: "Coder", prompt: "Implement Y" })
  Task({ subagent_type: "general-purpose", description: "Tester", prompt: "Write tests for Z" })
  TodoWrite({ todos: [todo1, todo2, todo3] })
  Bash("mkdir -p app/{src,tests,docs}")
```

### ❌ Wrong (Sequential - NEVER DO THIS)
```javascript
Message 1: Task({ ... })
Message 2: Task({ ... })
Message 3: TodoWrite({ ... })
// This is 3x slower!
```

---

## Batch Operations by Type

**File Operations (Single Message):**
- Read 10 files? → One message with 10 Read calls
- Write 5 files? → One message with 5 Write calls
- Edit 1 file many times? → One MultiEdit call

**Worker Operations (Single Message):**
- Need 3 workers? → One message with 3 Task calls
- Multiple file reads + worker spawn? → One message with all operations
- Task + monitoring? → One message with Task + TodoWrite

**Command Operations (Single Message):**
- Multiple directories? → One message with all mkdir commands
- Install + test + lint? → One message with all pnpm commands
- Git operations? → One message with all git commands

---

## Mandatory Multi-Worker Pattern Template

```
STEP 1: IMMEDIATE PARALLEL SPAWN (Single Message!)
[Single Message]:
  Task({ subagent_type: "general-purpose", description: "Architect", prompt: "Design system architecture for X" })
  Task({ subagent_type: "general-purpose", description: "API Developer", prompt: "Implement REST endpoints" })
  Task({ subagent_type: "general-purpose", description: "Frontend Dev", prompt: "Build React components" })
  Task({ subagent_type: "Explore", description: "DB Explorer", prompt: "Analyze database schema" })
  Task({ subagent_type: "general-purpose", description: "QA Engineer", prompt: "Write integration tests" })
  TodoWrite({ todos: [multiple todos at once] })

STEP 2: PARALLEL TASK EXECUTION (Single Message!)
[Single Message]:
  Read({ file_path: "/path/to/file1.ts" })
  Read({ file_path: "/path/to/file2.ts" })
  Write({ file_path: "/path/to/output1.ts", content: "..." })
  Write({ file_path: "/path/to/output2.ts", content: "..." })
```

---

## ❌ DENIED MCP Tools (DO NOT USE)

**These tools are DENIED and will not work:**
```javascript
// ❌ WRONG - DENIED
mcp__claude-flow__swarm_init({ topology: "mesh" })
mcp__claude-flow__agent_spawn({ type: "coder" })
mcp__claude-flow__task_orchestrate({ task: "..." })
mcp__claude-flow__agentic_flow_agent({ agent: "coder", task: "..." })
```

**Why DENIED:** These require separate API keys and infrastructure.

**Use instead:**
```javascript
// ✅ CORRECT - Uses Claude Max subscription
Task({
  subagent_type: "general-purpose",
  description: "Brief task description",
  prompt: "Detailed instructions for the worker..."
})
```

---

## Available Worker Types

**Built-in subagent_types:**
- `general-purpose` - Research, analysis, multi-step tasks
- `Explore` - Fast codebase exploration and file finding
- `Plan` - Planning and breakdown of complex tasks

**Custom agents from `.claude/agents/`:**
- `worker-specialist` - Execute assigned tasks
- `scout-explorer` - Explore and gather information
- `code-analyzer` - Analyze code quality
- `queen-coordinator` - Strategic orchestration
- Any agent name from `.claude/agents/` directory (143 available)

---

## Parallel Patterns

### Research + Implementation
```javascript
[Single Message]:
  Task({ subagent_type: "general-purpose", description: "Researcher", prompt: "Research best practices for JWT auth" })
  Task({ subagent_type: "general-purpose", description: "Implementer", prompt: "Implement JWT middleware based on findings" })
  Task({ subagent_type: "general-purpose", description: "Tester", prompt: "Write tests for auth flow" })
```

### Codebase Exploration + Analysis
```javascript
[Single Message]:
  Task({ subagent_type: "Explore", description: "Find auth files", prompt: "Find all files related to authentication" })
  Task({ subagent_type: "Explore", description: "Find test files", prompt: "Find all test files" })
  Task({ subagent_type: "general-purpose", description: "Analyzer", prompt: "Analyze test coverage gaps" })
```

### Multi-File Refactoring
```javascript
[Single Message]:
  Read({ file_path: "/path/to/file1.ts" })
  Read({ file_path: "/path/to/file2.ts" })
  Read({ file_path: "/path/to/file3.ts" })
  Task({ subagent_type: "general-purpose", description: "Refactor planner", prompt: "Plan refactoring strategy for these files" })
```

---

## Performance Optimization

### Use Agent Booster for Fast Edits

**352x faster than cloud APIs:**
```javascript
mcp__claude-flow__agent_booster_batch_edit({
  edits: [
    { target_filepath: "/path/to/file1.ts", instructions: "Add types", code_edit: "..." },
    { target_filepath: "/path/to/file2.ts", instructions: "Fix errors", code_edit: "..." },
    { target_filepath: "/path/to/file3.ts", instructions: "Add docs", code_edit: "..." }
  ]
})
```

---

## Best Practices

### ✅ DO
- Spawn all workers in ONE message (parallel execution)
- Use Task tool for ALL worker spawning
- Combine file operations with worker spawning in same message
- Use descriptive description field for worker tracking
- Use TodoWrite to track worker progress

### ❌ DON'T
- Use `mcp__claude-flow__swarm_init` (DENIED)
- Use `mcp__claude-flow__agent_spawn` (DENIED)
- Use `mcp__claude-flow__agentic_flow_agent` (DENIED)
- Spawn workers in sequential messages (kills parallelism)
- Forget to batch independent operations

---

## Coordination vs Execution

### Claude Code Does (MUST)
- ALL file operations (Read/Write/Edit)
- ALL code generation
- ALL bash commands
- ALL actual implementation work

### Workers Do (via Task tool)
- Research and analysis
- Planning and breakdown
- Code exploration
- Testing strategy
- Design recommendations

**Workers provide recommendations, Claude Code implements them.**

---

## Examples

### Full-Stack Feature Implementation

```javascript
[Single Message]:
  // Spawn all workers
  Task({ subagent_type: "general-purpose", description: "Backend Developer",
    prompt: "Design and implement REST API for user management with CRUD operations" })
  Task({ subagent_type: "general-purpose", description: "Frontend Developer",
    prompt: "Create React components for user management UI with forms and tables" })
  Task({ subagent_type: "general-purpose", description: "Database Designer",
    prompt: "Design database schema for users table with proper indexes" })
  Task({ subagent_type: "general-purpose", description: "Test Engineer",
    prompt: "Write integration tests for user management endpoints" })

  // Track progress
  TodoWrite({ todos: [
    { content: "Backend API implementation", status: "pending", activeForm: "Implementing backend API" },
    { content: "Frontend UI components", status: "pending", activeForm: "Building frontend UI" },
    { content: "Database schema creation", status: "pending", activeForm: "Creating database schema" },
    { content: "Integration tests", status: "pending", activeForm: "Writing integration tests" }
  ]})
```

---

**Last Updated:** 2025-12-04
**Version:** 2.0 (Task tool patterns, removed DENIED swarm tools)
