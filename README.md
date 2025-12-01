# Codebuild - Claude Code Unified Environment

> **Last Updated:** 2025-11-30
> **Maintainer:** AI Enablement Academy

## Overview

This is the unified Claude Code development environment for the AI Enablement Academy. It provides multiple Claude Code variants, each configured for different API providers and orchestration capabilities.

## Quick Start

```bash
# After opening a new terminal, see all available commands:
claude-env

# Standard Claude Code (Anthropic)
claude

# Z.AI GLM Models
claude-zai

# Claude + Agentic Flow orchestration
claude-flow

# Z.AI + Full Agent Suite (recommended for complex tasks)
claude-zai-agent-flow
```

## Available Commands

| Command | Alias | API Provider | Orchestration | Use Case |
|---------|-------|--------------|---------------|----------|
| `claude` | - | Anthropic | None | Standard development |
| `claude-zai` | `czai` | Z.AI (GLM) | None | Cost-effective development |
| `claude-flow` | `cflow` | Anthropic | agentic-flow | Complex multi-agent tasks |
| `claude-zai-flow` | `czf` | Z.AI (GLM) | agentic-flow | Cost-effective orchestration |
| `claude-zai-agent-flow` | `czaf` | Z.AI (GLM) | Full MCP Suite | Maximum capabilities |

### Utility Commands

| Command | Description |
|---------|-------------|
| `claude-reset` | Reset all Claude environment variables |
| `claude-env` | Display help and available commands |

## Architecture

```
codebuild/
├── .env                          # Universal environment configuration (API keys)
├── .claude/
│   ├── settings.json             # Universal settings (hooks, permissions)
│   ├── mcp.json                  # Universal MCP server configuration (15 servers)
│   ├── agents/                   # Agent definitions
│   ├── commands/                 # Slash commands
│   ├── hooks/                    # Hook scripts
│   ├── skills/                   # Skill definitions
│   └── helpers/                  # Helper scripts
│
├── claude-zai/                   # Z.AI basic scaffolding (49 agents, 40 skills)
├── claude-zai-flow/              # Z.AI + Flow scaffolding
├── claude-zai-agent-flow/        # Z.AI + Full Agent Suite
├── claude-flow/                  # Anthropic + Flow scaffolding
├── claude-code/                  # Basic Anthropic scaffolding
│
├── project-campfire/             # Main active project (monorepo)
├── codex-sandbox/                # Sandbox environment + Docmost wiki
├── codex-subagents-mcp/          # MCP server for subagent delegation
├── codex-cli-subagents/          # CLI subagent definitions
├── mcp-servers/                  # Custom MCP server implementations
│
├── universal-skills/             # Shared skill library
├── universal-agents/             # Shared agent library
├── skills-to-agents/             # Skill-to-agent conversion tools
│
├── docs/                         # Documentation
├── CLAUDE-ENVIRONMENTS.md        # Detailed environment documentation
└── README.md                     # This file
```

## MCP Servers (15 Total)

All Claude variants have access to these MCP servers via the unified `mcp.json`:

### Orchestration Servers
| Server | Description | Type |
|--------|-------------|------|
| `claude-flow` | Agentic Flow orchestration | stdio |
| `claude-flow-alpha` | Alpha features | stdio |
| `ruv-swarm` | Swarm coordination | stdio |
| `flow-nexus` | Advanced nexus features | stdio |

### Infrastructure Servers
| Server | Description | Type |
|--------|-------------|------|
| `supabase` | Database operations | stdio |
| `digitalocean-mcp` | Droplets & Apps management | stdio |
| `vercel` | Deployment tools | stdio |

### AI & Vision Servers
| Server | Description | Type |
|--------|-------------|------|
| `zai-mcp-server` | Z.AI vision/tools | stdio |
| `zai-search` | Z.AI web search | http |
| `context7` | Context management | stdio |

### Knowledge & Task Management
| Server | Description | Type |
|--------|-------------|------|
| `cortex` | SiYuan knowledge base | stdio |
| `nocodb-base-ops` | Task & sprint management | stdio |
| `codex-subagents` | Sub-agent delegation | stdio |

### Development Servers
| Server | Description | Type |
|--------|-------------|------|
| `playwright` | Browser automation | stdio |
| `svelte` | Svelte framework tools | stdio |

## Environment Variables

The universal `.env` file contains all API keys:

### API Keys Configured
- **Z_AI_API_KEY** - Z.AI GLM models (primary)
- **Z_AI_VISION_KEY** - Z.AI vision capabilities
- **Z_AI_SEARCH_KEY** - Z.AI web search
- **ANTHROPIC_API_KEY** - Anthropic Claude
- **OPENAI_API_KEY** - OpenAI GPT models
- **SUPABASE_ACCESS_TOKEN** - Supabase database
- **DIGITALOCEAN_API_TOKEN** - DigitalOcean infrastructure
- **NOCODB_MCP_TOKEN** - NocoDB task management
- **CORTEX credentials** - SiYuan knowledge base

### Z.AI Model Mappings
| Anthropic Model | Z.AI Equivalent |
|-----------------|-----------------|
| Claude Opus | GLM-4.6 |
| Claude Sonnet | GLM-4.6 |
| Claude Haiku | GLM-4.5-Air |

## Agents & Skills (Standardized Across ALL Variants)

All Claude variants now share the same agents and skills via symlinks:

### Unified Skills (67 total)
All variants have access to 67 skills via symlinks to `claude-zai/.claude/skills/`:
| Category | Count | Examples |
|----------|-------|----------|
| Infrastructure | 12 | docker-deploy, health-monitor, doc-platform-backup |
| Agentic/Flow | 15 | swarm-orchestration, hive-mind-advanced, flow-nexus-* |
| GitHub | 5 | github-code-review, github-workflow-automation |
| Creative | 5 | image-variant, video-generate, asset-approval |
| Product | 4 | product-sparc, product-prd, product-bmad |
| AgentDB | 5 | agentdb-advanced, agentdb-learning |
| Business Ops | 21 | campaign-launch, marketing-brief, cortex-task-log |

### Unified Agents (71+ total)
All variants have access to:
- **Base Agents (51)**: Located in `claude-zai/.claude/agents/`
  - cortex-ops, task-orchestrator, code-reviewer, oci-operations, and more
- **Research Agents (9)**: Located in `universal-agents/business-research/`
  - strategic-researcher, pattern-analyst, positioning-strategist, etc.
- **USACF Agents (13)**: Located in `universal-agents/usacf/`
  - USACF orchestrator, adversarial-reviewer, meta-learning-orchestrator, etc.

### Variant Capabilities
| Variant | Skills | Agents | Research |
|---------|--------|--------|----------|
| claude-code | 67 | 51 + 22 | ✅ |
| claude-zai | 67 | 51 + 22 | ✅ |
| claude-flow | 67 | 51 + 22 | ✅ |
| claude-zai-flow | 67 | 51 + 22 | ✅ |
| claude-zai-agent-flow | 67 | 51 + 22 | ✅ |

## Agentic Flow Features

When using `claude-flow`, `claude-zai-flow`, or `claude-zai-agent-flow`:

### Swarm Orchestration
```javascript
// Initialize a swarm
mcp__claude-flow__swarm_init({ topology: "hierarchical", maxAgents: 20 })

// Spawn agents
mcp__claude-flow__agent_spawn({ type: "researcher", name: "Analyst" })

// Orchestrate tasks
mcp__claude-flow__task_orchestrate({ task: "Build API", strategy: "parallel" })
```

### Memory Persistence
```javascript
// Store in memory
mcp__claude-flow__memory_usage({ action: "store", key: "project/data", value: "..." })

// Retrieve from memory
mcp__claude-flow__memory_usage({ action: "retrieve", key: "project/data" })
```

### Neural Patterns
```javascript
// Analyze patterns
mcp__claude-flow__neural_patterns({ action: "analyze" })

// Train patterns
mcp__claude-flow__neural_train({ pattern_type: "coordination", training_data: "..." })
```

## Knowledge Management

### Cortex (SiYuan) - Infrastructure & Codebase
- **URL**: https://cortex.aienablement.academy
- **Purpose**: Infrastructure documentation, codebase knowledge, learnings
- **Access**: Via cortex MCP server

### Docmost - Business Wiki
- **Location**: `codex-sandbox/docmost/`
- **Purpose**: Business documentation, processes, procedures
- **Status**: Self-hosted

### NocoDB - Task Management
- **Purpose**: ALL task tracking, sprint planning, time logging
- **Database**: OPS (`pz7wdven8yqgx3r`)
- **Tables**: TASKS, SPRINTS
- **Assignee**: claude-code@aienablement.academy

## GitHub Organization

**Organization**: [AI-Enablement-Academy](https://github.com/orgs/AI-Enablement-Academy/)

### Private Repositories (8)
| Repository | Description | Last Updated |
|------------|-------------|--------------|
| project-campfire | Main learning platform | 2025-11-30 |
| enablement-academy-face | Frontend application | 2025-11-28 |
| infrastructure | Infrastructure configs | 2025-10-24 |
| ops-backup | Backup scripts & timers | 2025-10-24 |
| ops-docmost-exporter | Docmost markdown exporter | 2025-10-24 |
| monitoring-stack | Metrics, Kuma, Dozzle | 2025-10-24 |
| ops-dashboard | Ops dashboard service | 2025-10-24 |
| ops-dashboard-actions | CI workflows | 2025-10-24 |

## Hooks System

Pre-configured hooks in `settings.json`:

### Pre-Tool Hooks
- **Bash**: Validates safety, prepares resources
- **Write/Edit**: Auto-assigns agents, loads context

### Post-Tool Hooks
- **Bash**: Tracks metrics, stores results
- **Write/Edit**: Formats code, trains neural patterns, updates memory

### Session Hooks
- **Stop**: Generates summary, persists state, exports metrics

## Workflow Protocol

### Mandatory Workflow
1. **Plan**: Create tasks in NocoDB first
2. **Execute**: Do work using Claude Code
3. **Document**: Store knowledge in Cortex
4. **Link**: Connect NocoDB tasks to Cortex docs
5. **Repeat**: No work outside this system

### Critical Rules
- ALL tasks logged in NocoDB with assignee `claude-code@aienablement.academy`
- ALL knowledge stored in Cortex (not local files)
- ALL tasks assigned to sprints based on due dates
- Use pnpm ONLY (npm/yarn denied in permissions)

## Troubleshooting

### Environment Not Loading
```bash
source ~/.zshrc
claude-env  # Verify configuration
```

### MCP Servers Not Available
```bash
which pnpm  # Ensure pnpm installed
cat ~/Documents/codebuild/.claude/mcp.json  # Verify config
```

### Z.AI Models Not Working
```bash
echo $Z_AI_API_KEY  # Verify key set
claude-reset  # Reset environment
```

### Cortex Connection Issues
- Check if SiYuan is running
- Verify Cloudflare tunnel active
- Check cortex-mcp.sh script

## Adding New Variants

1. Create folder: `codebuild/claude-new-variant/`
2. Create `.claude/` directory inside
3. Symlink MCP: `ln -s ../../../.claude/mcp.json .claude/mcp.json`
4. Create `settings.json` with specific settings
5. Add shell function in `~/.zshrc`

## Migration Notes (2025-11-30)

- Migrated from npm to pnpm (ONLY use pnpm)
- Migrated to agentic-flow orchestration
- Created universal .env (single source of truth)
- Standardized MCP configs via symlinks
- Added claude-zai-agent-flow variant
- Full audit completed with 20-agent swarm

---

**Documentation**: See `CLAUDE-ENVIRONMENTS.md` for detailed technical reference.

**Support**: Create task in NocoDB OPS database or document in Cortex.
