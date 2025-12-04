# Product Frameworks Plugin

Unified product strategy toolkit that delivers structured workflows for PRD creation, Spec Kit solution shaping, BMAD validation, and SPARC storytelling across Codex, Claude Code, and Claude Z.AI.

## Included Assets
- **Agents**
  - `prd-facilitator` – shepherds product requirements documents from problem framing to stakeholder sign-off.
  - `spec-kit-strategist` – hosts solution optioning, scope slicing, and delivery guardrails between PRD and BMAD.
  - `bmad-analyst` – runs the Business Model, Market, Advantage, Delivery assessment to justify investment decisions.
  - `sparc-navigator` – crafts Situation, Problem, Actions, Results, Conclusion narratives for launches and retrospectives.
- **Skills**
  - `product-prd` – end-to-end PRD workflow.
  - `product-spec-kit` – medium-complexity specification and release planning.
  - `product-bmad` – commercialization pressure-test.
  - `product-sparc` – storytelling and alignment.
- **Commands**
  - `/framework:intake` – gather context and recommend which framework to run.
  - `/framework:summary` – generate executive digest across PRD, Spec Kit, BMAD, and SPARC artifacts.

All content references the canonical markdown stored in `codex-sandbox/.docs`. Keep those sources authoritative, then run `scripts/sync/claude-sync.sh` to propagate updates into Claude installs.

## Usage
1. Install via local marketplace: `claude plugin install product-frameworks@local`.
2. Launch `/framework:intake` to capture context and select PRD (low complexity), Spec Kit (medium), BMAD (high), or SPARC workflow.
3. Use the suggested agent/skill combos to produce final artifacts in Docmost and synchronize status into NocoDB.

## Maintenance Notes
- When updating agents/skills in `.docs`, mirror the change here or re-run an automation script to copy content.
- Commands rely on standard Claude Code tooling (Read, Write, WebSearch). Add MCP hooks as new integrations come online.
- Version bump the plugin when schemas or commands change; update `scripts/sync/claude-sync.sh` with the new version if needed.
