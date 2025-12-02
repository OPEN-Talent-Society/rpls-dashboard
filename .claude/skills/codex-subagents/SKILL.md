---
name: codex-subagents
description: Codex subagent delegation system for running named sub-agents with custom personas and profiles. Load on-demand for specialized agent delegation.
category: orchestration
tags: [agents, delegation, personas, subagents]
version: 1.0.0
mcp_install: |
  claude mcp add codex-subagents /opt/homebrew/bin/node /Users/adamkovacs/Documents/codebuild/mcp-servers/codex-subagents-mcp/dist/codex-subagents.mcp.js --agents-dir /Users/adamkovacs/Documents/codebuild/mcp-servers/codex-subagents-mcp/agents
---

# Codex Subagents

Delegate tasks to specialized sub-agents running as clean Codex exec processes with custom personas and profiles. This is an on-demand skill - load only when you need specialized agent delegation.

## When to Use

Load this skill when you need:
- **Named sub-agents** with specific personas
- **Custom execution profiles** for different task types
- **Isolated agent environments** (sandbox modes)
- **Batch delegation** to multiple agents

## Installation (On-Demand)

```bash
# Add MCP server
claude mcp add codex-subagents /opt/homebrew/bin/node \
  /Users/adamkovacs/Documents/codebuild/mcp-servers/codex-subagents-mcp/dist/codex-subagents.mcp.js \
  --agents-dir /Users/adamkovacs/Documents/codebuild/mcp-servers/codex-subagents-mcp/agents

# Remove when done
claude mcp remove codex-subagents
```

## Core Tools

### 1. Delegate to Sub-Agent

```javascript
mcp__codex-subagents__delegate({
  agent: "researcher",
  task: "Research best practices for API rate limiting",
  persona: "senior-engineer",
  profile: "research",
  sandbox_mode: "read-only", // read-only, workspace-write, danger-full-access
  approval_policy: "on-failure" // never, on-request, on-failure, untrusted
})
```

### 2. Batch Delegation

```javascript
mcp__codex-subagents__delegate_batch({
  agent: "coder",
  task: "Implement utility functions for data transformation",
  sandbox_mode: "workspace-write",
  mirror_repo: true
})
```

### 3. List Available Agents

```javascript
mcp__codex-subagents__list_agents({})
```

### 4. Validate Agent Files

```javascript
mcp__codex-subagents__validate_agents({
  dir: "/path/to/custom/agents"
})
```

## Agent Configuration

Agents are defined in the agents directory with their capabilities and personas.

### Sandbox Modes

| Mode | Description |
|------|-------------|
| `read-only` | Can only read files, no modifications |
| `workspace-write` | Can write within workspace |
| `danger-full-access` | Full system access (use with caution) |

### Approval Policies

| Policy | Description |
|--------|-------------|
| `never` | No approval required |
| `on-request` | Approval only when agent requests |
| `on-failure` | Approval required after failures |
| `untrusted` | Approval for all operations |

## Example Workflows

### Research Task

```javascript
mcp__codex-subagents__delegate({
  agent: "researcher",
  task: "Analyze competitor API designs and summarize patterns",
  sandbox_mode: "read-only",
  approval_policy: "never"
})
```

### Code Generation

```javascript
mcp__codex-subagents__delegate({
  agent: "coder",
  task: "Generate TypeScript utility functions for date handling",
  sandbox_mode: "workspace-write",
  approval_policy: "on-failure",
  mirror_repo: true
})
```

### Security Review

```javascript
mcp__codex-subagents__delegate({
  agent: "security-reviewer",
  task: "Review authentication implementation for vulnerabilities",
  sandbox_mode: "read-only",
  approval_policy: "untrusted"
})
```

## Alternative: Claude Code Task Tool

For most use cases, prefer Claude Code's built-in Task tool with subagent_type:

```javascript
Task({
  description: "Research task",
  prompt: "Research best practices...",
  subagent_type: "Explore" // or other built-in types
})
```

Codex subagents are for when you need:
- Custom personas not available in built-in agents
- Specific sandbox isolation requirements
- Batch processing across multiple agents
- Custom agent configurations

## Removal

```bash
claude mcp remove codex-subagents
```

---

*Skill: codex-subagents | Version: 1.0.0 | Status: On-demand*
