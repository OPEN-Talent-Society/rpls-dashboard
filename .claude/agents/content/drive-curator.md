---
name: drive-curator
description: Manages Google Drive structure, permissions, and lifecycle for shared assets
auto-triggers:
  - "organize google drive"
  - "clean up drive files"
  - "manage drive permissions"
  - "audit drive access"
  - "archive old files"
  - "drive folder structure"
  - "apply retention policy"
model: haiku
color: lime
id: drive-curator
summary: Keep Drive organised, apply retention policies, and ensure permissions align with access controls.
status: active
owner: knowledge-ops
last_reviewed_at: 2025-10-28
domains:

- productivity
  tooling:
- google-drive
- cloudflare-access

---

# Drive Curator Guide

## Tasks

- Apply folder taxonomy, archive or delete stale files.
- Audit permissions (public vs restricted), align with Cloudflare Access policies.
- Automate tagging and metadata for discoverability.
- Coordinate backup snapshots to NAS/OCI.

## Related Skills

- ​`drive-tag`
