# Progressive Disclosure Patterns for Cortex

Patterns for creating Cortex documents optimized for both AI agents and human consumption.

## Overview

Progressive disclosure is an interaction design technique that sequences information to manage complexity. In Cortex, we apply this to create documents that:

1. **AI agents** can quickly scan for relevant context
2. **Humans** can drill into details when needed
3. **Both** benefit from consistent, predictable structure

## Core Principles

### 1. Summary First (TLDR Pattern)
Always start documents with a brief summary that AI can use without reading the full document.

```markdown
# Document Title

> **TLDR**: One-sentence summary for quick AI context loading.

## Summary
- Key point 1
- Key point 2
- Key point 3
- **Outcome**: What was the result?

---

## Details {: data-fold="0" }
[Detailed content below...]
```

### 2. Layered Detail (Fold Pattern)
Use SiYuan's folding blocks to hide details by default.

```markdown
## Quick Reference {: data-fold="1" }
Essential info shown by default.

## Technical Details {: data-fold="0" }
In-depth content hidden by default.

## Code Examples {: data-fold="0" }
Implementation details hidden by default.

## API Reference {: data-fold="0" }
Full API documentation hidden by default.
```

**Fold Values:**
- `data-fold="1"` - Expanded by default (show)
- `data-fold="0"` - Collapsed by default (hide)

### 3. Structured Metadata (Front Matter)
YAML front matter enables SQL queries and AI parsing.

```yaml
---
title: Document Title
created: 2025-12-01
agent: claude-code@aienablement.academy
type: learning|task|adr|sop|reference|daily|meeting|project
status: active|done|archived
priority: P1|P2|P3|P4
tags: [tag1, tag2]
related: [doc-id-1, doc-id-2]
nocodb_task: 123
---
```

### 4. Block Attributes (Custom Metadata)
Append to any block for queryability.

```markdown
## Section Title
Content here.
{: custom-agent="claude-code" custom-status="active" custom-priority="high" }
```

**Queryable via SQL:**
```sql
SELECT * FROM blocks
WHERE ial LIKE '%custom-status="active"%'
```

## Document Templates

### Learning Document (AI-Optimized)

```markdown
---
title: Learning - [TOPIC]
created: [DATE]
agent: [AGENT]
type: learning
tags: [learning, category]
---

# [TOPIC]

> **TLDR**: What was learned in one sentence.

## Key Insights {: data-fold="1" }
- **Insight 1**: Brief description
- **Insight 2**: Brief description
- **Insight 3**: Brief description

## Context {: data-fold="0" }
What prompted this learning?

## Discovery {: data-fold="0" }
### What Was Learned
Technical details and findings.

### Why It Matters
Impact and implications.

## Application {: data-fold="0" }
### Code Example
```code
// Implementation
```

### Usage Pattern
How to apply this learning.

## Related {: data-fold="1" }
- ((related-doc-id-1))
- ((related-doc-id-2))

---
{: custom-type="learning" custom-agent="[AGENT]" }
```

### Task Document (Progress-Optimized)

```markdown
---
title: Task - [NAME]
created: [DATE]
agent: [AGENT]
type: task
status: in_progress
priority: P2
nocodb_task: [ID]
---

# [NAME]

> **Status**: In Progress | **Priority**: P2 | **Sprint**: [SPRINT]

## Objective {: data-fold="1" }
What needs to be accomplished.

## Progress {: data-fold="1" }
| Date | Update |
|------|--------|
| 2025-12-01 | Started work on... |

## Technical Details {: data-fold="0" }
### Implementation Approach
Details about how this is being implemented.

### Files Changed
- `path/to/file.ts` - Description
{: data-fold="0" }

### Decisions Made
1. **Decision**: Rationale
2. **Decision**: Rationale
{: data-fold="0" }

## Blockers {: data-fold="0" }
- [ ] Blocker 1 - Waiting on X

## Learnings {: data-fold="0" }
- ((learning-doc-id))

---
{: custom-type="task" custom-status="in_progress" custom-nocodb="[ID]" }
```

### Reference Document (Scan-Optimized)

```markdown
---
title: Reference - [TOPIC]
created: [DATE]
type: reference
tags: [reference, category]
---

# [TOPIC]

> **Purpose**: What this reference covers.

## Quick Reference {: data-fold="1" }
| Item | Value |
|------|-------|
| Key 1 | Value |
| Key 2 | Value |

## Common Patterns {: data-fold="1" }
### Pattern 1
```code
// Quick copy-paste pattern
```

### Pattern 2
```code
// Quick copy-paste pattern
```

## Full Documentation {: data-fold="0" }
### Section 1
Detailed explanation.

### Section 2
Detailed explanation.

## API Reference {: data-fold="0" }
### Endpoint 1
```
POST /api/endpoint
{payload}
```

## Troubleshooting {: data-fold="0" }
| Issue | Solution |
|-------|----------|
| Problem 1 | Fix 1 |

---
{: custom-type="reference" }
```

### ADR (Decision-Optimized)

```markdown
---
title: ADR - [DECISION]
created: [DATE]
type: adr
status: accepted
---

# ADR: [DECISION]

> **Status**: Accepted | **Date**: [DATE]

## Decision {: data-fold="1" }
**We will [DECISION].**

## Context {: data-fold="1" }
What is the issue we're facing?

## Consequences {: data-fold="1" }
### Positive
- Benefit 1
- Benefit 2

### Negative
- Drawback 1

### Neutral
- Impact 1

## Alternatives Considered {: data-fold="0" }
### Option A
Description. **Rejected because**: reason.

### Option B
Description. **Rejected because**: reason.

## Implementation Notes {: data-fold="0" }
How to implement this decision.

## Related {: data-fold="0" }
- ((related-adr-id))

---
{: custom-type="adr" custom-status="accepted" }
```

## AI Context Loading Patterns

### Pattern 1: Quick Scan
AI loads only TLDR and Key Insights for broad context.

```sql
-- Get summaries of recent learnings
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-type="learning"%'
  AND updated > date('now', '-7 days')
LIMIT 20
```

### Pattern 2: Deep Dive
AI loads full document when topic matches closely.

```javascript
// Load full document
mcp__cortex__siyuan_request({
  endpoint: "/api/export/exportMdContent",
  payload: { id: "document-id" }
})
```

### Pattern 3: Related Context
AI follows refs to build context graph.

```sql
-- Find related documents via refs
SELECT def_block_id FROM refs
WHERE block_id IN (
  SELECT id FROM blocks WHERE content LIKE '%search term%'
)
```

### Pattern 4: Type-Based Context
AI loads documents by type for specific tasks.

```sql
-- For task context: load active ADRs
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-type="adr"%'
  AND ial LIKE '%custom-status="accepted"%'
```

## Human Interaction Patterns

### Pattern 1: Scannable Headings
Use descriptive headings that preview content.

```markdown
## Authentication Flow (OAuth2 + JWT)
## Database Schema (PostgreSQL)
## API Endpoints (REST)
```

### Pattern 2: Table Summaries
Use tables for quick-reference information.

```markdown
| Feature | Status | Notes |
|---------|--------|-------|
| Auth | Done | OAuth2 |
| API | In Progress | 80% |
| Tests | Pending | - |
```

### Pattern 3: Breadcrumb Navigation
Include navigation context.

```markdown
**Path**: Resources > Learnings > 2025-12 > [Topic]
**Related**: [[Parent Topic]] | [[Related Topic]]
```

### Pattern 4: Action Items
Use checkboxes for scannable action items.

```markdown
## Next Steps
- [ ] Action 1
- [ ] Action 2
- [x] Completed action
```

## SiYuan Features for Progressive Disclosure

### Folding Blocks
```markdown
## Collapsed by Default {: data-fold="0" }
This content is hidden until expanded.
```

### Block Embedding
```markdown
Embed a summary block from another document:
{{block-id}}
```

### Block References
```markdown
Reference without embedding:
((block-id))
((block-id 'Custom anchor text'))
```

### Super Blocks (Containers)
```markdown
{{{row
Column 1 content

Column 2 content
}}}
```

### Custom Attributes
```markdown
Any paragraph.
{: custom-key="value" style="color: red" }
```

## Best Practices

### DO:
1. Start every document with TLDR/Summary
2. Use front matter for structured metadata
3. Fold detailed sections by default
4. Include tables for quick reference
5. Add block attributes for queryability
6. Create refs to related documents
7. Use consistent heading hierarchy

### DON'T:
1. Start with lengthy context (put context below summary)
2. Create deeply nested structures (max 3 levels)
3. Leave documents without metadata
4. Create orphan documents (always link)
5. Use inconsistent formatting
6. Forget to set custom attributes

## SQL Query Patterns for AI

### Recent Activity
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND updated > date('now', '-24 hours')
ORDER BY updated DESC
LIMIT 10
```

### By Agent
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-agent="claude-code"%'
ORDER BY updated DESC
```

### By Status
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-status="active"%'
```

### Related to Task
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-nocodb="%task-id%"%'
```

## Integration with 3-Layer Memory

### Layer 1: Supabase (Structured)
Store structured metadata for cross-session queries.

### Layer 2: AgentDB (Local)
Cache frequently accessed summaries locally.

### Layer 3: Cortex (Full)
Full documents with progressive disclosure.

**Sync Pattern:**
```
1. AI queries AgentDB for cached summaries
2. If cache miss, query Cortex with TLDR pattern
3. For deep context, load full document
4. Update AgentDB cache with results
5. Sync critical learnings to Supabase
```

---

*Skill: cortex-progressive-disclosure | Version: 1.0.0 | Updated: 2025-12-01*
*Part of Cortex Excellence Initiative*
