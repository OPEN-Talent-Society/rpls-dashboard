# Agent Trigger Guide

Quick reference for which agents trigger on which user queries. Use this guide to understand how natural language queries map to specialized agents.

## Research & Analysis

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "research this market" | strategic-researcher | Market research and data collection |
| "analyze competitors" | competitive-intelligence | Competitive landscape analysis |
| "what are we missing" | gap-hunter | Gap identification across dimensions |
| "what could go wrong" | risk-analyst | Risk assessment and failure analysis |
| "find opportunities" | opportunity-generator | Transform gaps/risks into opportunities |
| "identify patterns" | pattern-analyst | Pattern recognition and synthesis |
| "comprehensive analysis" | universal-research-framework | Full multi-agent framework |
| "deep investigation" | universal-research-framework | Complete research suite with validation |

## Business Operations

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "scan the market" | market-scanner | Market intelligence gathering |
| "analyze campaigns" | marketing-orchestrator | Campaign analysis and optimization |
| "audit finances" | stripe-auditor / audit-scribe | Financial audit and compliance |
| "check compliance" | compliance-report | Compliance verification |
| "optimize workflow" | flow-analyst | Flow and pathway optimization |

## Product & Strategic Planning

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "create PRD" | prd-facilitator | Product requirements documentation |
| "BMAD analysis" | bmad-analyst | Business model and design analysis |
| "strategic positioning" | positioning-strategist | Market positioning strategy |
| "spec this feature" | spec-kit-strategist | Feature specification |

## Development Operations

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "deploy this" | docker-deploy | Docker deployment automation |
| "monitor performance" | netdata-ops / performance-monitor | System monitoring |
| "manage containers" | docker-ops | Docker operations |
| "vector database" | qdrant-ops | Qdrant vector DB management |

## GitHub & Code Review

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "review this PR" | code-review-swarm | Comprehensive PR review |
| "manage releases" | release-swarm | Release management |
| "coordinate repos" | github-multi-repo | Multi-repository coordination |
| "automate workflows" | workflow-automation | GitHub Actions automation |

## Content & Creative

| User Says... | Agent to Use | Why |
|--------------|-------------|-----|
| "create design" | canvas-design | Visual design creation |
| "produce video" | video-producer | Video production |
| "edit audio" | audio-editor | Audio editing |
| "enhance image" | image-enhancer | Image quality enhancement |

## Quick Decision Tree

```
User needs research?
├─ Specific library/framework? → Context7
├─ Recent/current data? → WebSearch + year (2025)
├─ Multiple dimensions/comprehensive? → universal-research-framework
├─ Single focus area?
│  ├─ Market data? → strategic-researcher
│  ├─ Competitors? → competitive-intelligence
│  ├─ Gaps/issues? → gap-hunter
│  ├─ Risks? → risk-analyst
│  └─ Opportunities? → opportunity-generator
└─ Simple fact? → Memory → Web

User needs implementation?
├─ File operations? → Claude Code (Edit, Write, Read)
├─ Code generation? → Claude Code directly
├─ Coordination? → Swarm or Task tool
└─ Specialized work? → Relevant agent via Task tool

User needs deployment?
├─ Docker? → docker-deploy or docker-ops
├─ Cloud? → digitalocean-infrastructure / vercel-deployment
├─ Database? → qdrant-ops
└─ Monitoring? → netdata-ops / health-monitor
```

## Research SOP Integration

The Universal Research Framework operates as **Level 4** in the Research SOP:

```
Level 1: Memory (Qdrant, AgentDB) - < 1 sec
├─ /memory:memory-search "query"
├─ mcp__claude-flow__agentdb_pattern_search
└─ Check Supabase, Swarm Memory, Cortex

Level 2: Documentation (Context7) - < 5 sec
├─ mcp__context7__resolve-library-id
└─ mcp__context7__get-library-docs

Level 3: Web Research - < 10 sec
├─ WebFetch with date context
└─ WebSearch with year (2025)

Level 4: Deep Research - minutes
└─ universal-research-framework (full suite)
```

## Trigger Keywords by Agent

### Strategic Researcher
**Triggers:** market research, industry analysis, data gathering, trend research, business intelligence, competitive landscape, strategic planning

### Competitive Intelligence
**Triggers:** competitor analysis, competitive research, market landscape, SWOT analysis, positioning analysis, market structure

### Gap Hunter
**Triggers:** find gaps, identify issues, quality gaps, performance gaps, capability assessment, weakness analysis, missing features, improvement opportunities, vulnerability identification

### Risk Analyst
**Triggers:** risk assessment, failure analysis, vulnerability scan, security risks, what could go wrong, edge cases, reliability issues, threat modeling

### Opportunity Generator
**Triggers:** find opportunities, improvement ideas, growth opportunities, optimization opportunities, innovation suggestions, quick wins, strategic initiatives, actionable recommendations

### Pattern Analyst
**Triggers:** identify patterns, find themes, pattern recognition, trend identification, data synthesis, insight extraction

### Flow Analyst
**Triggers:** flow analysis, pathway optimization, process flow, workflow analysis, bottleneck detection

## Universal Research Framework Agents (23 Total)

### Core Research (5 agents)
- **strategic-researcher** - Market research and data collection
- **competitive-intelligence** - Competitive landscape analysis
- **gap-hunter** - Multi-dimensional gap analysis
- **risk-analyst** - FMEA and failure mode analysis
- **opportunity-generator** - Gap-to-opportunity transformation

### Pattern & Analysis (3 agents)
- **pattern-analyst** - Pattern identification and themes
- **flow-analyst** - Flow and pathway analysis
- **structural-mapper** - Architecture and structure analysis

### Meta-Learning & Validation (4 agents)
- **meta-learning-orchestrator** - Self-improving search patterns
- **adversarial-reviewer** - Red team critique and validation
- **confidence-quantifier** - Uncertainty quantification
- **step-back-analyzer** - Establish principles first

### Synthesis & Knowledge (4 agents)
- **synthesis-specialist** - Combine multi-agent findings
- **ambiguity-clarifier** - Resolve ambiguities
- **documentation-specialist** - Document findings
- **knowledge-gap-identifier** - Critical knowledge gaps

### Advanced Techniques (7 agents)
- **self-ask-decomposer** - Complex question breakdown
- **perspective-simulator** - Multi-stakeholder analysis
- **research-intelligence** - Intelligence gathering and synthesis
- **positioning-strategist** - Market positioning strategy
- **problem-validator** - Problem validation
- **competitive-analyst** - Ongoing competitor monitoring
- **research-coordinator** - Coordinate comprehensive research

## When to Use Universal Research Framework

Use the full framework when you need:

1. **Complex Multi-Dimensional Analysis**
   - Multiple perspectives required
   - High-stakes decision making
   - Comprehensive gap and risk assessment

2. **Market/Competitive Intelligence**
   - Deep market research
   - Competitive landscape mapping
   - Strategic positioning analysis

3. **Quality Assurance & Validation**
   - Adversarial review needed
   - Confidence scoring required
   - Multiple validation gates

4. **Strategic Decision Support**
   - Long-term planning
   - Resource allocation decisions
   - Risk-adjusted recommendations

**Don't Use for:**
- Simple factual queries (use Memory or Web Search)
- Library documentation (use Context7)
- Quick status checks (use direct tools)
- Simple implementation tasks (use Claude Code)

## Memory Integration

Always store findings from research agents:

```javascript
mcp__claude-flow__agentdb_pattern_store({
  sessionId: "agent-task-id",
  task: "What the agent researched",
  input: "Original query",
  output: "Key findings and insights",
  reward: 0.85,  // Success metric (0-1)
  success: true,
  critique: "Self-reflection on approach and results"
})
```

## Quick Commands

```bash
# Search memory for previous research
/memory:memory-search "topic"

# List research agents
ls .claude/agents/specialized/ | grep -E "(researcher|intelligence|gap|risk|opportunity)"

# Check framework availability
cat .claude/agents/specialized/universal-research-framework.md

# Sync memory after research
bash .claude/skills/memory-sync/scripts/sync-all.sh
```

## Related Resources

| Resource | Location |
|----------|----------|
| Universal Research Framework | `.claude/agents/specialized/universal-research-framework.md` |
| Quick Reference | `.claude/docs/UNIVERSAL-RESEARCH-FRAMEWORK.md` |
| Research SOP | `.claude/docs/RESEARCH-SOP.md` |
| Memory SOP | `.claude/docs/MEMORY-SOP.md` |
| Main Config | `/Users/adamkovacs/CLAUDE.md` |

---

**Pro Tip:** When in doubt about which agent to use, start with the Research SOP hierarchy (Memory → Docs → Web → Deep Research) and let the natural language in your query guide the agent selection.
