---
name: product-bmad
description: Structured BMAD assessment to validate viability, differentiation, and delivery readiness before committing to build
status: production
owner: product
last_reviewed_at: 2025-10-28
tags:
  - product
  - strategy
  - commercialization
triggers:
  - "BMAD analysis"
  - "validate business model"
  - "go no-go decision"
  - "market assessment"
  - "competitive advantage"
  - "delivery readiness"
  - "investment decision"
dependencies:
  - bmad-analyst
outputs:
  - docmost-bmad-brief
  - nocodb-bmad-snapshot
---
# Product BMAD Skill

BMAD = **Business model, Market, Advantage, Delivery**. Use this skill to pressure-test big bets, ensure commercial fit, and document rationale for investment decisions.

## Triggers
- Large feature or product line requires go/no-go decision.
- Raising capital or presenting roadmap to leadership/investors.
- Need to compare competing opportunities or sequencing.

## Inputs
- Preliminary PRD or problem statement.
- Market research or TAM analysis.
- Competitive landscape notes.
- Delivery constraints (team capacity, dependencies, risk register).

## Steps
1. **Business Model**
   - Identify revenue streams, pricing, and unit economics.
   - Capture assumptions and sensitivity scenarios.
2. **Market**
   - Size opportunity (TAM/SAM/SOM), audience segments, channel strategy.
   - Note regulatory or geographic considerations.
3. **Advantage**
   - Document differentiation vs competitors and unique assets.
   - Map moat durability and potential erosion factors.
4. **Delivery**
   - Estimate build phases, resources, and success metrics.
   - List blockers, integration points, and risk mitigations.
5. **Executive Playback**
   - Summarize findings in Docmost BMAD brief.
   - Collect sign-off (approve, pause, pivot) with rationale.
6. **System Updates**
   - Log decision, confidence, and follow-up tasks in NocoDB `projects` view.

## Outputs
- Docmost BMAD brief for archival.
- Decision status in NocoDB (e.g., Approved, Needs Research, On Hold).
- Recommended next steps with owners.

## Quality Gates
- All four BMAD dimensions completed with explicit assumptions.
- Quantitative estimates have sources and confidence scores.
- Delivery plan ties to realistic capacity and risk mitigation.
- Decision recorded with date, approver, and follow-up actions.

## Automation Hooks
- `scripts/product/bmad-dashboard.py` compiles trend reports.
- Integrate with NocoDB via API to keep scoreboard current.

## Related Skills
- `product-prd` for requirement deep-dive (upstream).
- `product-spec-kit` when a medium-complexity specification is needed before BMAD.
- `product-sparc` to communicate outcomes to wider org.
