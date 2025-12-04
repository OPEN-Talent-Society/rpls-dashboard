---
description: "Run full infrastructure health check across Proxmox, OCI, and monitoring stacks"
argument-hint: "[--report-only]"
allowed-tools: ["Bash", "Read", "Write", "HTTP"]
---

# /infra:health

1. Execute `infra-health` skill to gather metrics.
2. Summarise status (green/yellow/red) and highlight incidents.
3. Provide actionable follow-ups and link to Docmost report.
