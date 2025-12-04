---
description: "Append a structured agent task entry into Cortex via SiYuan API"
argument-hint: "<summary> [--links url1,url2]"
allowed-tools: ["Cortex MCP", "HTTP", "Read", "Write"]
---

# /cortex:log-task

1. Collect task metadata: agent name, scope, outcomes, follow-ups, related artefacts.
2. Use `cortex-task-log` skill and MCP tools (`siyuan_create_doc`, `siyuan_append_block`, `siyuan_set_block_attrs`) to create or update the target page.
3. Summarise the entry in plain markdown, include backlinks to Git commits/docs, and confirm success response.
4. Optionally trigger digest notifications or exports once the entry lands in Cortex.
