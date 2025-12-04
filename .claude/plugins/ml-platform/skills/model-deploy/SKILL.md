---
name: model-deploy
description: Deploy or update ML models (Whisper/Ollama) with validation and rollback
status: draft
owner: ml-ops
last_reviewed_at: 2025-10-28
tags:
  - machine-learning
dependencies:
  - local-ml-stack-ops
outputs:
  - model-release
---

# Model Deploy Skill

Coordinate model deployment pipeline including download, verification, smoke tests, and catalog updates.

## Steps
1. Pull model artifact (Ollama/Whisper) with checksum verification.
2. Stage in test environment; run evaluation set.
3. Promote to production; update routing config.
4. Document release in Docmost + version inventory.

## Automation
- `scripts/ml/model-deploy.sh` deploys or refreshes models via Ollama CLI.
