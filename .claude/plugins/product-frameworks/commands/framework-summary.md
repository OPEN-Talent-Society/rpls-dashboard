---
description: "Generate executive-ready summary consolidating artifacts from the PRD, Spec Kit, BMAD, and SPARC workflows"
argument-hint: "[docmost urls]"
allowed-tools: ["Read", "WebFetch", "NotebookWrite", "WebSearch"]
---

# Framework Summary

Produce a concise snapshot across PRD, Spec Kit, BMAD, and SPARC deliverables for leadership updates or portfolio reviews.

## Inputs
- URLs or paths to Docmost documents.
- Current project status from NocoDB (if available).
- Latest metrics dashboards or launch reports.

## Steps
1. **Collect Artifacts**
   - Download or fetch text from referenced Docmost pages.
   - Parse headings to extract key sections (Goals, Assumptions, Results).

2. **Synthesize Highlights**
   - Summarize problem/opportunity from PRD.
   - Outline chosen solution path, release slices, and guardrails from Spec Kit.
   - Surface investment decision and rationale from BMAD.
   - Capture outcomes, metrics, and next actions from SPARC.

3. **Risk & Dependency Scan**
   - List unresolved assumptions or blockers.
   - Highlight cross-team dependencies and due dates.

4. **Action Plan**
   - Provide 30/60/90 day milestones.
   - Recommend upcoming framework refresh (e.g., revisit BMAD quarterly).

## Output Template
```markdown
# Product Framework Summary – <Project>

## Snapshot
- Stage: Discovery | Build | Launch | Live
- Decision: Proceed | Pause | Pivot (from BMAD)

## Key Points
- PRD Highlights: ...
- Spec Kit Highlights: ...
- BMAD Highlights: ...
- SPARC Highlights: ...

## Metrics
- Success KPI: value (source, date)
- Guardrail KPI: value (source, date)

## Risks & Mitigations
- Risk / Impact / Owner / Status

## Next Actions
1. ...
2. ...
3. ...

## References
- PRD: <link>
- Spec Kit: <link>
- BMAD: <link>
- SPARC: <link>
- NocoDB Row: <link>
```

## Tips
- If any artifact missing, flag it and suggest responsible owner to fill gap.
- Use consistent currency/date formats to aid comparison.
- Keep summary under one screenful for quick executive read.
