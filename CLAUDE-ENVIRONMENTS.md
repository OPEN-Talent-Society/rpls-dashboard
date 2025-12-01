# Claude Code Unified Environment

## Overview

This document describes the unified Claude Code environment setup for the codebuild workspace.

**Last Updated:** 2025-11-30

## Quick Start

After opening a new terminal, run `claude-env` to see all available commands.

### Available Commands

| Command | Description | API Provider | Orchestration |
|---------|-------------|--------------|---------------|
| `claude` | Standard Claude Code | Anthropic | None |
| `claude-zai` | Z.AI GLM Models | Z.AI | None |
| `claude-flow` | Claude + Flow | Anthropic | agentic-flow |
| `claude-zai-flow` | Z.AI + Flow | Z.AI | agentic-flow |
| `claude-zai-agent-flow` | Z.AI + Full Agent Suite | Z.AI | agentic-flow + MCP |

### Short Aliases

| Alias | Full Command |
|-------|--------------|
| `czai` | `claude-zai` |
| `czaf` | `claude-zai-agent-flow` |
| `cflow` | `claude-flow` |
| `czf` | `claude-zai-flow` |

### Utility Commands

| Command | Description |
|---------|-------------|
| `claude-reset` | Reset all Claude environment variables |
| `claude-env` | Display help and available commands |

## Architecture

```
codebuild/
├── .env                    # Universal environment configuration
├── .claude/
│   ├── settings.json       # Universal settings (hooks, permissions)
│   └── mcp.json           # Universal MCP server configuration
├── claude-zai/            # Z.AI basic scaffolding
├── claude-zai-flow/       # Z.AI + Flow scaffolding
├── claude-zai-agent-flow/ # Z.AI + Full Agent Suite
├── claude-flow/           # Anthropic + Flow scaffolding
├── claude-code/           # Basic Anthropic scaffolding
└── project-campfire/      # Main project (uses parent configs)
```

## Universal .env Configuration

All Claude Code variants share a single `.env` file at `~/Documents/codebuild/.env`:

### API Keys Configured

- **Z.AI** - GLM models via Anthropic-compatible API
- **OpenAI** - GPT models
- **Supabase** - Database operations
- **DigitalOcean** - Infrastructure
- **NocoDB** - Task management
- **Cortex** - Knowledge management
- **Vercel** - Deployment

### Model Mappings (Z.AI)

| Anthropic Model | Z.AI Equivalent |
|-----------------|-----------------|
| Claude Opus | GLM-4.6 |
| Claude Sonnet | GLM-4.6 |
| Claude Haiku | GLM-4.5-Air |

## MCP Servers

All variants have access to these MCP servers:

| Server | Description | Type |
|--------|-------------|------|
| claude-flow | Agentic Flow orchestration | stdio |
| claude-flow-alpha | Alpha features | stdio |
| ruv-swarm | Swarm coordination | stdio |
| flow-nexus | Advanced nexus features | stdio |
| supabase | Database operations | stdio |
| context7 | Context management | stdio |
| digitalocean-mcp | Infrastructure | stdio |
| playwright | Browser automation | stdio |
| zai-mcp-server | Z.AI vision/tools | stdio |
| zai-search | Z.AI web search | http |
| nocodb-base-ops | Task management | stdio |
| cortex | Knowledge management | stdio |
| codex-subagents | Sub-agent delegation | stdio |
| svelte | Svelte framework tools | stdio |
| vercel | Deployment tools | stdio |

## Shell Configuration

The shell functions in `~/.zshrc` automatically:

1. Source the universal `.env` from codebuild
2. Set up the correct API provider (Anthropic or Z.AI)
3. Navigate to the appropriate workspace folder
4. Configure model mappings for Z.AI variants

### How It Works

```bash
# Helper function for Z.AI setup
_setup_zai_env() {
    export ANTHROPIC_BASE_URL="${Z_AI_BASE_URL}"
    export ANTHROPIC_AUTH_TOKEN="${Z_AI_API_KEY}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${Z_AI_SONNET_MODEL}"
    # ... etc
}

# Each command calls the helper
claude-zai-agent-flow() {
    _setup_zai_env
    cd ~/Documents/codebuild/claude-zai-agent-flow
    command claude "$@"
}
```

## Troubleshooting

### Environment Not Loading

1. Run `source ~/.zshrc` to reload shell configuration
2. Check that `~/Documents/codebuild/.env` exists
3. Run `claude-env` to verify configuration

### MCP Servers Not Available

1. Ensure `pnpm` is installed: `which pnpm`
2. Check that `PNPM_HOME` is in PATH
3. Verify MCP config: `cat ~/Documents/codebuild/.claude/mcp.json`

### Z.AI Models Not Working

1. Verify Z_AI_API_KEY is set: `echo $Z_AI_API_KEY`
2. Check Z_AI_BASE_URL is correct: `echo $Z_AI_BASE_URL`
3. Try `claude-reset` then re-run the Z.AI command

## Adding New Configurations

To add a new Claude variant:

1. Create a new folder in codebuild (e.g., `claude-new-variant/`)
2. Create `.claude/` directory inside
3. Symlink the MCP config: `ln -s ../../../.claude/mcp.json .claude/mcp.json`
4. Create `settings.json` with specific settings
5. Add a shell function in `~/.zshrc`

## Migration Notes (2025-11-30)

- Migrated from npm to pnpm (ONLY use pnpm)
- Migrated from claude-flow@alpha to agentic-flow
- Created universal .env (replaces scattered env files)
- Standardized MCP configs via symlinks
- Added claude-zai-agent-flow variant
