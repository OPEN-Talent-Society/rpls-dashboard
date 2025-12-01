---
name: progressive-disclosure
description: >
  Implements progressive disclosure patterns for efficient context window usage.
  Use when building skills, implementing tool discovery, or optimizing token consumption.
  Reduces token usage by up to 98.7% through on-demand capability loading.
status: active
owner: platform
version: 1.0.0
tags:
  - patterns
  - performance
  - context-efficiency
  - tool-discovery
---

# Progressive Disclosure Skill

## Purpose
Apply progressive disclosure patterns to reveal information in layers based on relevance, dramatically reducing token consumption while maintaining full capability access.

## When to Use
- Building new skills or agents
- Implementing tool discovery systems
- Optimizing context window usage
- Managing large tool libraries (10+ tools)
- Processing large datasets

## Core Patterns

### Three-Level Loading
```
Level 1: Metadata (~10-50 tokens)
Level 2: Full content (~500-2000 tokens)
Level 3: Deep context (~500-5000 tokens)
```

### Tool Search Pattern
```javascript
searchTools({
  mode: "operations",  // or "types"
  resourceType: "target",
  action: "verb",
  riskLevel: "read|write|destructive|admin"
})
```

### Programmatic Batching
```python
# Process locally, return only summary
results = [process(item) for item in batch]
return aggregate(results)  # Only this enters context
```

## Quick Reference

| Approach | Token Reduction | Use Case |
|----------|-----------------|----------|
| Skills Metadata | ~95% | Skill discovery |
| Tool Search | ~98.7% | Large tool libraries |
| Programmatic | ~37% | Multi-step workflows |

## Implementation

### For Skills
1. Keep SKILL.md under 500 lines
2. Use one-level-deep references
3. Scripts execute, not load
4. Bundle large data as references

### For Tools
1. Single meta-tool for discovery
2. Separate operations vs types modes
3. Classify by risk level
4. Return structured output

### For Workflows
1. Batch operations in loops
2. Process results locally
3. Return only summaries
4. Early termination on success

## Related Documentation
- [PROGRESSIVE-DISCLOSURE.md](../../docs/PROGRESSIVE-DISCLOSURE.md) - Full documentation
- [CONTINUOUS-IMPROVEMENT.md](../../docs/CONTINUOUS-IMPROVEMENT.md) - Integration patterns

## Validation
- [ ] Token usage decreased after implementation
- [ ] Full capabilities remain accessible
- [ ] No increase in error rates
- [ ] Discovery works on-demand

#progressive-disclosure #performance #patterns #automated
