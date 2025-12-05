# Research & Information Gathering SOP

## When to Use This SOP
- Agent is stuck and needs information
- Need to verify current/accurate data
- Research market/competitive intelligence
- Find library documentation
- Gather context for decision-making

## Mandatory Research Sequence

### Level 1: Memory Systems (FASTEST - Check First)

**1.1 Qdrant Semantic Search** (< 1 second)
```bash
# Use MCP tool for semantic search
# Collection: agent_memory
# Endpoint: http://qdrant.harbor.fyi
# Searches: patterns, learnings, trajectories, decisions
```

**1.2 AgentDB Pattern Search** (< 1 second)
```javascript
mcp__claude-flow__agentdb_pattern_search {
  task: "your search query",
  k: 10,
  minReward: 0.7,  // Optional: filter by success threshold
  onlySuccesses: true  // Optional: only successful patterns
}
```

**1.3 Wider Memory** (if needed)
- **Supabase** - patterns/learnings tables
- **Swarm Memory** - `.swarm/memory.db` (SQLite)
- **Hive-Mind** - per-project memory stores
- **Cortex** - knowledge base (https://cortex.aienablement.academy)

**Commands:**
```bash
# Quick memory search across all backends
/memory:memory-search "your query"

# Manual hook execution
bash .claude/hooks/pre-task-memory-lookup.sh "task description"

# Check stats
mcp__claude-flow__agentdb_stats {}
```

### Level 2: Documentation (Library/Framework Docs)

**2.1 Context7 for Library Docs**
```javascript
// Step 1: Resolve library ID
mcp__context7__resolve-library-id {
  libraryName: "react"
}

// Step 2: Get docs (once you have the ID)
mcp__context7__get-library-docs {
  context7CompatibleLibraryID: "/facebook/react",
  topic: "hooks",
  mode: "code"  // or "info" for conceptual guides
}

// Step 3: Paginate if needed
mcp__context7__get-library-docs {
  context7CompatibleLibraryID: "/facebook/react",
  topic: "hooks",
  mode: "code",
  page: 2  // Continue to pages 2, 3, 4 if context insufficient
}
```

**Mode Selection:**
- `mode: "code"` - API references, code examples, function signatures
- `mode: "info"` - Conceptual guides, architecture, best practices

### Level 3: Web Research (Current Information)

**3.1 WebFetch with Date Context**
```javascript
// Get current date context
const currentDate = new Date().toISOString().split('T')[0] // YYYY-MM-DD
const currentYear = new Date().getFullYear()
const currentMonth = new Date().toLocaleString('default', { month: 'long' })

// Use in WebFetch prompt
WebFetch {
  url: "https://example.com/docs",
  prompt: `Extract information about X. Current date: ${currentMonth} ${currentYear}. Prioritize recent information and indicate publication dates.`
}
```

**3.2 WebSearch for Recent Data**
```javascript
WebSearch {
  query: `topic name ${currentYear}`,  // Include year for recency
  allowed_domains: ["example.com", "docs.example.org"],  // Optional filtering
  blocked_domains: ["spam.com"]  // Optional blocking
}
```

**Recency Best Practices:**
- ALWAYS include current year in queries (2025 for now)
- Ask for publication dates in prompts
- Prefer official documentation over third-party sources
- Verify information is current before using

### Level 4: Deep Research (Market Intelligence)

**4.1 Spawn Research Swarm**
```javascript
// Use Task tool for parallel research (PREFERRED)
Task {
  subagent_type: "strategic-researcher",
  description: "Research market landscape",
  prompt: `Research X with focus on current ${currentYear} data.
  Analyze trends, key players, market size, growth projections.`
}

Task {
  subagent_type: "competitive-intelligence",
  description: "Analyze competitors",
  prompt: `Analyze competitive landscape for X.
  Identify top 5 competitors, their strengths/weaknesses, market positioning.`
}

Task {
  subagent_type: "pattern-analyst",
  description: "Identify patterns and insights",
  prompt: `Analyze data from market and competitive research.
  Extract key patterns, opportunities, threats.`
}
```

**4.2 Specialized Research Agents**
Available in `.claude/agents/specialized/`:
- `strategic-researcher` - Market landscape analysis
- `competitive-intelligence` - Competitor analysis
- `pattern-analyst` - Pattern recognition and insights
- `risk-analyst` - Risk assessment and mitigation
- `gap-hunter` - Gap analysis and opportunities

## Decision Tree

```
Need information?
├─ Already in memory? → Level 1 (Qdrant/AgentDB)
│  └─ Found? → Use it + store context of reuse
│  └─ Not found? → Continue to Level 2
│
├─ Library/framework documentation? → Level 2 (Context7)
│  └─ Found? → Store in memory for future
│  └─ Not found? → Continue to Level 3
│
├─ Current/recent data needed? → Level 3 (WebFetch/WebSearch + date)
│  └─ Found? → Store in memory with date context
│  └─ Not found or need deep analysis? → Continue to Level 4
│
└─ Complex multi-dimensional research? → Level 4 (Research swarm)
   └─ Always store final insights in memory
```

## Parallel Execution Rules

**When running multiple research operations:**

✅ **CORRECT** - Single message with parallel calls:
```javascript
// All independent operations in one message
mcp__claude-flow__agentdb_pattern_search { task: "X", k: 10 }
WebSearch { query: "Y 2025" }
mcp__context7__get-library-docs { context7CompatibleLibraryID: "/org/lib", topic: "Z" }
```

❌ **WRONG** - Sequential messages:
```
Message 1: agentdb_pattern_search
[wait for response]
Message 2: WebSearch
[wait for response]
Message 3: get-library-docs
```

**Swarm for Complex Research:**
```javascript
// Spawn multiple researchers in parallel
Task { subagent_type: "strategic-researcher", prompt: "Research market X" }
Task { subagent_type: "competitive-intelligence", prompt: "Analyze competitors Y" }
Task { subagent_type: "pattern-analyst", prompt: "Extract patterns from Z" }
```

## Memory Storage After Research

**ALWAYS store research results:**

```javascript
// After successful research
mcp__claude-flow__agentdb_pattern_store {
  sessionId: "research-session-id",
  task: "Research topic X",
  input: "Search query and context",
  output: "Key findings and insights",
  reward: 0.9,  // 0-1 based on result quality
  success: true,
  tokensUsed: 1500,
  latencyMs: 3200,
  critique: "Research was comprehensive. Found X, Y, Z. Could improve by..."
}
```

**Cortex Knowledge Base:**
```bash
# Log to Cortex for permanent storage
bash .claude/hooks/cortex-post-task.sh "Research findings for X"
```

## Recency Requirements

**MANDATORY for all web research:**

1. **Include current year** in all web queries
2. **Pass current date** to WebFetch prompts
3. **Request publication dates** in extraction prompts
4. **Verify recency** of information before using

**Current Date Template:**
```javascript
const now = new Date()
const dateContext = {
  iso: now.toISOString().split('T')[0],  // 2025-12-04
  year: now.getFullYear(),  // 2025
  month: now.toLocaleString('default', { month: 'long' }),  // December
  monthYear: `${now.toLocaleString('default', { month: 'long' })} ${now.getFullYear()}`  // December 2025
}
```

## Quality Standards

- **Speed**: Start with fastest (memory) before slower (web/swarm)
- **Accuracy**: Verify information recency and source credibility
- **Completeness**: Use appropriate level for the question's complexity
- **Storage**: Always store findings in memory for future use
- **Parallel**: Execute independent operations in parallel
- **Citations**: Include source URLs and dates in findings

## Common Patterns

### Pattern 1: Quick Answer
```
Question: "What's the current React hooks API?"
→ Level 1: Check memory (0.5s)
→ Level 2: Context7 React docs (3s)
→ Store: Save to memory
```

### Pattern 2: Current Market Data
```
Question: "What are the leading AI coding tools in 2025?"
→ Level 1: Check memory (0.5s) - might be outdated
→ Level 3: WebSearch "AI coding tools 2025" (5s)
→ Store: Save with date context
```

### Pattern 3: Deep Analysis
```
Question: "Should we enter the X market?"
→ Level 1: Check for previous analysis (0.5s)
→ Level 4: Spawn research swarm (2-5 min)
  - Market researcher (landscape)
  - Competitive analyst (competitors)
  - Risk analyst (risks/opportunities)
  - Pattern analyst (synthesize findings)
→ Store: Save comprehensive report
```

## Error Handling

**If research fails at any level:**
1. Log the failure with context
2. Try next level in sequence
3. If all levels fail, report to user with details
4. Store failure pattern for learning

```javascript
// Store failed research for learning
mcp__claude-flow__agentdb_pattern_store {
  sessionId: "research-session-id",
  task: "Research topic X",
  input: "Search query and context",
  output: "Failed to find information after trying all levels",
  reward: 0.1,  // Low reward for failure
  success: false,
  critique: "Could not find current data. Suggest: 1) Try different keywords, 2) Check if topic exists, 3) Use alternative sources"
}
```

## Examples

### Example 1: Library Documentation
```javascript
// User asks: "How do I use Next.js App Router?"

// Level 1: Memory check
mcp__claude-flow__agentdb_pattern_search {
  task: "Next.js App Router usage",
  k: 5
}
// Result: No recent patterns found

// Level 2: Context7
mcp__context7__resolve-library-id { libraryName: "next.js" }
// Result: /vercel/next.js

mcp__context7__get-library-docs {
  context7CompatibleLibraryID: "/vercel/next.js",
  topic: "app router",
  mode: "code"
}
// Result: Comprehensive App Router documentation

// Store for future
mcp__claude-flow__agentdb_pattern_store {
  sessionId: "nextjs-research",
  task: "Next.js App Router usage",
  output: "App Router is...",
  reward: 1.0,
  success: true
}
```

### Example 2: Market Research
```javascript
// User asks: "Analyze the AI agent framework market"

// Level 1: Memory check
mcp__claude-flow__agentdb_pattern_search {
  task: "AI agent framework market analysis",
  k: 5
}
// Result: Outdated analysis from 6 months ago

// Level 3: Current web data
const year = new Date().getFullYear()
WebSearch { query: `AI agent frameworks market ${year}` }
WebSearch { query: `AI agent platforms comparison ${year}` }

// Level 4: Deep analysis swarm
Task {
  subagent_type: "strategic-researcher",
  prompt: "Research AI agent framework market landscape 2025..."
}
Task {
  subagent_type: "competitive-intelligence",
  prompt: "Analyze top AI agent frameworks (LangChain, AutoGPT, Claude Code, etc)..."
}
Task {
  subagent_type: "pattern-analyst",
  prompt: "Synthesize market trends and predictions..."
}

// Workers complete and report back
// Store consolidated findings
mcp__claude-flow__agentdb_pattern_store {
  sessionId: "ai-agent-market-research",
  task: "AI agent framework market analysis 2025",
  output: "Market dominated by X, Y, Z. Key trends: ...",
  reward: 0.95,
  success: true
}
```

## Related Resources

- [MEMORY-SOP.md](.claude/docs/MEMORY-SOP.md) - Memory system usage
- [CLAUDE.md](/Users/adamkovacs/CLAUDE.md) - Main configuration
- `/research` command - Execute this SOP
- `research-coordinator` agent - Automate this workflow
