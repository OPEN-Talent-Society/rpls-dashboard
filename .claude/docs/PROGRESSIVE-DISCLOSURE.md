# Progressive Disclosure Best Practices

## Core Philosophy

> "Only load schemas for operations the model actually needs"

Progressive disclosure is a design pattern that reveals information in layers based on relevance, dramatically reducing token consumption while maintaining full capability access.

---

## Token Efficiency Benefits

| Pattern | Token Reduction | Source |
|---------|-----------------|--------|
| Tool Search vs Static | 98.7% | Anthropic Engineering |
| Programmatic Orchestration | 37% | Advanced Tool Use |
| Skills Metadata Loading | ~95% | Claude Platform |
| ProDisco Implementation | 85% | MCP SEP |

---

## Implementation Patterns

### Pattern 1: Three-Level Skills Disclosure

From Claude Platform Best Practices:

```
Level 1 (Startup): Metadata only (~10-50 tokens/skill)
├── name: skill-identifier
└── description: When and how to use

Level 2 (On-Demand): Full SKILL.md (~500-2000 tokens)
├── Guidelines and workflows
├── Patterns and preferences
└── Core instructions

Level 3 (Selective): Bundled files (~500-5000 tokens)
├── Commands
├── Agents
└── Reference documentation
```

**Implementation**:
- Pre-load only name/description at startup
- Read SKILL.md when relevant to task
- Access bundled files only when specific context needed

### Pattern 2: Tool Search Meta-Tool

From MCP SEP-1888 and ProDisco:

```javascript
// Single meta-tool replacing hundreds of individual tools
searchTools({
  mode: "operations",  // or "types"
  resourceType: "pods",
  action: "get",
  riskLevel: "read"
})

// Three-step workflow:
1. Search operations → receive method signatures
2. Query types → get structured definitions
3. Generate code → using operation + type info
```

**Key Features**:
- Operations mode: Search by resource, action, scope, risk
- Types mode: Retrieve machine-readable definitions
- Dot-notation navigation: `V1Deployment.spec.template.spec`

### Pattern 3: Programmatic Tool Calling

From Advanced Tool Use:

```python
# Instead of multiple API calls, write code that:
# 1. Calls multiple tools in sequence
# 2. Processes outputs locally
# 3. Controls what enters context window

def analyze_repos(repo_list):
    results = []
    for repo in repo_list:
        data = api.get_repo(repo)
        # Process locally - not in context
        summary = summarize(data)
        results.append(summary)
    # Only summary enters context
    return aggregate(results)
```

**Benefits**:
- Eliminates 19+ inference passes
- Enables parallel execution
- Explicit control flow with loops/conditionals

### Pattern 4: File-Based Discovery

From Anthropic Code Execution:

```
./servers/
├── kubernetes/
│   ├── pods.ts
│   ├── deployments.ts
│   └── services.ts
├── github/
│   └── repos.ts
└── stripe/
    └── payments.ts

# Agent reads directory structure first
# Loads specific modules on demand
# 150,000 tokens → 2,000 tokens (98.7% reduction)
```

---

## Risk Classification

From MCP SEP:

| Risk Level | Description | Use Case |
|------------|-------------|----------|
| `read` | Read-only operations | Listing, describing, getting |
| `write` | Modifications | Creating, updating, patching |
| `destructive` | Deletions | Delete, remove, purge |
| `admin` | Privileged operations | RBAC, secrets, security |

Enable policy-based filtering: "only allow read operations by default"

---

## Skill Architecture Best Practices

### File Organization

```
skill-name/
├── SKILL.md (main instructions, <500 lines)
├── reference.md (linked directly from SKILL.md)
├── examples.md (linked directly)
├── forms/
│   └── FORMS.md (conditional access)
└── scripts/
    └── utility.py (executed, not loaded into context)
```

**Key Principles**:
1. One-level-deep references from SKILL.md
2. Avoid nested file chains
3. Scripts execute without context consumption
4. Large datasets as bundled references

### SKILL.md Structure

```yaml
---
name: skill-identifier  # gerund form: processing-pdfs
description: >
  What this skill does and when to use it.
  Write in third person for system prompt injection.
  Include both capability and trigger conditions.
license: optional-license
---

# Skill Name

## Quick Start
[Minimal viable instructions]

## Core Workflows
[Main patterns and procedures]

## Advanced Features
See [REFERENCE.md](./REFERENCE.md) for advanced options.
See [FORMS.md](./forms/FORMS.md) for form processing.

## Scripts
Run `./scripts/utility.py` for [purpose].
```

### Description Writing

```yaml
# Good - specific trigger conditions
description: >
  Extract text and tables from PDF files, fill forms, merge documents.
  Use when working with PDFs or when user mentions extraction.

# Bad - vague
description: "Helps with documents"
```

---

## Progressive Disclosure in Hooks

### Pre-Task Hook with Discovery

```bash
#!/bin/bash
# Only load relevant context

TASK="$1"

# Check if we have cached knowledge about this task type
CACHED=$(npx claude-flow memory search \
  --pattern "patterns/${TASK_TYPE}/*" \
  --limit 3)

if [ -n "$CACHED" ]; then
  echo "Loading cached patterns..."
  echo "$CACHED"
else
  echo "No cached patterns. Starting fresh investigation."
fi

# Progressive context loading
# Level 1: Quick summary
# Level 2: Detailed context if needed
# Level 3: Full history only if blocked
```

### Tool Discovery Hook

```bash
#!/bin/bash
# Implement searchTools pattern

search_tools() {
  local mode="$1"       # operations | types
  local resource="$2"   # resource type
  local action="$3"     # get | create | update | delete

  # Return minimal signatures first
  if [ "$mode" = "operations" ]; then
    # Return only method names and parameter hints
    return_minimal_signatures "$resource" "$action"
  else
    # Return full type definitions on demand
    return_type_definitions "$resource"
  fi
}
```

---

## Context Window Management

### Token Budget Allocation

```
System prompt:        ~5,000 tokens (fixed)
Skill metadata:       ~200-1,000 tokens (all skills)
Active skill:         ~500-2,000 tokens (loaded on demand)
Conversation:         ~10,000-50,000 tokens (variable)
Tool definitions:     ~2,000 tokens (with discovery)
Working space:        ~remaining tokens
```

### Optimization Strategies

1. **Metadata efficiency**: Name/description drive discovery
2. **Script utilization**: Execute without context consumption
3. **Reference bundling**: Large datasets accessed only when needed
4. **Lazy loading**: Files accessed via bash only when determined necessary

---

## Degrees of Freedom Calibration

Match specificity to task fragility:

| Freedom Level | Use When | Example |
|---------------|----------|---------|
| High (text) | Multiple approaches valid | "analyze structure, check for bugs" |
| Medium (pseudocode) | Preferred pattern exists | "use this template, customize params" |
| Low (scripts) | Error-prone operations | "do not modify the command" |

---

## Anti-Patterns to Avoid

1. **Loading all tools upfront** - Use discovery instead
2. **Deep nesting** - Max 1 level from SKILL.md
3. **Vague descriptions** - Be specific about triggers
4. **Magic numbers** - Document all constants
5. **Excessive options** - Provide sensible defaults
6. **Time-sensitive info** - Use "old patterns" sections

---

## Implementation Checklist

### For New Skills

- [ ] Name follows gerund form (processing-pdfs)
- [ ] Description includes capability AND trigger conditions
- [ ] SKILL.md under 500 lines
- [ ] References max 1 level deep
- [ ] Scripts execute, not load
- [ ] Large data as bundled references

### For Tool Discovery

- [ ] Single meta-tool for search
- [ ] Operations and types modes
- [ ] Risk classification on all operations
- [ ] Structured output for machine parsing
- [ ] Pagination for large results

### For Programmatic Calling

- [ ] Batch operations in loops
- [ ] Early termination on success
- [ ] Local result processing
- [ ] Context-efficient returns

---

## References

- [MCP SEP-1888](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1888)
- [ProDisco Implementation](https://github.com/harche/ProDisco)
- [Claude Platform Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
- [Anthropic Code Execution with MCP](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [Anthropic Advanced Tool Use](https://www.anthropic.com/engineering/advanced-tool-use)

---

*Implementing progressive disclosure reduces token usage by up to 98.7% while maintaining full capability access.*
