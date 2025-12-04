# Continuous Improvement Framework

## Philosophy

> "We should not make the same mistake twice. We should not search for the same things twice."

This document defines the patterns and practices for continuous monitoring-based improvement across all Claude agents.

---

## Core Principles

### 1. Learn Once, Remember Forever
- Every learning is logged to AgentDB and Cortex
- Before solving a problem, check if it's been solved before
- Errors become prevention patterns, not just fixes

### 2. Progressive Disclosure (Anthropic Best Practice)
- Don't load all tools upfront - discover on-demand
- Reduces token usage by up to 98.7%
- Use tool search patterns for large tool libraries

### 3. Code Execution Preference
- **Use code execution when:**
  - Processing large datasets that need filtering
  - Implementing complex control flow (loops, conditionals)
  - Handling sensitive data that shouldn't pass through context
  - Connecting to multiple MCP servers

- **Use direct MCP calls when:**
  - Simple, single-step operations
  - Minimal infrastructure requirements
  - Sandboxing adds unnecessary overhead

### 4. Context Efficiency
- Filter results before returning to model
- Only explicitly logged data reaches model context
- Aggregate and transform in execution environment

---

## Mistake Prevention Patterns

### Pattern 1: Error Logging with Resolution
```yaml
namespace: errors/
key_format: errors/{category}/{specific-error}
required_fields:
  - error_message: What went wrong
  - root_cause: Why it happened
  - resolution: How it was fixed
  - prevention: How to avoid in future
  - related_code: Files/functions involved
```

**Hook**: `post-error.sh`
```bash
# After any error resolution:
/opt/homebrew/bin/claude-flow memory store \
  --key "errors/${CATEGORY}/${ERROR_ID}" \
  --value '{"error":"...","resolution":"...","prevention":"..."}'
```

### Pattern 2: Pre-Search Deduplication
Before any search/investigation:
```bash
# Check if we've searched this before
/opt/homebrew/bin/claude-flow memory search --pattern "searches/${TOPIC}*"

# If found, use cached result
# If not, perform search and cache
/opt/homebrew/bin/claude-flow memory store \
  --key "searches/${TOPIC}/${QUERY_HASH}" \
  --value '{"query":"...","results":"...","timestamp":"..."}'
```

### Pattern 3: Solution Templates
When a solution works, template it:
```yaml
namespace: patterns/
key_format: patterns/{domain}/{problem-type}
required_fields:
  - problem_pattern: Regex/description of when to apply
  - solution_template: Reusable code/approach
  - prerequisites: Required context
  - caveats: Known limitations
```

---

## Anthropic Engineering Best Practices

### From: Code Execution with MCP

1. **Progressive Tool Discovery**
   - Present MCP servers as file structure
   - Load tool definitions on-demand
   - Use search_tools with detail-level parameter

2. **Data Processing Efficiency**
   - Process large datasets locally
   - Return only filtered/relevant results
   - Execute aggregations without bloating context

3. **State Persistence**
   - Write outputs to files for resuming
   - Save working code as reusable skills
   - Build higher-level capabilities over time

### From: Building Effective Agents

1. **Start Simple**
   - Single LLM calls with retrieval first
   - Add complexity only when justified
   - Find simplest solution possible

2. **Agent Architecture Progression**
   ```
   Augmented LLM → Workflows → Agents
   (Start here)    (Add if needed)  (Only when necessary)
   ```

3. **Workflow Patterns**
   - **Prompt Chaining**: Sequential steps
   - **Routing**: Direct to specialized handlers
   - **Parallelization**: Independent subtasks simultaneously
   - **Orchestrator-Workers**: Dynamic task delegation
   - **Evaluator-Optimizer**: Generate + evaluate loops

4. **Error Recovery**
   - Ground truth from environment at each step
   - Clear checkpoints for human feedback
   - Iteration limits for control
   - Extensive sandboxed testing

5. **Tool Development Priority**
   - Spend more time optimizing tools than prompts
   - Invest in Agent-Computer Interface (ACI) design
   - Tool documentation equals UX priority

### From: Advanced Tool Use

1. **Tool Selection**
   - Keep 3-5 most-used tools always loaded
   - Defer rest to on-demand discovery
   - Use tool search when >10 tools or >10K tokens

2. **Programmatic Orchestration**
   - Write code that calls multiple tools
   - Control what enters context window
   - Enable parallel execution
   - Eliminate inference overhead (37% token reduction)

3. **Idempotent Operations**
   - Design tools safe to retry
   - Operations that can run in parallel
   - Naturally supports error recovery

---

## Implementation Hooks

### Pre-Task Hook Enhancement
```bash
#!/bin/bash
# Check for existing solutions before starting

TASK_HASH=$(echo "$TASK_DESCRIPTION" | md5)

# Search for similar problems solved before
EXISTING=$(/opt/homebrew/bin/claude-flow memory search \
  --pattern "patterns/*" \
  --query "$TASK_DESCRIPTION" \
  --limit 5)

if [ -n "$EXISTING" ]; then
  echo "Found existing patterns that may help:"
  echo "$EXISTING"
fi

# Search for relevant errors and their resolutions
RELEVANT_ERRORS=$(/opt/homebrew/bin/claude-flow memory search \
  --pattern "errors/*" \
  --query "$TASK_DESCRIPTION" \
  --limit 3)

if [ -n "$RELEVANT_ERRORS" ]; then
  echo "Relevant past errors to avoid:"
  echo "$RELEVANT_ERRORS"
fi
```

### Post-Error Hook
```bash
#!/bin/bash
# Log error with resolution for future prevention

ERROR_CATEGORY="$1"
ERROR_MESSAGE="$2"
RESOLUTION="$3"
PREVENTION="$4"

KEY="errors/${ERROR_CATEGORY}/$(date +%Y%m%d-%H%M%S)"

/opt/homebrew/bin/claude-flow memory store \
  --key "$KEY" \
  --namespace "errors" \
  --value "{
    \"category\": \"$ERROR_CATEGORY\",
    \"error\": \"$ERROR_MESSAGE\",
    \"resolution\": \"$RESOLUTION\",
    \"prevention\": \"$PREVENTION\",
    \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
    \"agent\": \"$CLAUDE_VARIANT\"
  }"

# Also log to Cortex for human visibility (Updated 2025-12-01)
curl -X POST "https://cortex.aienablement.academy/api/block/appendBlock" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{
    \"id\": \"20251201183343-ujsixib\",
    \"data\": \"## Error: $ERROR_MESSAGE\n\n**Resolution**: $RESOLUTION\n\n**Prevention**: $PREVENTION\",
    \"dataType\": \"markdown\"
  }"
```

### Learning Deduplication Hook
```bash
#!/bin/bash
# Check for duplicate learning before storing

LEARNING_CONTENT="$1"
LEARNING_HASH=$(echo "$LEARNING_CONTENT" | md5)

# Check if this exact learning exists
EXISTING=$(/opt/homebrew/bin/claude-flow memory search \
  --pattern "learnings/*" \
  --query "$LEARNING_CONTENT" \
  --threshold 0.9)

if [ -n "$EXISTING" ]; then
  echo "Similar learning already exists:"
  echo "$EXISTING"
  echo "Skipping duplicate storage."
  exit 0
fi

# Store new learning
/opt/homebrew/bin/claude-flow memory store \
  --key "learnings/$(date +%Y%m%d)/${LEARNING_HASH}" \
  --value "$LEARNING_CONTENT"
```

---

## Continuous Monitoring Patterns

### Real-time Metrics Collection
```bash
# Collect after each operation
/opt/homebrew/bin/claude-flow metrics collect \
  --operation "$OPERATION_TYPE" \
  --duration "$DURATION_MS" \
  --tokens "$TOKENS_USED" \
  --success "$SUCCESS_BOOL"
```

### Performance Trend Analysis
```bash
# Weekly analysis
/opt/homebrew/bin/claude-flow trend_analysis \
  --metric "token_usage" \
  --period "7d"

/opt/homebrew/bin/claude-flow trend_analysis \
  --metric "error_rate" \
  --period "7d"
```

### Bottleneck Detection
```bash
# Identify slow operations
/opt/homebrew/bin/claude-flow bottleneck_analyze \
  --component "all" \
  --metrics '["latency", "token_usage", "error_rate"]'
```

---

## Knowledge Graph Updates

When a problem is solved, update the knowledge graph:

1. **Create Error Entry** (if applicable)
   - Document what went wrong
   - Document the fix
   - Link to prevention pattern

2. **Create/Update Pattern**
   - Generalize the solution
   - Add to searchable patterns
   - Link to related patterns

3. **Create Learning Entry**
   - What was learned
   - When to apply
   - Related documentation

4. **Update Cortex**
   - Human-readable documentation
   - Backlinks to related topics
   - Tags for discoverability

---

## Standard Operating Procedure

### Before Starting Any Task
1. Search memory for similar tasks
2. Check for relevant error resolutions
3. Load applicable patterns
4. Review related learnings

### During Task Execution
1. Log significant decisions
2. Store intermediate findings
3. Track any errors encountered

### After Task Completion
1. Log the solution as a pattern (if novel)
2. Document any errors and resolutions
3. Create/update learnings
4. Update Cortex documentation

### On Any Error
1. Log error immediately with context
2. Document resolution steps
3. Create prevention pattern
4. Update related documentation

---

## Metrics to Track

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| Duplicate searches | <5% | Improve caching |
| Repeated errors | 0 | Strengthen prevention |
| Token usage | -10% weekly | Review progressive disclosure |
| Resolution time | Decreasing | Better pattern matching |

---

## Integration Points

### AgentDB
- Error storage: `errors/` namespace
- Learnings: `learnings/` namespace
- Patterns: `patterns/` namespace
- Search cache: `searches/` namespace

### Cortex
- Human documentation
- Cross-agent knowledge sharing
- Backlinks and forward links
- Tag-based discovery

### NocoDB
- Task tracking
- Sprint management
- Time logging
- Dependency tracking

### Claude Flow
- Memory operations
- Performance metrics
- Swarm coordination
- Neural pattern training

---

*Last Updated: 2024-11-30*
*Incorporating Anthropic Engineering Best Practices*
