---
name: tailscale-access-review
description: Review Tailscale ACLs, device inventory, and access logs for compliance
status: draft
owner: ops
last_reviewed_at: 2025-10-28
tags:
  - security
dependencies:
  - tailscale-operations
outputs:
  - access-review
---

# Tailscale Access Review Skill

Run weekly review of Tailscale nodes, tags, ACLs, and active sessions; revoke stale devices and document changes.

## Steps
1. Fetch device list via Tailscale API/MCP.
2. Compare against inventory; flag unknown/stale nodes.
3. Validate ACL file vs policy; raise PR if drift detected.
4. Confirm MagicDNS/Split DNS entries (e.g. `ddns.harbor.fyi → 100.85.205.49`) still terminate on Tailnet-only hosts by checking `dnsmasq` status on `nginxproxymanager` and verifying `ddns-updater` health on VM `101` (`docker ps --filter name=ddns-updater`).
5. Log review in Docmost + update NocoDB `access_reviews`.

## Automation
- `scripts/security/tailscale-review.py` generates audit reports.
