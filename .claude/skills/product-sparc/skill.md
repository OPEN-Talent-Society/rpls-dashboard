---
name: product-sparc
description: SPARC storytelling workflow to communicate product decisions, launch outcomes, and retrospectives with crisp narrative focus
status: production
owner: product
last_reviewed_at: 2025-10-28
tags:
  - product
  - communication
  - storytelling
triggers:
  - "SPARC narrative"
  - "product launch brief"
  - "post-launch recap"
  - "retrospective"
  - "executive update"
  - "product story"
  - "communicate results"
dependencies:
  - sparc-navigator
outputs:
  - docmost-sparc-brief
  - comms-pack
---
# Product SPARC Skill

SPARC = **Situation, Problem, Actions, Results, Conclusion**. This narrative format keeps stakeholders aligned on why a project mattered, what was done, the measurable impact, and the forward-looking plan.

## Triggers
- Pre-launch briefing or go/no-go review.
- Post-launch recap, incident write-up, or retrospective.
- Executive update decks that need a concise storyline.

## Inputs
- PRD or BMAD artifacts for context.
- Metrics dashboards, analytics exports, or qualitative feedback.
- Incident timelines or launch runbooks.
- Audience definition and desired outcome (decision, awareness, funding).

## Steps
1. **Situation**
   - Frame context: market forces, user persona, prior state.
   - Highlight urgency or stakes.
2. **Problem**
   - State pain point with data + anecdote.
   - Clarify what happens if unaddressed.
3. **Actions**
   - Summarize solution path, experiments, key decisions.
   - Note cross-functional contributors and timeline.
4. **Results**
   - Share metrics, qualitative wins, unexpected learnings.
   - Include counter-metrics (guardrails, costs).
5. **Conclusion**
   - Call-to-action, next steps, or pending risks.
   - Provide appendix links (dashboards, PRD, BMAD, retro).
6. **Distribution**
   - Publish in Docmost under `Product/SPARC/<date>-<topic>.md`.
   - Create comms pack (Slack blurb, Google Slides outline, email summary).

## Outputs
- Docmost SPARC brief capturing narrative.
- Optional slides or newsletter snippet for stakeholders.
- Updates in NocoDB `projects` timeline log.

## Quality Gates
- Storyline can be read top-to-bottom in under five minutes.
- Numbers annotated with source + date range.
- Next actions clear with owner + due date.
- Links to supporting docs verified.

## Automation Hooks
- Template slides stored under `/ops/templates/product-sparc-slide-deck.pptx`.
- Future n8n flow can auto-digest metrics into Results section.

## Related Skills
- `product-prd` for upstream context.
- `product-spec-kit` for delivery slices referenced in narrative.
- `product-bmad` for investment rationale.
