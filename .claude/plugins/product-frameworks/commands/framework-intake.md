---
description: "Capture product context and recommend whether to run PRD, Spec Kit, BMAD, or SPARC workflow"
argument-hint: "[goal/problem statements]"
allowed-tools: ["Read", "Write", "Bash", "WebSearch", "NotebookRead"]
---

# Framework Intake

Use this command when you need to quickly determine which product framework to run and gather the minimum viable information to start the workflow.

## Steps

1. **Clarify Objective**
   - Ask the user to provide the core goal, target audience, and urgency.
   - Identify whether decision, alignment, or storytelling is the primary need.

2. **Assess Inputs**
   - Check for existing PRDs, Spec Kits, BMAD briefs, or SPARC narratives in the workspace (`rg "PRD"`, `rg "Spec Kit"`, `rg "BMAD"`, `rg "SPARC"`).
   - If none exist, note open gaps and required stakeholders.

3. **Recommend Framework**
   - **Choose PRD** when requirements or scope are unclear.
   - **Choose Spec Kit** when the problem is validated but solution shape, release slices, or delivery plan need definition.
   - **Choose BMAD** when leadership needs investment confidence or prioritization.
   - **Choose SPARC** when communicating progress, outcomes, or retrospectives.

4. **Kickoff Checklist**
   - Suggest relevant agent + skill pairing (e.g., `prd-facilitator` + `product-prd`).
   - Create todo list of missing inputs (research, metrics, approvals).
   - Provide command hints (`/framework:summary`, `/plugin agent prd-facilitator`).

## Output Template
```markdown
# Framework Intake Summary

## Recommendation
- Selected Framework: PRD | Spec Kit | BMAD | SPARC
- Confidence: High/Medium/Low

## Context
- Objective:
- Audience:
- Urgency/Timeline:

## Required Inputs
- [ ] Item / Owner / Due

## Next Steps
1. Launch agent: ...
2. Activate skill: ...
3. Schedule alignment: ...
```

## Tips
- Always surface risks or missing stakeholders before committing to the framework.
- If multiple frameworks are needed, propose sequencing (PRD → Spec Kit → BMAD) with SPARC used for storytelling throughout.
- Record summary in Docmost or NocoDB to keep decision trail.
