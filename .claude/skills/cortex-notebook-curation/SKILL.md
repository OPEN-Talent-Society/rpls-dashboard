---
name: cortex-notebook-curation
description: Maintain Cortex notebook structure, templates, and automated dashboards for the second-brain system.
status: active
owner: knowledge-ops
last_reviewed_at: 2025-11-04
tags:
  - cortex
  - knowledge
dependencies:
  - cortex-siyuan-ops
outputs:
  - notebook-audit
  - template-pack
---

# Cortex Notebook Curation Skill

1. Audit notebooks for alignment with PARA layout, archiving stale pages and resurfacing critical runbooks.
2. Standardise templates (task log, decision record, experiment log) and publish them under `Templates` for quick reuse.
3. Build SiYuan database blocks that power dashboards (project tracker, knowledge expansion, backlog), ensuring required attributes exist.
4. Configure automation hooks (cron, n8n) that sync `.docs` exports and update Cortex indexes.
5. Document structural changes and update `.docs/knowledge/cortex-siyuan-system.md` to keep the runbook accurate.
