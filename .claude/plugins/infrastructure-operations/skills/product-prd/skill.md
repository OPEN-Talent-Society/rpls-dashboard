---
name: product-prd
description: End-to-end workflow for producing a high-quality product requirements document from discovery through stakeholder sign-off
status: production
owner: product
last_reviewed_at: 2025-10-28
tags:
  - product
  - strategy
  - documentation
dependencies:
  - prd-facilitator
outputs:
  - docmost-prd
  - nocodb-project-entry
---
# Product PRD Skill

This skill orchestrates the full PRD lifecycle so engineering, design, and GTM teams share the same source of truth before execution begins.

## Triggers
- Leadership requests clarity for a new initiative or feature set.
- Discovery research yields enough signal to scope delivery work.
- Downstream functions ask for a canonical requirements doc before committing resources.

## Inputs
- Problem statement and success metrics.
- Stakeholder roster with decision authority.
- Research artifacts: customer interviews, telemetry, competitive notes.
- Constraints: timeline, compliance, platform guardrails.

## Steps
1. **Discovery Synthesis**
   - Summarize user pains and business value.
   - Capture citations for data points.
2. **Audience & Goals**
   - Define target users/personas and expected outcomes.
   - Draft Goals/Non-Goals list.
3. **Experience Walkthrough**
   - Map primary flows with acceptance criteria.
   - Document edge cases, failure states, analytics hooks.
4. **Requirement Detailing**
   - Write functional requirements grouped by capability.
   - Back each requirement with rationale and owner.
   - Capture non-functional needs (latency, security, platforms).
5. **Alignment Review**
   - Schedule review session; facilitate decisions and record sign-offs.
   - Update docmost PRD with discussion outcomes.
6. **Finalization & Distribution**
   - Export shareable summary (Exec TL;DR, timeline, open questions).
   - Log PRD URL, status, and key fields in NocoDB tracker row.

## Outputs
- Docmost PRD with revision history and comment log.
- Update record in NocoDB `projects` table.
- Optional: Slack/email digest summarizing decisions and next actions.

## Quality Gates
- Conflicts and open questions tracked with owners/due dates.
- Every requirement ties back to user/jobs-to-be-done.
- Launch metrics defined with instrumentation notes.
- Risks & mitigations section complete.

## Automation Hooks
- `/scripts/product/prd-summary.sh` auto-generates an executive digest.
- Add to `claude plugin` command palette via `product-frameworks` plugin.

## Related Skills
- `product-spec-kit` for medium-complexity solution shaping before investment sizing.
- `product-bmad` for commercial validation.
- `product-sparc` for post-launch or retrospective storytelling.
