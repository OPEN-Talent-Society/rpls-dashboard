---
name: voiceover-transcribe
description: Generate AI voiceovers from scripts and handle transcription cleanup
status: draft
owner: creative-ops
last_reviewed_at: 2025-10-28
tags:
  - audio
dependencies:
  - audio-editor
outputs:
  - voiceover-file
---

# Voiceover & Transcription Skill

Produce high-quality voiceovers using approved voice models, confirm licensing, and provide accompanying transcripts.

## Steps
1. Accept script + pronunciation guide.
2. Generate voiceover via voice AI provider; run QA.
3. Transcribe final audio, proofread, and package with asset metadata.
4. Store audio + transcript in asset library.
