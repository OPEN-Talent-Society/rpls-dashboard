---
name: stripe-reconcile
description: Reconcile Stripe transactions with accounting records and bank payouts
status: draft
owner: finance
last_reviewed_at: 2025-10-28
tags:
  - finance
dependencies:
  - stripe-auditor
outputs:
  - reconciliation-report
---

# Stripe Reconcile Skill

Pulls Stripe data via Agent Toolkit, matches against ledger entries, flags discrepancies, and files report.
