# Claude Code Asset Index

> **Central registry of all skills, agents, hooks, commands, and helpers in `/codebuild`**
>
> Last updated: 2025-12-02
>
> ✅ **Validated by 10-agent swarm audit**

## Quick Stats

| Category | Count | Location |
|----------|-------|----------|
| **Skills** | 66 | `.claude/skills/` |
| **Hooks** | 39 | `.claude/hooks/` |
| **Commands** | 14 (top-level) | `.claude/commands/` |
| **Agents** | 4 | `.claude/agents/` |
| **Helpers** | 6 | `.claude/helpers/` |
| **Docs** | 10 | `.claude/docs/` |

---

## 🎯 Skills (66)

Skills are invoked via the `Skill` tool. Each has a `SKILL.md` defining its behavior.

### Memory & Data
| Skill | Description |
|-------|-------------|
| `memory-sync` | Unified memory sync across 6 backends |
| `agentdb-advanced` | Advanced AgentDB features |
| `agentdb-learning` | AI learning with reinforcement algorithms |
| `agentdb-memory-patterns` | Persistent memory patterns for agents |
| `agentdb-optimization` | AgentDB performance optimization |
| `agentdb-vector-search` | Semantic vector search with AgentDB |
| `reasoningbank-agentdb` | ReasoningBank adaptive learning |
| `reasoningbank-intelligence` | Pattern recognition and optimization |
| `ruvector-development` | Vector database for semantic search |

### Infrastructure & DevOps
| Skill | Description |
|-------|-------------|
| `brevo-email` | Brevo email marketing integration |
| `cloudflare-dns` | Cloudflare DNS management |
| `digitalocean-infrastructure` | DigitalOcean infrastructure |
| `oci-server` | Oracle Cloud Infrastructure |
| `vercel-deployment` | Vercel deployment automation |
| `vercel-domains` | Vercel domain management |
| `vercel-environment` | Vercel environment variables |
| `calcom-selfhosted` | Cal.com self-hosted deployment |

### AI & Agents
| Skill | Description |
|-------|-------------|
| `agentic-jujutsu` | Quantum-resistant version control for AI |
| `codex-subagents` | Codex subagent orchestration |
| `flow-nexus-neural` | Neural networks in distributed sandboxes |
| `flow-nexus-platform` | Flow Nexus platform management |
| `flow-nexus-swarm` | Cloud-based AI swarm deployment |
| `hive-mind-advanced` | Queen-led multi-agent coordination |
| `hooks-automation` | Intelligent hooks with MCP integration |
| `pair-programming` | AI-assisted pair programming |
| `performance-analysis` | Swarm performance analysis |
| `ruv-swarm-operations` | Swarm operation management |
| `swarm-advanced` | Advanced swarm features |
| `swarm-orchestration` | Multi-agent swarm orchestration |

### GitHub Integration
| Skill | Description |
|-------|-------------|
| `github-code-review` | AI-powered code review |
| `github-multi-repo` | Multi-repository coordination |
| `github-project-management` | Project board automation |
| `github-release-management` | Release orchestration |
| `github-workflow-automation` | GitHub Actions automation |

### Product & Business
| Skill | Description |
|-------|-------------|
| `academy-brand-design` | AI Enablement Academy branding |
| `competitive-ads-extractor` | Competitor ad analysis |
| `content-research-writer` | Content research and writing |
| `developer-growth-analysis` | Developer growth metrics |
| `domain-name-brainstormer` | Domain name generation |
| `gtm-sales-proposals` | GTM sales proposal development |
| `lead-research-assistant` | Lead research automation |
| `learning-science-design` | Evidence-based instructional design |
| `sparc-methodology` | SPARC narrative framework |

### Documents & Media
| Skill | Description |
|-------|-------------|
| `pdf` | PDF processing and analysis |
| `xlsx` | Excel file operations |
| `docx` | Word document operations |
| `pptx` | PowerPoint operations |
| `image-enhancer` | AI image enhancement |
| `video-downloader` | Video download and processing |
| `zai-vision` | Z.AI vision analysis |
| `canvas-design` | Canvas/visual design |

### Development Tools
| Skill | Description |
|-------|-------------|
| `shadcn-components` | shadcn/ui component management |
| `svelte-framework` | Svelte framework patterns |
| `changelog-generator` | Changelog generation |
| `mcp-builder` | MCP server builder |
| `skill-builder` | Skill creation wizard |
| `skill-creator` | Alternative skill creator |
| `verification-quality` | Code verification and QA |
| `standard-ops` | Standard operations |
| `stream-chain` | Stream processing chains |
| `progressive-disclosure` | Progressive disclosure patterns |

### Finance & Payments
| Skill | Description |
|-------|-------------|
| `stripe-payments` | Stripe payment integration |

### Utilities
| Skill | Description |
|-------|-------------|
| `file-organizer` | File organization automation |
| `internal-comms` | Internal communications |
| `invoice-organizer` | Invoice organization |
| `meeting-insights-analyzer` | Meeting transcript analysis |

---

## 🪝 Hooks (39)

Hooks are triggered automatically by Claude Code events.

### Memory Hooks
| Hook | Trigger | Description |
|------|---------|-------------|
| `pre-task-memory-lookup` | UserPromptSubmit | Search all 6 memory backends |
| `incremental-memory-sync` | PostToolUse | Sync every 30 calls or 5 min |
| `emergency-memory-flush` | Manual | Full sync before data loss |
| `memory-orchestrator` | Various | Unified 3-layer memory chain |
| `memory-search` | Manual | Search memory stores |
| `memory-store` | Manual | Store to memory |
| `memory-sync-hook` | PostToolUse | Auto-sync on pattern storage |
| `memory-to-learnings-bridge` | PostToolUse | Bridge memory to learnings |
| `agentdb-supabase-sync` | Stop | Sync AgentDB to Supabase |
| `index-new-episode` | PostToolUse | Index episodes for embeddings |
| `sync-memory-to-supabase` | Stop | Sync memory to Supabase |
| `semantic-search` | Manual | Keyword search across all backends |

### Cortex Hooks
| Hook | Trigger | Description |
|------|---------|-------------|
| `cortex-create-doc` | Manual | Create Cortex documents |
| `cortex-health-check` | Manual | Quick health assessment |
| `cortex-learning-capture` | Manual | Store learnings in KB |
| `cortex-link-creator` | Manual | Create bidirectional links |
| `cortex-log-learning` | Manual | Log learnings to Cortex |
| `cortex-post-task` | PostToolUse | Log completed work |
| `cortex-template-create` | Manual | Create from templates |

### Task Lifecycle
| Hook | Trigger | Description |
|------|---------|-------------|
| `pre-task` | UserPromptSubmit | Load context, prepare work |
| `post-task` | Stop | Persist learnings, update tracker |
| `session-start` | Start | Initialize session |
| `session-end` | Stop | Persist state, sync memory |
| `session-end-sync` | Stop | Full sync on session end |
| `session-lock` | Start/Stop | Prevent parallel conflicts |

### Learning & Patterns
| Hook | Trigger | Description |
|------|---------|-------------|
| `log-learning` | Manual | Capture learnings with dedup |
| `save-pattern` | Manual | Store successful solutions |
| `extract-learnings-from-findings` | Manual | Extract from session |
| `check-existing-solution` | PreToolUse | Look for existing patterns |

### Search & Cache
| Hook | Trigger | Description |
|------|---------|-------------|
| `pre-search` | PreToolUse | Check cached searches |
| `post-search` | PostToolUse | Cache search results |

### NocoDB Integration
| Hook | Trigger | Description |
|------|---------|-------------|
| `nocodb-create-task` | Manual | Create NocoDB task |
| `nocodb-update-status` | Manual | Update task status |

### Error & Logging
| Hook | Trigger | Description |
|------|---------|-------------|
| `post-error` | Notification | Log errors with resolutions |
| `log-action` | PostToolUse | Track individual actions |
| `detect-agent` | Start | Detect Claude agent variant |

### External Services
| Hook | Trigger | Description |
|------|---------|-------------|
| `stripe-webhook-monitor` | Manual | Monitor Stripe webhooks |
| `vercel-deployment-hook` | Manual | Vercel deployment trigger |

---

## ⚡ Commands (14)

Slash commands available via `/command-name`.

| Command | Description |
|---------|-------------|
| `/cortex-export` | Export Cortex documents |
| `/cortex-fix-orphans` | Fix orphaned Cortex links |
| `/cortex-search` | Search Cortex knowledge base |
| `/memory-stats` | Show memory statistics |
| `/memory-sync` | Full memory sync |
| `/shadcn-add` | Add shadcn/ui components |
| `/shadcn-check` | Check shadcn setup |
| `/stripe-balance` | Check Stripe balance |
| `/stripe-test-webhook` | Test Stripe webhooks |
| `/sync-agentdb` | Sync AgentDB manually |
| `/vercel-deploy` | Deploy to Vercel |
| `/vercel-env` | Manage Vercel env vars |
| `/vercel-logs` | View Vercel logs |
| `/vercel-status` | Check Vercel status |

---

## 🤖 Agents (4)

Custom agent definitions in `.claude/agents/`.

| Agent | Category | Description |
|-------|----------|-------------|
| `cloudflare-dns` | core | Cloudflare DNS operations |
| `cortex-ops` | core | Cortex knowledge management |
| `vercel-ops` | core | Vercel deployment operations |
| `stripe-ops` | integrations | Stripe payment operations |

### Agent Directories (Empty/Placeholder)
- `analysis/`, `architecture/`, `consensus/`, `data/`
- `development/`, `devops/`, `documentation/`
- `flow-nexus/`, `github/`, `hive-mind/`
- `optimization/`, `sparc/`, `specialized/`
- `swarm/`, `templates/`, `testing/`

### Symlinked Agents
- `research` → `../../universal-agents/business-research`
- `usacf` → `../../universal-agents/usacf`

---

## 🔧 Helpers (6)

Utility scripts in `.claude/helpers/`.

| Helper | Description |
|--------|-------------|
| `checkpoint-manager.sh` | Manage session checkpoints |
| `github-safe.js` | Safe GitHub CLI helper (prevents timeout issues) |
| `github-setup.sh` | GitHub configuration setup |
| `quick-start.sh` | Quick project setup |
| `setup-mcp.sh` | MCP server setup |
| `standard-checkpoint-hooks.sh` | Standard checkpoint hook runners |

---

## 📚 Documentation (10)

Reference docs in `.claude/docs/`.

| Document | Description |
|----------|-------------|
| `ASSET-INDEX.md` | This file - central asset registry |
| `CONTINUOUS-IMPROVEMENT.md` | Improvement processes |
| `CORTEX-API-OPS.md` | Cortex API operations reference |
| `CORTEX-IMPROVEMENT-PLAN.md` | Cortex enhancement plan |
| `CORTEX-PROGRESSIVE-DISCLOSURE.md` | Progressive disclosure patterns for Cortex |
| `CORTEX-SYNC-REPORT-2025-12-01.md` | Sync report |
| `MEMORY-SOP.md` | Memory system SOP |
| `PROGRESSIVE-DISCLOSURE.md` | Progressive disclosure patterns |
| `PROJECT-INVENTORY.md` | Project inventory |
| `TOOL-REFERENCE.md` | Tool reference guide |

---

## 📁 Directory Structure

```
.claude/
├── agents/          # Custom agent definitions (4)
│   ├── core/        # Core operational agents
│   └── integrations/# External service agents
├── commands/        # Slash commands (14 top-level, 89 total)
├── docs/            # Documentation (8)
├── helpers/         # Utility scripts (6)
├── hooks/           # Event hooks (39)
├── skills/          # Skills with SKILL.md (66)
│   └── */scripts/   # Skill-specific scripts
├── settings.json    # Hook configurations
└── mcp.json         # MCP server configurations
```

---

## ✅ Cleanup Status (2025-12-02)

| File | Status | Action Taken |
|------|--------|--------------|
| `statusline-command.sh` | ✅ Keep | Referenced by settings.json |
| `cortex-api-ops.md` | ✅ Moved | Now in `docs/CORTEX-API-OPS.md` |
| `cortex-progressive-disclosure.md` | ✅ Moved | Now in `docs/CORTEX-PROGRESSIVE-DISCLOSURE.md` |
| `mcp-full-backup.json` | ✅ Deleted | Backup no longer needed |
| `mcp-lean.json` | ⚠️ Review | Alternative config, keep for now |

---

## 🔗 Related Files

| File | Location | Purpose |
|------|----------|---------|
| `CLAUDE.md` | `/codebuild/` | Main instructions |
| `CLAUDE.md` | `/project-campfire/` | Project-specific |
| `.env` | `/codebuild/` | Environment variables |
| `agentdb.db` | `/codebuild/` | Local episode storage |
| `.swarm/memory.db` | `/codebuild/` | Swarm memory |

---

*Generated: 2025-12-03 | Update with: Review asset changes*
