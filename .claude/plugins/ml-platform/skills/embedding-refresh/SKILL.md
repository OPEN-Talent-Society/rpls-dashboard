---
name: embedding-refresh
description: Refresh Qdrant embeddings for content repositories and knowledge bases
status: draft
owner: ml-ops
last_reviewed_at: 2025-10-28
tags:
  - machine-learning
dependencies:
  - qdrant-ops
outputs:
  - embedding-run
---

# Embedding Refresh Skill

Recompute embeddings for documents (Docmost, Siyuan, CRM notes) and sync to Qdrant.

## Steps
1. Identify documents updated since last run.
2. Generate embeddings via local model or API.
3. Upsert vectors into Qdrant with metadata.
4. Validate sample queries; log results.

## Automation
- `scripts/ml/embedding-refresh.py` orchestrates pipeline.
