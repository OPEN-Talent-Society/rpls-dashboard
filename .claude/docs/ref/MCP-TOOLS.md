# MCP Tools Reference

> Complete reference for Claude Flow MCP tools and coordination capabilities.
> Core principle: **MCP tools coordinate, Claude Code creates!**

---

## TL;DR - MCP Tool Categories

**✅ ALLOWED - Memory**: `agentdb_pattern_store/search`, `agentdb_stats` - Persistent reasoning patterns
**✅ ALLOWED - Agent Booster**: `agent_booster_edit_file`, `agent_booster_batch_edit` - 352x faster code editing
**✅ ALLOWED - Context7**: `resolve-library-id`, `get-library-docs` - Documentation lookup

**❌ DENIED - Coordination**: `swarm_init`, `agent_spawn`, `task_orchestrate` - Use Task tool instead
**❌ DENIED - Agentic Flow**: `agentic_flow_agent` - Requires separate API keys, use Task tool instead

**Key Rule**: For agent spawning, ALWAYS use the Task tool with subagent_type parameter.

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

## ❌ DENIED - Coordination Tools (Use Task Tool Instead)

**These tools are DENIED and will not work. Use the Task tool for agent spawning:**

```javascript
// ✅ CORRECT - Use Task tool
Task({
  subagent_type: "general-purpose",  // or any agent from .claude/agents/
  description: "Worker task description",
  prompt: "Detailed instructions..."
})

// ❌ WRONG - These are DENIED
mcp__claude-flow__swarm_init({ topology: "mesh" })
mcp__claude-flow__agent_spawn({ type: "coder" })
mcp__claude-flow__task_orchestrate({ task: "..." })
```

**Why DENIED:** These tools require separate API keys and infrastructure. The Task tool uses your Claude Max subscription and is always available.

---

## ✅ ALLOWED - Memory & Pattern Tools

### AgentDB (Reasoning Bank)
- `mcp__claude-flow__agentdb_pattern_store` - Store successful reasoning patterns
  ```javascript
  agentdb_pattern_store({
    sessionId: "id",
    task: "what was accomplished",
    reward: 0.9,  // 0-1 success metric
    success: true,
    critique: "self-reflection"
  })
  ```
- `mcp__claude-flow__agentdb_pattern_search` - Search for similar patterns
  ```javascript
  agentdb_pattern_search({ task: "description", k: 5 })
  ```
- `mcp__claude-flow__agentdb_stats` - Database statistics
- `mcp__claude-flow__agentdb_clear_cache` - Clear query cache

---

## ❌ DENIED - GitHub Integration Tools

**These tools are DENIED.** For GitHub operations, use the `gh` CLI tool via Bash or the GitHub Skills:
- `.claude/skills/github-code-review/`
- `.claude/skills/github-multi-repo/`
- `.claude/skills/github-project-management/`
- `.claude/skills/github-release-management/`
- `.claude/skills/github-workflow-automation/`

---

## ✅ ALLOWED - Agent Booster (Ultra-Fast Editing)

**These tools work and are 352x faster than cloud APIs:**

- `mcp__claude-flow__agent_booster_edit_file` - Lightning-fast code editing
  ```javascript
  agent_booster_edit_file({
    target_filepath: "/path/to/file.ts",
    instructions: "Add error handling",
    code_edit: "// ... existing code ...\ntry {\n  // new code\n}"
  })
  ```
- `mcp__claude-flow__agent_booster_batch_edit` - Multi-file editing in one operation
- `mcp__claude-flow__agent_booster_parse_markdown` - Parse markdown with filepath metadata

---

## ❌ DENIED - Agentic Flow Agent Tools

**These tools are DENIED because they require separate API keys.**

**Instead of:**
```javascript
mcp__claude-flow__agentic_flow_agent({ agent: "coder", task: "..." })
```

**Use Task tool:**
```javascript
Task({
  subagent_type: "general-purpose",
  description: "Coding task",
  prompt: "Detailed instructions..."
})
```

**Available for information only (no execution):**
- `mcp__claude-flow__agentic_flow_list_agents` - List available agent types (informational)
- `mcp__claude-flow__agentic_flow_agent_info` - Get agent details (informational)

---

## System Tools

- `mcp__claude-flow__benchmark_run` - Measure coordination efficiency
- `mcp__claude-flow__features_detect` - Available capabilities

---

## ✅ CORRECT Workflow Examples

### Multi-Agent Research Task

**Use Task tool to spawn parallel workers:**

```javascript
// Spawn multiple workers in ONE message (parallel execution)
Task({
  subagent_type: "general-purpose",
  description: "Literature review",
  prompt: "Search and summarize neural architecture papers from 2023-2025"
})

Task({
  subagent_type: "general-purpose",
  description: "Data analysis",
  prompt: "Analyze performance metrics from benchmark datasets"
})

Task({
  subagent_type: "general-purpose",
  description: "Synthesis",
  prompt: "Combine findings into cohesive research summary"
})
```

### Fast Code Editing with Agent Booster

**Use agent_booster for 352x faster edits:**

```javascript
agent_booster_batch_edit({
  edits: [
    {
      target_filepath: "/path/to/file1.ts",
      instructions: "Add TypeScript types",
      code_edit: "// updated code with types"
    },
    {
      target_filepath: "/path/to/file2.ts",
      instructions: "Fix error handling",
      code_edit: "// updated error handling"
    }
  ]
})
```

### Memory Pattern Storage

**Store successful approaches for future retrieval:**

```javascript
agentdb_pattern_store({
  sessionId: "session-2025-12-04",
  task: "Implemented authentication system",
  reward: 0.95,
  success: true,
  critique: "Well-structured approach, tests passed, good error handling"
})
```

---

## Best Practices

### ✅ DO
- Use Task tool for spawning workers/agents
- Use AgentDB to store successful reasoning patterns
- Use agent_booster for ultra-fast code edits (352x faster)
- Use Claude Code tools (Read/Write/Edit) for all file operations
- Store patterns after completing significant work

### ❌ DON'T
- Use `mcp__claude-flow__swarm_init` (DENIED)
- Use `mcp__claude-flow__agent_spawn` (DENIED)
- Use `mcp__claude-flow__agentic_flow_agent` (DENIED - requires API keys)
- Try to use MCP tools for file operations (use Claude Code tools)
- Forget to store successful patterns in AgentDB

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
