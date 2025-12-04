---
name: meeting-notes
description: Capture and distribute meeting summaries and action items
status: draft
owner: comms
last_reviewed_at: 2025-10-28
tags:
  - productivity
dependencies:
  - meeting-scribe
outputs:
  - meeting-summary
---

# Meeting Notes Skill

Uses Whisper transcripts + LLM to produce concise summaries, action items, and decisions, then routes to Docmost and email.
