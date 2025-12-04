---
description: "Run weekly Cortex review, tidy notebooks, and refresh dashboards"
argument-hint: "[--inbox-only]"
allowed-tools: ["Cortex MCP", "HTTP", "Read", "Write"]
---

# /cortex:curate

1. Execute `cortex-notebook-curation` skill to audit notebooks against PARA structure.
2. Archive or relabel stale pages, regenerate dashboards via `siyuan_sql_query`, and ensure templates are up to date.
3. Log a summary block into the Operations journal and capture follow-up actions in Docmost or GitHub issues.
