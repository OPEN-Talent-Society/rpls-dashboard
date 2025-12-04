---
name: rl-eval-run
description: Execute RLHF/LLM evaluation suites and archive outcomes
status: draft
owner: ml-ops
last_reviewed_at: 2025-10-28
tags:
  - machine-learning
dependencies:
  - rlhf-lab-coordinator
outputs:
  - evaluation-report
---

# RL Evaluation Skill

Run evaluation harness (automated + human feedback), aggregate metrics, and publish results.

## Steps
1. Select experiment run + dataset.
2. Execute evaluation notebook/scripts (wandb integration).
3. Compile metrics (BLEU, accuracy, reward) and human scores.
4. Publish Docmost summary + update NocoDB experiment tracker.
