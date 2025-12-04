---
name: infra-health
description: Run comprehensive infrastructure health checks across Proxmox, Docker hosts, network, and monitoring stack
status: draft
owner: ops
last_reviewed_at: 2025-10-28
tags:
  - infrastructure
dependencies:
  - proxmox-ops
  - docker-host-operations
  - tailscale-operations
outputs:
  - health-report
---

# Infra Health Skill

## Purpose
Execute a standardised health assessment across the hybrid infrastructure estate, aggregating system metrics, service statuses, and alert triage into a single report.

## When to Use
- Daily health sweep (recommended at start of ops shift).
- Before major deploys or maintenance windows.
- After incidents to confirm stability.

## Prerequisites
- Access to Proxmox API, Docker hosts, monitoring endpoints.
- Tailscale connectivity to on-prem assets.
- Write access to Docmost + NocoDB for report logging.

## Steps
1. Collect host metrics (Proxmox, OCI) using MCP/CLI.
2. Validate shared storage availability: confirm `/mnt/qnap/*` mounts on Proxmox (`mount | grep /mnt/qnap`) and spot-check container bind targets (`pct exec <ct> -- ls /media`).
3. Confirm Tailnet-only services are gated correctly:
   - `systemctl status dnsmasq` on `nginxproxymanager` and `dig ddns.harbor.fyi` from a tailnet node should resolve to `100.85.205.49`, while public queries return 403/405.
   - On VM `101` (`Docker-Debian`), ensure `ddns-updater` is healthy with `docker ps --filter name=ddns-updater` and review logs (`docker logs --tail 50 ddns-updater`) for successful Porkbun updates.
4. Check Docker Compose stacks status and recent container logs across `/srv/*` (OCI) and `/root` (VM `101`) as appropriate.
5. Verify monitoring/alerting services (Uptime Kuma, Netdata) are operational.
6. Run security checks (open ports, pending updates) if flagged.
7. Summarise findings in Docmost template and push KPIs to NocoDB.

## Outputs
- Markdown report under `Operations/Reports/Infra Health`.
- NocoDB row appended to `infra_health_checks` with status and follow-ups.

## Automation Hooks
- `scripts/infra/health-check.sh` orchestrates data collection.
- Hook to uptime heartbeat to confirm completion.
