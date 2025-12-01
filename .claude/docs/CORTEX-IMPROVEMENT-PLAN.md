# Cortex Excellence Improvement Plan

**Created**: 2025-12-01
**Based on**: 20-Agent Swarm Audit Results
**Current Feature Utilization**: 19% → Target: 60%+

## Executive Summary

The Cortex Excellence Audit revealed that only **19% of SiYuan features** are currently utilized. This plan outlines 5 phases to dramatically improve knowledge management capabilities.

---

## Current State (Post-Audit)

| Metric | Value | Status |
|--------|-------|--------|
| Total Documents | 428 | ✅ Growing |
| Orphan Rate | 2.1% (9 docs) | ✅ Excellent |
| Total References | 1,051 | 🟡 Could be denser |
| Custom Attributes | 99.5% | ✅ Excellent |
| Feature Utilization | 19% | 🔴 Critical Gap |

### Unused Features Identified

| Feature | Utilization | Impact |
|---------|-------------|--------|
| **Widgets/Dashboards** | 0% | High - visual overviews |
| **SQL Query Widgets** | 0% | High - live data views |
| **Block Embedding** | 5% | High - content reuse |
| **Super Blocks** | 0% | Medium - layouts |
| **Flashcards** | 0% | Medium - spaced repetition |
| **Graph View** | 10% | Low - already good refs |
| **Daily Notes** | 0% | Medium - journal pattern |
| **Templates** | 15% | Medium - need more |

---

## Phase 1: Quick Wins (Day 1-2)

### 1.1 Fix Remaining Orphans

**Current orphans** (9 documents):
- 6 archived whisper-stack docs
- 1 jellyfin fix (archived)
- 1 PayloadCMS learning (needs link)
- 1 Audit summary (needs link)

**Action**: Run orphan fix script
```bash
.claude/hooks/cortex-fix-orphans.sh
```

### 1.2 Enable Daily Notes

Create daily note template for automatic journaling:

```yaml
# Daily Note Template
---
title: Daily - {{date}}
type: daily
created: {{date}}
agent: claude-code@aienablement.academy
---

## Today's Focus
- [ ] Priority 1
- [ ] Priority 2

## Completed
-

## Learnings
-

## Blockers
-

## Tomorrow
-

---
{: custom-type="daily" custom-date="{{date}}" }
```

---

## Phase 2: Implement Widgets & Dashboards (Day 3-5)

### 2.1 Knowledge Dashboard Widget

Create SQL widget for knowledge overview:

```sql
-- Create in SiYuan: Insert > Widget > SQL

SELECT
  box,
  COUNT(*) as docs,
  COUNT(CASE WHEN ial LIKE '%custom-type="learning"%' THEN 1 END) as learnings,
  COUNT(CASE WHEN ial LIKE '%custom-type="task"%' THEN 1 END) as tasks
FROM blocks
WHERE type='d'
GROUP BY box
```

### 2.2 Recent Activity Widget

```sql
SELECT
  content,
  updated,
  CASE
    WHEN ial LIKE '%custom-type="learning"%' THEN '📚'
    WHEN ial LIKE '%custom-type="task"%' THEN '✅'
    WHEN ial LIKE '%custom-type="adr"%' THEN '📋'
    ELSE '📄'
  END as icon
FROM blocks
WHERE type='d'
ORDER BY updated DESC
LIMIT 10
```

### 2.3 Sprint Progress Widget

```sql
SELECT
  content,
  ial
FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-type="task"%'
  AND ial LIKE '%custom-status="in_progress"%'
ORDER BY updated DESC
```

---

## Phase 3: Template Standardization (Day 6-10)

### 3.1 Enforce Progressive Disclosure

All documents MUST follow this pattern:

```markdown
# Title

> **TLDR**: One-sentence summary

## Key Points {: data-fold="1" }
- Point 1
- Point 2

## Details {: data-fold="0" }
[Hidden by default]

## Technical Notes {: data-fold="0" }
[Hidden by default]
```

### 3.2 Standard Templates

| Template | Notebook | Auto-Metadata |
|----------|----------|---------------|
| Learning | Resources | `custom-type="learning"` |
| Task | Projects | `custom-type="task"`, `custom-priority` |
| ADR | KB | `custom-type="adr"`, `custom-status` |
| SOP | Resources | `custom-type="sop"`, `custom-version` |
| Meeting | Areas | `custom-type="meeting"` |
| Daily | Areas | `custom-type="daily"`, `custom-date` |
| Reference | Resources | `custom-type="reference"` |
| Project | Projects | `custom-type="project"` |

### 3.3 Retroactive Template Application

Script to update existing docs:
```bash
#!/bin/bash
# Apply standard attributes to existing documents

# Find docs without custom-type
curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -d '{"stmt": "SELECT id, content FROM blocks WHERE type=\"d\" AND ial NOT LIKE \"%custom-type%\" LIMIT 50"}'

# Apply based on content patterns:
# - Contains "Learning" → custom-type="learning"
# - Contains "Task" → custom-type="task"
# - Contains "ADR" → custom-type="adr"
```

---

## Phase 4: AI Context Loading (Day 11-15)

### 4.1 Quick Context Queries

Create reusable SQL queries for AI agents:

**Recent Learnings**:
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-type="learning"%'
  AND updated > date('now', '-7 days')
ORDER BY updated DESC
LIMIT 5
```

**Active Tasks**:
```sql
SELECT id, content FROM blocks
WHERE type='d'
  AND ial LIKE '%custom-type="task"%'
  AND ial LIKE '%custom-status="in_progress"%'
```

**Related Context**:
```sql
SELECT b.id, b.content FROM blocks b
JOIN refs r ON b.id = r.def_block_id
WHERE r.block_id IN (
  SELECT id FROM blocks WHERE content LIKE '%SEARCH_TERM%'
)
```

### 4.2 Context Loading Skill

Create `.claude/skills/cortex-context-loader.md`:

```markdown
# Cortex Context Loader

## Quick Scan (< 1000 tokens)
Load TLDR and Key Points only for broad context.

## Deep Dive (full document)
When topic matches closely, load complete document.

## Related Context
Follow refs to build context graph for interconnected topics.
```

---

## Phase 5: Automation & Maintenance (Day 16-20)

### 5.1 Scheduled Health Checks

Create cron-style maintenance:

```bash
#!/bin/bash
# cortex-health-cron.sh
# Run daily at midnight

# 1. Find orphans
ORPHANS=$(cortex-check-orphans.sh)
if [ "$ORPHANS" -gt 5 ]; then
  cortex-fix-orphans.sh
fi

# 2. Archive old tasks
cortex-archive-old.sh --days 30

# 3. Generate health report
cortex-health-report.sh > /tmp/cortex-health-$(date +%Y%m%d).txt
```

### 5.2 Auto-Archive Rule

Documents meeting these criteria auto-move to Archives:
- Status = "Done"
- Updated > 30 days ago
- Type = "task" or "meeting"

### 5.3 Weekly Knowledge Digest

Auto-generate weekly summary:
- New learnings this week
- Completed tasks
- Active projects status
- Orphan count trend

---

## Implementation Schedule

| Week | Phase | Focus |
|------|-------|-------|
| Week 1 | Phase 1 + 2 | Fix orphans, create dashboards |
| Week 2 | Phase 3 | Template standardization |
| Week 3 | Phase 4 | AI context queries |
| Week 4 | Phase 5 | Automation setup |

---

## Success Metrics

| Metric | Current | Week 2 | Week 4 | Target |
|--------|---------|--------|--------|--------|
| Feature Utilization | 19% | 35% | 50% | 60% |
| Orphan Rate | 2.1% | <1% | <1% | <1% |
| Widget Usage | 0 | 3 | 5 | 5+ |
| Template Compliance | 15% | 50% | 80% | 90% |
| Daily Notes | 0 | 7 | 14 | Daily |
| Auto-Archive | No | No | Yes | Yes |

---

## Deliverables Checklist

### Phase 1 (Quick Wins)
- [ ] Fix 9 orphan documents
- [ ] Enable daily notes template
- [ ] Create PARA index documents

### Phase 2 (Widgets)
- [ ] Knowledge dashboard widget
- [ ] Recent activity widget
- [ ] Sprint progress widget
- [ ] Orphan monitor widget

### Phase 3 (Templates)
- [ ] 8 standard templates created
- [ ] Progressive disclosure enforced
- [ ] Retroactive metadata applied

### Phase 4 (AI Context)
- [ ] 5+ quick context queries
- [ ] Context loader skill
- [ ] Agent memory integration

### Phase 5 (Automation)
- [ ] Health check cron
- [ ] Auto-archive rule
- [ ] Weekly digest generator

---

## Quick Start Commands

```bash
# Check current health
.claude/hooks/cortex-health-check.sh

# Fix orphans
.claude/hooks/cortex-fix-orphans.sh

# Create document from template
.claude/hooks/cortex-template-create.sh learning "Topic Name"

# Export document
/cortex-export <doc-id> md

# Search knowledge base
/cortex-search "query"
```

---

*Plan Version: 1.0.0 | Created: 2025-12-01 | Owner: claude-code@aienablement.academy*
