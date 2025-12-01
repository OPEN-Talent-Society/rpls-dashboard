---
title: "ADR - {{DECISION_TITLE}}"
created: {{TIMESTAMP}}
type: decision
agent: {{AGENT_VARIANT}}
agent_email: {{AGENT_EMAIL}}
status: {{STATUS}}
related_task: {{NOCODB_TASK_ID}}
tags: [decision, adr, {{CATEGORY}}, {{AGENT_VARIANT}}]
---

# ADR: {{DECISION_TITLE}}

## Status
{{STATUS}}

*Proposed | Accepted | Deprecated | Superseded by [[ADR-XXX]]*

---

## Context
{{CONTEXT}}

What is the issue we're trying to solve? What constraints exist?

---

## Decision
{{DECISION}}

What is the change that we're proposing and/or doing?

---

## Options Considered

### Option 1: {{OPTION_1_NAME}}
**Description**: {{OPTION_1_DESC}}

**Pros**:
- {{OPTION_1_PRO_1}}
- {{OPTION_1_PRO_2}}

**Cons**:
- {{OPTION_1_CON_1}}
- {{OPTION_1_CON_2}}

### Option 2: {{OPTION_2_NAME}}
**Description**: {{OPTION_2_DESC}}

**Pros**:
- {{OPTION_2_PRO_1}}

**Cons**:
- {{OPTION_2_CON_1}}

---

## Consequences

### Positive
- {{POSITIVE_1}}
- {{POSITIVE_2}}

### Negative
- {{NEGATIVE_1}}
- {{NEGATIVE_2}}

### Risks
- {{RISK_1}}

---

## Implementation

### Steps
1. {{STEP_1}}
2. {{STEP_2}}
3. {{STEP_3}}

### Timeline
{{TIMELINE}}

---

## Related

- [[ADR-Previous]]
- [[Task-Related]]
- [[Learning-Related]]

---

## Metadata
- **Decision Date**: {{DECISION_DATE}}
- **Decision Makers**: {{DECISION_MAKERS}}
- **Agent**: {{AGENT_VARIANT}}
- **Related Task**: #{{NOCODB_TASK_ID}}

#decision #adr #{{CATEGORY}} #{{AGENT_VARIANT}}

{: custom-type="decision" custom-status="{{STATUS}}" custom-agent="{{AGENT_VARIANT}}" }
