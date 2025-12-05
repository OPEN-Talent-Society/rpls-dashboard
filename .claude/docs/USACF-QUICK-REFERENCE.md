# USACF Quick Reference

**Universal Search Algorithm for Claude Flow**

## What Is USACF?

Hyper-advanced multi-agent search framework integrating 20+ AI research techniques:
- Meta-learning & step-back prompting
- Adversarial validation & red team critique
- Multi-dimensional analysis (quality, performance, capability, strategic)
- Memory-coordinated agents with RAG integration
- Self-improving search with uncertainty quantification
- Perspective simulation and graduated context
- Iterative depth with validation gates

**Framework Location:** `.claude/agents/specialized/USACF.md`

## When to Use

- Complex multi-dimensional analysis
- Market/competitive research requiring depth
- Gap analysis and opportunity generation
- Strategic decision-making with high stakes
- Quality/risk assessment across multiple dimensions
- Research requiring adversarial validation
- Problems needing meta-learning and self-improvement

## Quick Start

```javascript
// Full USACF analysis
Task {
  subagent_type: "strategic-researcher",
  description: "USACF-powered research",
  prompt: "Follow USACF.md framework to analyze X market. Apply step-back prompting, multi-agent decomposition, and RAG integration for comprehensive analysis."
}
```

## Core USACF Agents (23 Total)

### Strategic Analysis
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| strategic-researcher | Web research, data collection | Primary market research |
| research-intelligence | Intelligence gathering, synthesis | Deep investigation |
| positioning-strategist | Market positioning, strategy | Strategic planning |

### Competitive Intelligence
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| competitive-intelligence | Competitive landscape analysis | Competitor analysis |
| competitive-analyst | Ongoing competitor monitoring | Continuous intelligence |

### Gap & Risk Analysis
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| gap-hunter | Multi-dimensional gap analysis | Quality/performance gaps |
| risk-analyst | FMEA, failure mode analysis | Risk assessment |
| opportunity-generator | Transform gaps to opportunities | Strategy synthesis |

### Pattern Analysis
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| pattern-analyst | Pattern identification, themes | Data synthesis |
| flow-analyst | Flow and pathway analysis | Process optimization |
| structural-mapper | Architecture analysis | System design |

### Knowledge Management
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| knowledge-gap-identifier | Critical knowledge gaps | Learning needs |
| problem-validator | Problem validation | Requirement verification |

### Meta-Learning & Validation
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| meta-learning-orchestrator | Self-improving search patterns | Iterative refinement |
| adversarial-reviewer | Red team critique, validation | Quality assurance |
| confidence-quantifier | Uncertainty quantification | Confidence scoring |
| step-back-analyzer | Establish principles first | Pre-analysis setup |
| self-ask-decomposer | Break down complex questions | Problem decomposition |

### Synthesis & Clarity
| Agent | Purpose | When to Use |
|-------|---------|-------------|
| synthesis-specialist | Combine multi-agent findings | Final integration |
| ambiguity-clarifier | Resolve ambiguities | Unclear requirements |
| documentation-specialist | Document findings | Knowledge capture |

## USACF Workflow Example

### Comprehensive Market Analysis

```javascript
// Phase 1: Meta-Analysis (Establish Principles)
Task {
  subagent_type: "step-back-analyzer",
  description: "Establish analysis principles",
  prompt: "Before analyzing X market, establish 5-7 core principles for market analysis excellence, evaluation criteria, anti-patterns to avoid, and success definition."
}

// Phase 2: Parallel Research (Multi-Agent Decomposition)
Task {
  subagent_type: "strategic-researcher",
  description: "Market landscape research",
  prompt: "Research X market in 2025. Use USACF framework: web search, data collection, trend analysis. Store findings in memory."
}

Task {
  subagent_type: "competitive-intelligence",
  description: "Competitive analysis",
  prompt: "Analyze top 5 competitors in X market. Strengths, weaknesses, positioning, market share. Use gap-hunter patterns."
}

Task {
  subagent_type: "pattern-analyst",
  description: "Pattern identification",
  prompt: "Analyze market data and competitive intelligence. Extract key patterns, trends, and themes."
}

// Phase 3: Gap Analysis
Task {
  subagent_type: "gap-hunter",
  description: "Multi-dimensional gap analysis",
  prompt: "Identify quality, performance, capability, and strategic gaps in X market using USACF dimensional framework."
}

Task {
  subagent_type: "risk-analyst",
  description: "FMEA risk assessment",
  prompt: "Conduct failure mode and effects analysis for entering X market. Identify risks, likelihood, impact, mitigation strategies."
}

// Phase 4: Opportunity Generation
Task {
  subagent_type: "opportunity-generator",
  description: "Transform gaps to opportunities",
  prompt: "Based on gap analysis and risk assessment, generate prioritized list of market opportunities with implementation roadmap."
}

// Phase 5: Adversarial Validation (Red Team)
Task {
  subagent_type: "adversarial-reviewer",
  description: "Critical validation",
  prompt: "Red team critique of all research findings. Identify assumptions, biases, missing data, alternative interpretations, and potential blind spots."
}

// Phase 6: Synthesis
Task {
  subagent_type: "synthesis-specialist",
  description: "Integrate all findings",
  prompt: "Synthesize all research, gap analysis, opportunities, and critiques into comprehensive strategic recommendation with confidence scores."
}
```

## USACF Research Techniques (20+)

**Integrated in Framework:**

1. **Meta-Learning** - Self-improving search patterns
2. **Step-Back Prompting** - Establish principles first
3. **Multi-Agent Decomposition** - Parallel specialized agents
4. **Adversarial Validation** - Red team critique
5. **Uncertainty Quantification** - Confidence scoring
6. **RAG Integration** - Grounded research with sources
7. **Active Prompting** - Adaptive questioning
8. **Perspective Simulation** - Multi-stakeholder views
9. **Graduated Context** - Hot/warm/cold context tiers
10. **Iterative Depth** - Adaptive analysis depth
11. **Observability** - Full decision tracing
12. **Version Control** - Source attribution
13. **Synthetic Data** - Test edge cases
14. **Self-Ask** - Decompose complex questions
15. **Chain-of-Verification** - Validate findings
16. **Reflection & Critique** - Self-improvement
17. **Memory Coordination** - Cross-agent learning
18. **Tool Use** - Web search, calculators, APIs
19. **Code Generation** - Automated analysis scripts
20. **Multi-Modal** - Text, images, data integration

## Integration with Research SOP

USACF is **Level 4** in the Research SOP:

```
Level 1: Memory (Qdrant, AgentDB) - < 1 sec
Level 2: Docs (Context7) - < 5 sec
Level 3: Web (WebFetch/WebSearch) - < 10 sec
Level 4: USACF Deep Research - minutes (use USACF agents)
```

See: [RESEARCH-SOP.md](./RESEARCH-SOP.md)

## Memory Storage

**Always store USACF findings:**

```javascript
mcp__claude-flow__agentdb_pattern_store({
  sessionId: "usacf-market-analysis",
  task: "USACF comprehensive market analysis for X",
  input: "Market research query with USACF framework",
  output: "Key findings, gaps, opportunities, risks, strategic recommendations",
  reward: 0.95,  // High quality analysis
  success: true,
  tokensUsed: 15000,
  latencyMs: 180000,  // 3 minutes
  critique: "USACF analysis was comprehensive. Found 12 gaps, generated 8 opportunities. Adversarial review identified 2 assumptions to validate. Next: validate customer demand."
})
```

## Performance Metrics

**Typical USACF Analysis:**
- **Duration**: 2-5 minutes
- **Agents**: 5-10 specialized agents
- **Depth**: 3-5 dimensional analysis
- **Quality**: 90%+ confidence with validation
- **Actionability**: Prioritized recommendations with roadmap

## Commands

```bash
# Execute research with USACF
/research "topic" --deep --usacf

# Search memory for previous USACF analyses
/memory:memory-search "USACF market analysis"

# Check USACF agent availability
ls .claude/agents/specialized/ | grep -E "(researcher|intelligence|gap|risk|pattern|meta|adversarial)"
```

## Related Resources

| Resource | Description |
|----------|-------------|
| `.claude/agents/specialized/USACF.md` | Full USACF framework documentation |
| `.claude/docs/RESEARCH-SOP.md` | Research procedures and workflows |
| `.claude/docs/MEMORY-SOP.md` | Memory system usage |
| `/Users/adamkovacs/CLAUDE.md` | Main configuration |

## Quick Decision Matrix

| Scenario | Use USACF? | Why |
|----------|-----------|-----|
| Simple question | No | Use memory or docs (Level 1-2) |
| Current news | No | Use web search (Level 3) |
| Market analysis | Yes | Multi-dimensional, strategic |
| Competitive research | Yes | Requires gap analysis, validation |
| Strategic decision | Yes | High stakes, needs adversarial review |
| Technical docs | No | Use Context7 (Level 2) |
| Risk assessment | Yes | FMEA, multi-perspective analysis |
| Opportunity identification | Yes | Gap-to-opportunity transformation |

---

**Remember:** USACF is for complex, high-value analysis requiring depth, validation, and strategic synthesis. For simpler queries, use Research SOP Levels 1-3 first.
