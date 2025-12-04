---
name: video-generate
description: Create AI-generated video assets aligned with creative briefs
status: draft
owner: creative-ops
last_reviewed_at: 2025-10-28
tags:
  - creative
dependencies:
  - video-producer
outputs:
  - video-asset
---

# Video Generation Skill

Automate Sora/Veo/Runway video generation, manage prompt iterations, and log approvals.

## Steps
1. Load creative brief and reference assets.
2. Submit job to chosen provider via MCP; monitor status.
3. Review output, trim/edit if needed, capture metadata.
4. Upload to GDrive/NAS and notify stakeholders.
