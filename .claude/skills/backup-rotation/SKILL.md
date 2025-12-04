---
name: backup-rotation
description: Execute backup rotation schedule for Proxmox, NAS, Docmost, NocoDB, and cloud snapshots
status: draft
owner: ops
last_reviewed_at: 2025-10-28
tags:
  - backup
dependencies:
  - proxmox-ops
  - nas-backup-admin
outputs:
  - backup-report
---

# Backup Rotation Skill

Automates scheduled backups, validates integrity, and logs results in Docmost/NocoDB.

## Workflow Summary
1. Trigger Proxmox snapshot + ZFS send to NAS.
2. Run Docmost/NocoDB database dumps and push to `/srv/backups` + cloud.
3. Validate checksums, update retention policy (delete expired backups).
4. Produce summary report and alert on failures.

## Automation
- `scripts/backup/run-rotation.sh` orchestrates tasks.
- Hooks to backup verifier for completion heartbeat.
