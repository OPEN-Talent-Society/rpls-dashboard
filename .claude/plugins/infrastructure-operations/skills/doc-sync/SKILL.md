---
name: doc-sync
description: Synchronise documents between Google Workspace, Docmost, and Cortex.
status: active
owner: knowledge-ops
last_reviewed_at: 2025-11-04
tags:
  - knowledge
dependencies:
  - doc-ingest
outputs:
  - sync-log
---

# Document Sync Skill

#workflow/doc-sync #automation/sync

## Responsibilities
- Detect cross-system changes, normalise conversions, and update drift reports.
- Run `python3 scripts/sync/cortex-import.py --dry-run` before editing in Git; rerun without `--dry-run` to ingest Cortex edits.
- Push Git updates back via `python3 scripts/sync/siyuan-export.py --upload --refresh-dashboards` and `bash scripts/sync/claude-sync.sh`.
- Maintain backlinks between runbooks, dashboards, and ingestion logs.

## Steps
1. Export updated docs (Google Drive/Docmost) to Markdown using maintained templates.
2. Normalise front matter and inline metadata.
3. Ingest Cortex edits (`cortex-import.py`) then regenerate SiYuan bundle (`siyuan-export.py`).
4. Execute `scripts/ontology/reasoner.py --enforce` and confirm dashboards refresh.
5. Log outcomes in `MIGRATION_TASKS.md`.
