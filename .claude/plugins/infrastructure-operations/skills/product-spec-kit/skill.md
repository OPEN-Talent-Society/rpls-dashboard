---
name: product-spec-kit
description: Medium-complexity workflow that shapes implementation options, release slices, and delivery safeguards between PRD and BMAD
status: production
owner: product
last_reviewed_at: 2025-10-28
tags:
  - product
  - delivery
  - roadmap
dependencies:
  - spec-kit-strategist
  - prd-facilitator
outputs:
  - docmost-spec-kit
  - nocodb-spec-plan
---
# Product Spec Kit Skill

Use this skill when a validated problem (PRD) needs structured solution shaping before committing to a full BMAD investment review. Spec Kit helps teams explore options, plan staged releases, and align delivery expectations.

## Placement in Complexity Ladder
- **Low complexity** → `product-prd`: define the problem and baseline requirements.
- **Medium complexity** → `product-spec-kit`: refine solutions, scope slices, delivery plan.
- **High complexity** → `product-bmad`: evaluate commercial viability and long-term bets.

## Inputs
- Finalized or near-final PRD.
- Preliminary sizing notes from engineering/design.
- Known constraints (technical, compliance, timeline).
- Stakeholder availability for working sessions.

## Steps
1. **Review PRD Context**
   - Extract goals, success metrics, and constraints.
   - Highlight open questions or unresolved assumptions.
2. **Generate Solution Options**
   - Draft 2-3 viable approaches with pros/cons and complexity.
   - Note integration touchpoints, platform considerations, and validation risks.
3. **Define Release Slices**
   - Break work into pilot, GA, and follow-on milestones.
   - Associate each slice with user value, acceptance criteria, and observability hooks.
4. **Plan Delivery & Resources**
   - Estimate effort and team involvement for each slice.
   - Capture dependencies (people, vendors, tech upgrades).
5. **Risk & Guardrail Assessment**
   - Identify failure modes, triggers, and mitigation playbooks.
   - Clarify compliance/security reviews required.
6. **Decision Log & Handoff**
   - Select recommended approach; log rationale and dissent.
   - Update NocoDB project row with chosen slice plan and owners.
   - Share Spec Kit doc with engineering for estimation/kickoff.

## Outputs
- Docmost Spec Kit with option matrix, release roadmap, risk register.
- NocoDB updates: `spec_status`, `target_release`, `resourcing`, `open_reviews`.
- Optional: action items posted to project tracker or task board.

## Quality Gates
- At least one alternative approach considered and documented.
- Release slices align with measurable user outcomes.
- Risks have owners and monitoring strategy.
- Outstanding questions tagged with owner/due date.

## Automation Hooks
- `scripts/product/spec-kit-summary.sh` generates an executive TL;DR.
- Integrate with n8n flow to nudge owners when open questions linger.

## Related Skills
- `product-prd` (upstream discovery).
- `product-bmad` (downstream investment review).
- `product-sparc` (storytelling before/after launch).
