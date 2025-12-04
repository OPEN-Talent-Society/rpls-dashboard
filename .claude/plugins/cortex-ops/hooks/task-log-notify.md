---
description: "Emit webhook or email notification after Cortex task log entry is created"
triggers: ["/cortex:log-task"]
---

# Cortex Task Log Notifier Hook

Use this hook to fan out notifications (Brevo email, Slack, Docmost update) once a new task log entry is appended in Cortex. Implement via n8n or MCP delegate:

1. Listen for `/cortex:log-task` completion event.
2. Pull the latest block using `siyuan_export_markdown` or `siyuan_sql_query`.
3. Send formatted summary to the chosen channel and link back to the Cortex page.
4. Record delivery status in Cortex attributes for auditability.
