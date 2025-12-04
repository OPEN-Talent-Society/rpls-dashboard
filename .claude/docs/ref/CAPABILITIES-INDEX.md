# Capabilities Index

> Full reference for all available agents, skills, commands, hooks, and sync scripts.
> **Last Audit**: 2025-12-04 via Claude Flow Swarm

---

## TL;DR - What You Have Access To

**73 Custom Agents** in `.claude/agents/` - Domain specialists for infrastructure, business, DevOps, research
**72 Agentic-Flow Agents** via MCP - Swarm coordination, GitHub, consensus, optimization
**107 Skills** - Data processing, AI agents, cloud infra, dev tools, marketing, product
**85 Commands** - Memory, Cortex, Hive-Mind, GitHub, analysis, monitoring
**37 Hooks** - Session lifecycle, memory sync, task tracking, integrations
**16 Plugins** - Domain-specific bundles (finance, infrastructure, GTM, product)
**23 Sync Scripts** - Hot/cold memory sync, Qdrant indexing, unified search

**Quick Start**: Use `skill: "name"` for skills, `/command-name` for commands, agents auto-spawn via Task tool.

---

## Quick Summary

| Category | Count | Location | How to Use |
|----------|-------|----------|------------|
| **Custom Agents** | 73 | `.claude/agents/` | Specialized domain agents |
| **Agentic-Flow Agents** | 72 | MCP | `mcp__claude-flow__agentic_flow_list_agents` |
| **Skills** | 107 | `.claude/skills/` | `skill: "name"` |
| **Commands** | 85 | `.claude/commands/` | `/command-name` |
| **Hooks** | 37 | `.claude/hooks/` | Auto-run or `bash .claude/hooks/name.sh` |
| **Plugins** | 16 | `.claude/plugins/` | Domain-specific bundles |
| **Sync Scripts** | 23 | `.claude/skills/memory-sync/scripts/` | `bash script.sh` |

---

## Custom Agents (73 Total)

Located in `.claude/agents/` - project-specific domain agents.

### Core Agents (4)
| Agent | Purpose |
|-------|---------|
| **cortex-ops** | Cortex (SiYuan) knowledge management - PARA methodology |
| **cloudflare-dns** | Cloudflare DNS record management |
| **vercel-ops** | Vercel deployment and infrastructure |
| **stripe-ops** | Stripe payment processing, subscriptions |

### Operations Agents (20+)
| Agent | Purpose |
|-------|---------|
| **docker-operations** | Container lifecycle, orchestration, security |
| **dozzle-operations** | Container log monitoring and analysis |
| **netdata-operations** | System metrics and infrastructure observability |
| **local-ml-stack-ops** | On-prem ML stack (Whisper, Ollama, embeddings) |
| **moodle-admin** | Moodle LMS platform administration |
| **email-ops** | Transactional and marketing email workflows |
| **qdrant-ops** | Vector database deployment and backup |
| **ollama-orchestrator** | Ollama model lifecycle and prompt routing |
| **whisper-service-ops** | Speech-to-text pipelines and data handling |
| **nas-backup-admin** | QNAP NAS storage, snapshots, replication |
| **doc-platform-backup** | Docmost, NocoDB backup orchestration |
| **cortex-notebook-curation** | Cortex notebook structure and dashboards |

### Business & Marketing Agents (15+)
| Agent | Purpose |
|-------|---------|
| **marketing-orchestrator** | Multi-channel campaigns and analytics |
| **creative-director** | AI-generated assets and brand governance |
| **competitive-analyst** | Competitor monitoring and battlecards |
| **market-scanner** | Crunchbase, G2, social opportunity scanning |
| **crm-sync** | CRM pipeline data consistency |
| **contract-guardian** | Contract lifecycle and renewal alerts |
| **finance-compliance** | Finance controls and regulatory reporting |

### Product & Strategy Agents (10+)
| Agent | Purpose |
|-------|---------|
| **prd-facilitator** | PRD workflow - discovery, alignment, delivery |
| **spec-kit-strategist** | Spec Kit - scope slicing, delivery guardrails |
| **bmad-analyst** | BMAD assessment for product investments |
| **sparc-navigator** | SPARC framework for updates and briefings |

### Content & Media Agents (8+)
| Agent | Purpose |
|-------|---------|
| **video-producer** | AI video production (Sora/Veo/Runway) |
| **image-curator** | AI-generated imagery curation |
| **audio-editor** | Audio production and transcription |
| **slides-producer** | Presentation automation |

### Research & Analysis Agents (USACF - 14)
| Agent | Purpose |
|-------|---------|
| **meta-learning-orchestrator** | USACF multi-agent analysis coordination |
| **self-ask-decomposer** | Essential question generation (15-20 questions) |
| **step-back-analyzer** | High-level principle extraction |
| **structural-mapper** | Architecture and component mapping |
| **flow-analyst** | Data/process/user flow analysis |
| **gap-hunter** | Multi-dimensional gap identification |
| **risk-analyst** | FMEA failure mode analysis |
| **adversarial-reviewer** | Red team critique and validation |
| **opportunity-generator** | Gap-to-opportunity transformation |
| **confidence-quantifier** | Uncertainty and confidence scoring |
| **ambiguity-clarifier** | Terminology disambiguation |
| **synthesis-specialist** | Cross-arc strategic integration |

### Business Research Agents (9)
| Agent | Purpose |
|-------|---------|
| **strategic-researcher** | Web research and data collection |
| **competitive-intelligence** | Market structure analysis |
| **positioning-strategist** | Positioning statement development |
| **problem-validator** | Burning problem validation |
| **knowledge-gap-identifier** | Research gap analysis |
| **pattern-analyst** | Thematic analysis and contradiction resolution |
| **documentation-specialist** | File structure and doc management |

### Directory Structure
```
.claude/agents/
├── core/                    # Infrastructure (4 agents)
├── integrations/            # External services
├── specialized/             # USACF + Business Research (21 agents)
├── [48 root-level agents]   # Operations, business, content
└── category dirs/           # analysis, architecture, consensus, data, etc.
```

---

## Agentic-Flow Agents (72 Total)

Available via MCP: `mcp__claude-flow__agentic_flow_list_agents`

### Core Agents
- `coder` - Implementation specialist
- `planner` - Strategic planning
- `researcher` - Deep research
- `reviewer` - Code review and QA
- `tester` - Testing and QA

### Swarm Agents
- `adaptive-coordinator` - Dynamic topology switching
- `hierarchical-coordinator` - Queen-led swarm
- `mesh-coordinator` - Peer-to-peer mesh

### SPARC Agents
- `specification` - Requirements analysis
- `pseudocode` - Algorithm design
- `architecture` - System design
- `refinement` - Iterative improvement

### GitHub Agents
- `code-review-swarm` - Comprehensive code reviews
- `release-manager` - Release coordination
- `repo-architect` - Repository structure optimization
- `issue-tracker` - Issue management
- `multi-repo-swarm` - Cross-repo orchestration

### Flow Nexus Agents
- `flow-nexus-auth` - Authentication
- `flow-nexus-sandbox` - E2B sandbox management
- `flow-nexus-swarm` - AI swarm orchestration
- `flow-nexus-neural` - Neural network training
- `flow-nexus-payments` - Credit and billing

### Optimization Agents
- `Benchmark Suite` - Performance benchmarking
- `Load Balancing Coordinator` - Task distribution
- `Performance Monitor` - Metrics collection
- `Resource Allocator` - Capacity planning
- `Topology Optimizer` - Communication optimization

### Consensus Agents
- `byzantine-coordinator` - Byzantine fault tolerance
- `crdt-synchronizer` - CRDT implementation
- `gossip-coordinator` - Gossip protocols
- `raft-manager` - Raft consensus
- `quorum-manager` - Dynamic quorum adjustment

---

## Skills (68 Total)

Located in `.claude/skills/` - invoke with `skill: "name"`

### Data & Document Processing (8)
| Skill | Purpose |
|-------|---------|
| `xlsx` | Excel file manipulation |
| `pdf` | PDF reading, forms, extraction |
| `docx` | Word document processing (includes OOXML schemas) |
| `pptx` | PowerPoint generation (includes OOXML schemas) |
| `academy-brand-design` | AI Enablement Academy branded content |
| `canvas-design` | Canvas-based design |
| `frontend-design` | Frontend design implementation |
| `image-enhancer` | Image enhancement |

### AgentDB & Memory Systems (6)
| Skill | Purpose |
|-------|---------|
| `agentdb-advanced` | Advanced AgentDB operations |
| `agentdb-learning` | Reinforcement learning patterns |
| `agentdb-memory-patterns` | Persistent memory patterns |
| `agentdb-optimization` | Quantization, HNSW indexing |
| `agentdb-vector-search` | Semantic vector search |
| `reasoningbank-agentdb` | ReasoningBank with AgentDB |

### AI Agents & Swarms (8)
| Skill | Purpose |
|-------|---------|
| `agentic-jujutsu` | Quantum-resistant version control |
| `codex-subagents` | Subagent management |
| `hive-mind-advanced` | Queen-led coordination |
| `swarm-advanced` | Advanced swarm patterns |
| `swarm-orchestration` | Swarm workflow management |
| `ruv-swarm-operations` | RuV swarm operations |
| `ruvector-development` | Distributed vector database |
| `reasoningbank-intelligence` | Adaptive learning |

### Cloud & Infrastructure (7)
| Skill | Purpose |
|-------|---------|
| `cloudflare-dns` | DNS management |
| `digitalocean-infrastructure` | DigitalOcean management |
| `oci-server` | Oracle Cloud Infrastructure |
| `vercel-deployment` | Vercel deployments |
| `vercel-domains` | Domain configuration |
| `vercel-environment` | Environment variables |
| `calcom-selfhosted` | Cal.com self-hosted |

### Flow Nexus Platform (3)
| Skill | Purpose |
|-------|---------|
| `flow-nexus-swarm` | Cloud AI swarm deployment |
| `flow-nexus-neural` | Neural network training |
| `flow-nexus-platform` | Platform management |

### GitHub & DevOps (5)
| Skill | Purpose |
|-------|---------|
| `github-code-review` | AI-powered code review |
| `github-multi-repo` | Multi-repo coordination |
| `github-project-management` | Project board automation |
| `github-release-management` | Release orchestration |
| `github-workflow-automation` | GitHub Actions automation |

### Memory & Knowledge (3)
| Skill | Purpose |
|-------|---------|
| `memory-sync` | 7-backend memory synchronization (23+ scripts) |
| `qdrant-ops` | Qdrant vector DB operations |
| `progressive-disclosure` | Progressive information display |

### Development & Building (5)
| Skill | Purpose |
|-------|---------|
| `mcp-builder` | Build MCP servers |
| `skill-builder` | Create new skills |
| `skill-creator` | Skill scaffolding |
| `pair-programming` | AI pair programming |
| `svelte-framework` | SvelteKit development |

### Testing & Quality (3)
| Skill | Purpose |
|-------|---------|
| `verification-quality` | Code quality checks |
| `performance-analysis` | Performance profiling |
| `hooks-automation` | Hook script automation |

### Content & Marketing (7)
| Skill | Purpose |
|-------|---------|
| `content-research-writer` | Research and writing |
| `sparc-methodology` | SPARC storytelling |
| `gtm-sales-proposals` | GTM sales proposals |
| `learning-science-design` | Instructional design |
| `brevo-email` | Brevo email marketing |
| `internal-comms` | Internal communications |
| `changelog-generator` | Auto-generate changelogs |

### Business & Operations (6)
| Skill | Purpose |
|-------|---------|
| `competitive-ads-extractor` | Competitor ad analysis |
| `developer-growth-analysis` | Developer metrics |
| `domain-name-brainstormer` | Domain name ideas |
| `invoice-organizer` | Invoice management |
| `lead-research-assistant` | Lead research |
| `meeting-insights-analyzer` | Meeting analysis |

### UI Components (1)
| Skill | Purpose |
|-------|---------|
| `shadcn-components` | shadcn/ui installation |

### Utilities (7)
| Skill | Purpose |
|-------|---------|
| `browser-automation` | Screenshots, PDFs, testing (Playwright CLI/MCP) |
| `file-organizer` | File organization |
| `standard-ops` | Standard operations |
| `stream-chain` | Stream processing |
| `stripe-payments` | Stripe integration |
| `video-downloader` | Video downloading |
| `zai-vision` | AI vision analysis (Z.AI GLM-4.5V)

---

## Commands (89 Total)

Located in `.claude/commands/` - 13 categories

### Agents Commands (4)
- `/agent-types` - List all 54+ agent types
- `/agent-capabilities` - Agent capabilities and features
- `/agent-coordination` - Multi-agent coordination guide
- `/agent-spawning` - Spawn agents with Task tool

### Coordination Commands (3)
- `/swarm-init` - Initialize swarm topology (mesh, hierarchical, ring, star)
- `/agent-spawn` - Spawn individual agents
- `/task-orchestrate` - Orchestrate tasks with adaptive strategies

### Memory Commands (5)
- `/memory:memory-search` - Search ALL 7 memory backends
- `/memory-usage` - Query memory backends
- `/memory-persist` - Persist to cold storage
- `/memory-sync` - Sync all backends
- `/memory-stats` - Memory statistics

### GitHub Commands (5)
- `/github-swarm` - GitHub repository management swarm
- `/repo-analyze` - Deep repository analysis
- `/pr-enhance` - AI-powered PR improvements
- `/issue-triage` - Intelligent issue classification
- `/code-review` - Automated code review

### Hive-Mind Commands (11)
- `/hive-mind-init` - Initialize hive-mind system
- `/hive-mind-spawn` - Spawn worker agents
- `/hive-mind-status` - Check hive status
- `/hive-mind-resume` - Resume from previous session
- `/hive-mind-stop` - Stop hive operations
- `/hive-mind-sessions` - Manage sessions
- `/hive-mind-consensus` - Run consensus mechanisms
- `/hive-mind-memory` - Access collective memory
- `/hive-mind-metrics` - View performance metrics
- `/hive-mind-wizard` - Guided interactive setup
- `/hive-mind` - Main documentation

### Analysis Commands (3)
- `/bottleneck-detect` - Detect performance bottlenecks
- `/performance-report` - Generate performance analysis
- `/token-usage` - Token consumption statistics

### Monitoring Commands (3)
- `/swarm-monitor` - Real-time swarm monitoring
- `/agent-metrics` - Individual agent metrics
- `/real-time-view` - Live dashboard view

### Hooks Commands (5)
- `/pre-task` - Before task execution
- `/post-task` - After task completion
- `/pre-edit` - Before code edits
- `/post-edit` - After code edits
- `/session-end` - At session end

### Automation Commands (3)
- `/auto-agent` - Auto-assign agents
- `/smart-spawn` - Intelligent agent spawning
- `/workflow-select` - Select workflows

### Training Commands (3)
- `/neural-train` - Train neural patterns
- `/pattern-learn` - Learn from past operations
- `/model-update` - Update model weights

### Workflows Commands (3)
- `/workflow-create` - Create workflows
- `/workflow-execute` - Execute workflows
- `/workflow-export` - Export workflows

### Swarm Commands (10)
- `/swarm` - Main swarm documentation
- `/swarm-init` - Initialize swarm
- `/swarm-spawn` - Spawn agents
- `/swarm-status` - Check status
- `/swarm-monitor` - Monitor swarm
- `/swarm-analysis` - Analyze performance
- `/swarm-background` - Background concepts
- `/swarm-modes` - Execution modes
- `/swarm-strategies` - Execution strategies

### Optimization Commands (3)
- `/cache-manage` - Manage caching
- `/parallel-execute` - Parallel execution
- `/topology-optimize` - Optimize swarm topology

### Cortex Commands (3)
- `/cortex-search` - Search knowledge base
- `/cortex-export` - Export documents
- `/cortex-fix-orphans` - Fix orphan documents

### Framework Commands (7)
- `/shadcn-check` - Check shadcn/ui setup
- `/shadcn-add` - Add shadcn/ui components
- `/vercel-deploy` - Deploy to Vercel
- `/vercel-status` - Check deployment status
- `/vercel-env` - Manage environment variables
- `/vercel-logs` - View deployment logs
- `/sync-agentdb` - Sync AgentDB

### Payment Commands (2)
- `/stripe-balance` - Check Stripe balance
- `/stripe-test-webhook` - Test Stripe webhooks

---

## Hooks (37 Total)

Located in `.claude/hooks/` - organized by lifecycle stage

### Session Lifecycle (4)
| Hook | Purpose |
|------|---------|
| `session-start.sh` | Initialize session, load memory |
| `session-end.sh` | Persist state, archive learnings |
| `session-end-sync.sh` | Full sync on session end |
| `session-lock.sh` | Prevent parallel session conflicts |

### Memory Operations (10)
| Hook | Purpose |
|------|---------|
| `memory-orchestrator.sh` | Unified 3-layer memory chain |
| `memory-search.sh` | Search AgentDB/Claude Flow memory |
| `memory-store.sh` | Namespace-based storage |
| `memory-sync-hook.sh` | Auto-sync on pattern storage |
| `memory-to-learnings-bridge.sh` | Bridge memory to learnings |
| `incremental-memory-sync.sh` | Periodic sync (30 calls or 5 min) |
| `pre-task-memory-lookup.sh` | Search ALL memory sources |
| `log-learning.sh` | Capture learnings with deduplication |
| `index-new-episode.sh` | Index to AgentDB embeddings |
| `agentdb-supabase-sync.sh` | Sync AgentDB JSON to Supabase |

### Task Lifecycle (5)
| Hook | Purpose |
|------|---------|
| `pre-task.sh` | Load context, prepare for work |
| `post-task.sh` | Log completion, persist learnings |
| `post-error.sh` | Log errors with resolutions |
| `pre-search.sh` | Check cached searches |
| `post-search.sh` | Cache search results |

### Cortex Integration (7)
| Hook | Purpose |
|------|---------|
| `cortex-create-doc.sh` | Create document with metadata |
| `cortex-link-creator.sh` | Create bidirectional links |
| `cortex-learning-capture.sh` | Store learnings in knowledge base |
| `cortex-log-learning.sh` | Log learning with structure |
| `cortex-post-task.sh` | Log completed work |
| `cortex-template-create.sh` | Create from templates |
| `cortex-health-check.sh` | Quick health assessment |

### NocoDB Integration (2)
| Hook | Purpose |
|------|---------|
| `nocodb-create-task.sh` | Create task with agent assignment |
| `nocodb-update-status.sh` | Update task status |

### Agent & Pattern (6)
| Hook | Purpose |
|------|---------|
| `detect-agent.sh` | Detect Claude agent variant |
| `save-pattern.sh` | Store successful patterns |
| `check-existing-solution.sh` | Check before solving |
| `log-action.sh` | Track individual actions |
| `extract-learnings-from-findings.sh` | Analyze findings |
| `emergency-memory-flush.sh` | Full sync before data loss |

### External Integration (3)
| Hook | Purpose |
|------|---------|
| `sync-memory-to-supabase.sh` | Sync to Supabase |
| `stripe-webhook-monitor.sh` | Stripe CLI forwarding |
| `vercel-deployment-hook.sh` | Auto-deploy to Vercel |

---

## Memory Sync Scripts (23 Total)

Located in `.claude/skills/memory-sync/scripts/`

### Main Orchestration
- `sync-all.sh` - Full sync of all backends
- `memory-stats.sh` - Show memory statistics

### Hot to Cold Sync
- `sync-agentdb-to-supabase.sh` - AgentDB → Supabase
- `sync-agentdb-to-cortex.sh` - AgentDB → Cortex
- `sync-swarm-to-cold.sh` - Swarm → Cold storage
- `sync-hivemind-to-cold.sh` - Hive-Mind → Cold storage

### Cold to Hot Sync
- `sync-supabase-to-agentdb.sh` - Supabase → AgentDB
- `sync-from-cortex.sh` - Cortex → Local

### Qdrant Indexing
- `index-to-qdrant.sh` - Index all to Qdrant
- `index-codebase-to-qdrant.sh` - Index codebase
- `sync-cortex-to-qdrant.sh` - Cortex → Qdrant
- `sync-supabase-to-qdrant.sh` - Supabase → Qdrant
- `sync-swarm-to-qdrant.sh` - Swarm → Qdrant
- `sync-episodes-to-qdrant.sh` - Episodes → Qdrant
- `sync-patterns-to-qdrant.sh` - Patterns → Qdrant

### Search
- `semantic-search.sh` - Semantic search
- `unified-search.sh` - Unified search across backends
- `test-search-codebase.sh` - Test codebase search

### Utilities
- `sync-to-cortex.sh` - Sync to Cortex
- `migrate-qdrant-schema.py` - Schema migration
- `migrate-qdrant-nested-schema.py` - Nested schema migration

---

## Discovery Commands

```bash
# List custom agents
ls .claude/agents/*/

# List all agentic-flow agents (72)
mcp__claude-flow__agentic_flow_list_agents

# Get agent details
mcp__claude-flow__agentic_flow_agent_info { name: "coder" }

# List all skills (68)
ls .claude/skills/

# Read skill documentation
cat .claude/skills/SKILL-NAME/SKILL.md

# List all commands (89)
find .claude/commands -name "*.md" | wc -l

# List all hooks (37)
ls .claude/hooks/*.sh | wc -l

# List sync scripts (23)
ls .claude/skills/memory-sync/scripts/*.sh | wc -l
```

---

*Last updated: 2025-12-04 - Swarm audit of all documentation*
