---
name: cortex-task-log
description: Capture and append structured agent task reports into Cortex via SiYuan APIs.
status: active
owner: knowledge-ops
last_reviewed_at: 2025-11-04
tags:
  - cortex
  - siyuan
dependencies:
  - cortex-siyuan-ops
  - doc-sync
outputs:
  - cortex-task-entry
  - sync-proof
---

# Cortex Task Log Skill

1. Determine the target notebook/page using metadata (project, runbook, or tracker) and create it when missing with `/api/filetree/createDocWithMd`.
2. Append a timestamped block summarising the task outcome, decisions, links to artefacts, and follow-up actions using `/api/block/appendBlock`.
3. Tag the entry with responsible agent(s), status, and review date via `/api/block/setBlockAttrs` so dashboards stay current.
4. Trigger optional notifications or digests (Brevo email, Docmost sync) once the log entry is confirmed.
5. Record the update in the Git workspace (e.g., `MIGRATION_TASKS.md`) to maintain bidirectional traceability.
