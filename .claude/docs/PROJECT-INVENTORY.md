# Codebuild Project Inventory

**Last Updated**: 2025-11-30
**Author**: claude-code@aienablement.academy

---

## Infrastructure Overview

### Master Claude Configuration
**Location**: `/Users/adamkovacs/Documents/codebuild/.claude/`

| Component | Count | Description |
|-----------|-------|-------------|
| Skills | 32 | Master skill library |
| Hooks | 18 | Automation hooks |
| Templates | 5 | Document/task templates |
| Docs | 3 | Core documentation |
| Config | 1 | agents.json |

### Claude Variants (5 total)

Each variant has its OWN `.claude/` directory with 72 skills (copies, not symlinks).

| Variant | Email | Role | Skills |
|---------|-------|------|--------|
| claude-code | claude-code@aienablement.academy | developer | 72 |
| claude-flow | claude-flow@aienablement.academy | orchestrator | 72 |
| claude-zai | claude-zai@aienablement.academy | intelligence | 72 |
| claude-zai-flow | claude-zai-flow@aienablement.academy | hybrid | 72 |
| claude-zai-agent-flow | agent-flow@aienablement.academy | multi-agent | 72 |

### Symlinked Components (to master)
- `config/` → shared agent configuration
- `docs/` → shared documentation
- `hooks/` → shared automation hooks
- `templates/` → shared templates
- `mcp.json` → shared MCP configuration

---

## Projects with .claude Setups

### 1. codebuild (Master)
- **Path**: `/Users/adamkovacs/Documents/codebuild/`
- **Type**: SvelteKit monorepo
- **Package Manager**: npm
- **.claude**: Master configuration (32 skills, 18 hooks)
- **Purpose**: Main development environment

### 2. project-campfire
- **Path**: `/Users/adamkovacs/Documents/codebuild/project-campfire/`
- **Type**: Turborepo monorepo (pnpm)
- **Name**: ai-enablement-academy
- **Apps**: cms, web
- **.claude**: Independent (27 skills, 17 agent categories)
- **Purpose**: AI Enablement Academy platform

### 3. codex-sandbox
- **Path**: `/Users/adamkovacs/Documents/codebuild/codex-sandbox/`
- **.claude**: Minimal (mcp.json only)
- **Purpose**: Sandbox environment for testing

---

## Application Projects

### Labor Market / Skills Domain

| Project | Path | Type | Package Manager | Purpose |
|---------|------|------|-----------------|---------|
| rpls-dashboard | `rpls-dashboard/` | SvelteKit | npm | Labor Market Intelligence Platform |
| openskills | `openskills/` | CLI/Library | npm | Universal skills loader for AI agents |
| universal-skills | `universal-skills/` | MCP Server/CLI | npm | Skills discovery and installation |
| skills-to-agents | `skills-to-agents/` | CLI/GitHub Action | npm | Sync Claude Skills into AGENTS.md |
| labor-market-pulse | `labor-market-pulse/` | Unknown | - | Labor market data |

### Web Applications

| Project | Path | Type | Package Manager | Purpose |
|---------|------|------|-----------------|---------|
| ttf-web | `ttf-web/` | Express/Vite | npm | TTF web application |
| ttf-web-nextjs | `ttf-web-nextjs/` | Next.js | npm | TTF Next.js version |
| frontend | `frontend/` | Unknown | npm | Frontend components |
| backend | `backend/` | Unknown | - | Backend services |
| taylormade | `taylormade/` | - | - | TaylorMade project (vendor/web) |

### MCP Servers

**Location**: `/Users/adamkovacs/Documents/codebuild/mcp-servers/`

| Server | Purpose |
|--------|---------|
| codex-subagents-mcp | Subagent delegation for Codex CLI |
| context7-mcp | Context7 integration |
| cortex | SiYuan/Cortex integration |
| github-mcp-server | GitHub operations |
| mcp-browser-use | Browser automation |
| mcp-server-git | Git operations |
| perplexity-mcp | Perplexity AI integration |
| porkbun-mcp-server | Domain management |

### Codex Integration

| Project | Path | Purpose |
|---------|------|---------|
| codex-subagents-mcp | `codex-subagents-mcp/` | MCP server for subagent delegation |
| codex-cli-subagents | `codex-cli-subagents/` | CLI subagent tools |
| codex-sandbox | `codex-sandbox/` | Testing sandbox |

### Agent Development

| Project | Path | Purpose |
|---------|------|---------|
| universal-agents | `universal-agents/` | Universal agent framework |
| universal-skills-mcp-tmp | `universal-skills-mcp-tmp/` | Skills MCP temporary |

---

## Master Skills Library (32 skills)

### AEA Skills (Academy)
- `academy-brand-design` - Brand design guidelines
- `gtm-sales-proposals` - GTM and sales proposal generation
- `learning-science-design` - Learning science principles

### AgentDB Skills
- `agentdb-advanced` - Advanced AgentDB operations
- `agentdb-learning` - Learning capture and retrieval
- `agentdb-memory-patterns` - Memory management patterns
- `agentdb-optimization` - AgentDB optimization
- `agentdb-vector-search` - Vector search operations

### Flow/Swarm Skills
- `flow-nexus-neural` - Neural network integration
- `flow-nexus-platform` - Platform operations
- `flow-nexus-swarm` - Swarm orchestration
- `hive-mind-advanced` - Hive mind operations
- `swarm-advanced` - Advanced swarm patterns
- `swarm-orchestration` - Basic swarm orchestration

### GitHub Skills
- `github-code-review` - Code review automation
- `github-multi-repo` - Multi-repo management
- `github-project-management` - Project management
- `github-release-management` - Release automation
- `github-workflow-automation` - Workflow automation

### Development Skills
- `agentic-jujutsu` - Agentic development patterns
- `hooks-automation` - Hook automation
- `pair-programming` - Pair programming patterns
- `performance-analysis` - Performance analysis
- `progressive-disclosure` - Context efficiency (NEW)
- `ruvector-development` - RUVector development
- `skill-builder` - Skill creation patterns
- `sparc-methodology` - SPARC development
- `standard-ops` - Standard operations
- `stream-chain` - Stream processing
- `verification-quality` - Quality verification

### Intelligence Skills
- `reasoningbank-agentdb` - ReasoningBank + AgentDB
- `reasoningbank-intelligence` - Intelligence operations

---

## Hooks Library (18 hooks)

### Pre-Operation Hooks
- `pre-search.sh` - Check cached searches before searching
- `pre-task.sh` - Pre-task setup and context loading

### Post-Operation Hooks
- `post-search.sh` - Cache search results
- `post-task.sh` - Post-task cleanup and logging
- `post-error.sh` - Error logging and prevention

### Session Hooks
- `session-start.sh` - Session initialization
- `session-end.sh` - Session cleanup and summary

### Memory/Learning Hooks
- `check-existing-solution.sh` - Check for existing patterns
- `save-pattern.sh` - Save successful solutions
- `log-learning.sh` - Log learnings with deduplication
- `memory-search.sh` - Search memory stores
- `memory-store.sh` - Store to memory

### Integration Hooks
- `log-action.sh` - Log actions
- `detect-agent.sh` - Detect agent identity
- `cortex-create-doc.sh` - Create Cortex documents
- `cortex-log-learning.sh` - Log learnings to Cortex
- `nocodb-create-task.sh` - Create NocoDB tasks
- `nocodb-update-status.sh` - Update NocoDB status

---

## Integration Systems

### NocoDB (Task Management)
- **Base ID**: `pz7wdven8yqgx3r`
- **Tasks Table**: `mmx3z4zxdj9ysfk`
- **Sprints Table**: `mtkfphwlmiv8mzp`
- **Default Assignee**: `uskfxdybo8kofowf` (claude-code)

### Cortex (Knowledge Management)
- **URL**: https://cortex.aienablement.academy
- **Token**: `0fkvtzw0jrat2oht`
- **Notebooks** (PARA methodology):
  - Projects: `20231114112233-projects`
  - Areas: `20231114112234-areas`
  - Resources: `20231114112235-resources`
  - Archives: `20231114112236-archives`
  - Agent Logs: `20231114112237-agent-logs`

### Memory Systems (ACTUAL STATUS)
- **Supabase Cloud DB**: ✅ Active (https://zxcrbcmdxpqprpxhsntc.supabase.co)
  - Tables: `agent_memory`, `learnings`, `patterns`
  - Region: us-east-2 | Status: ACTIVE_HEALTHY
  - Hooks updated to write automatically
- **File-based AgentDB**: ✅ Active (`.claude/.agentdb/learnings.json`, `.claude/.agentdb/patterns.json`)
- **Cortex/SiYuan**: ✅ Active (https://cortex.aienablement.academy)
- **Claude Flow Memory**: ⚠️ IN-MEMORY ONLY (not persistent across sessions)
- **NocoDB**: ⚠️ Requires MCP connection per session
- **RUVector/Synapse/ReasoningBank**: 📚 Skills only (no running services)

---

## Architecture Summary

```
codebuild/
├── .claude/                    # Master config (32 skills, 18 hooks)
│   ├── skills/                 # Skill definitions
│   ├── hooks/                  # Automation hooks
│   ├── templates/              # Document templates
│   ├── docs/                   # Documentation
│   └── config/                 # Agent configuration
├── claude-code/                # Variant 1 (72 skills)
│   └── .claude/ → symlinks + own skills
├── claude-flow/                # Variant 2 (72 skills)
│   └── .claude/ → symlinks + own skills
├── claude-zai/                 # Variant 3 (72 skills)
│   └── .claude/ → symlinks + own skills
├── claude-zai-flow/            # Variant 4 (72 skills)
│   └── .claude/ → symlinks + own skills
├── claude-zai-agent-flow/      # Variant 5 (72 skills)
│   └── .claude/ → symlinks + own skills
├── project-campfire/           # AEA Platform (27 skills, 17 agents)
│   └── .claude/ (independent)
├── mcp-servers/                # 8 MCP servers
└── [other projects]/           # No .claude setups
```

---

## Validation Checklist

- [x] All 5 variants have 72 skills each
- [x] Master has 32 skills
- [x] Master has 18 hooks
- [x] progressive-disclosure symlinked to all variants
- [x] agents.json has proper email mappings
- [x] NocoDB integration configured
- [x] Cortex integration configured
- [x] AEA skills present in all variants

---

#inventory #documentation #infrastructure #automated
