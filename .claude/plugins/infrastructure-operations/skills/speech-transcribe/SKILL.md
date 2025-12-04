---
name: speech-transcribe
description: Transcribe audio using Whisper service with compliance and redaction controls
status: draft
owner: ml-ops
last_reviewed_at: 2025-10-28
tags:
  - audio
dependencies:
  - whisper-service-ops
outputs:
  - transcript
---

# Speech Transcribe Skill

Submit audio files, retrieve transcripts, redact sensitive information, and store results.

## Steps
1. Upload audio (via secure channel) to Whisper API.
2. Retrieve transcript, detect PII, apply redactions.
3. Format output (Markdown/JSON) and attach to Docmost page.
4. Delete raw audio per retention policy.
