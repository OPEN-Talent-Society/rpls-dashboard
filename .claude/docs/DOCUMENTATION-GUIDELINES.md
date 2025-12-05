# Documentation Guidelines

> **Golden Rule**: One source of truth per topic. Update existing docs, don't create duplicates.

---

## Quick Decision Tree

```
Need to document something?
├─ Epic/task specification?
│  └─ UPDATE specs/sections/*.md (DON'T create new files)
│
├─ Deployment/operations guide?
│  └─ docs/operations/*.md
│
├─ Development/setup guide?
│  └─ docs/*.md or docs/setup/*.md
│
├─ Temporary analysis/report?
│  ├─ .claude/reports/*.md (mark with "DELETE AFTER REVIEW" header)
│  └─ DELETE after committing relevant changes
│
├─ Session summary/chat log?
│  └─ DON'T commit (delete after session)
│
└─ Reference documentation?
   └─ .claude/docs/ref/*.md
```

---

## Documentation Locations

### Project Documentation (`docs/`)

| Type | Path | Examples |
|------|------|----------|
| **Setup Guides** | `docs/setup/` | CONVEX-SETUP.md, AUTH-SETUP.md |
| **Development** | `docs/development/` | ACCESSIBILITY.md, SEED-DATA.md |
| **Database** | `docs/database/` | ERD.md, MIGRATION.md |
| **Operations** | `docs/operations/` | DEPLOYMENT-RUNBOOK.md, MONITORING-GUIDE.md |
| **Design System** | `docs/DESIGN-SYSTEM.md` | Brand guidelines, component patterns |
| **Integration Guides** | `docs/[SERVICE]-*.md` | STRIPE-PRODUCT-SYNC.md |

### Project Specifications (`specs/`)

| Type | Path | Purpose |
|------|------|---------|
| **Epic Specs** | `specs/` | Top-level specifications (DON'T duplicate) |
| **Detailed Specs** | `specs/sections/` | Schema, SDK, features (UPDATE these) |

### Claude Configuration (`.claude/docs/`)

| Type | Path | Purpose |
|------|------|---------|
| **SOPs** | `.claude/docs/*.md` | MEMORY-SOP.md, CORTEX-API-OPS.md |
| **References** | `.claude/docs/ref/` | Quick reference guides |
| **Indexes** | `.claude/docs/*-INDEX.md` | Tool references, asset indexes |

### Temporary Files (`.claude/reports/`)

**IMPORTANT**: All files here are TEMPORARY and must be deleted after use.

```markdown
# [REPORT TITLE]

**Status**: DELETE AFTER REVIEW
**Created**: YYYY-MM-DD
**Purpose**: [Why this was created]
**Action Required**: [What to do with this information]

[Content...]
```

---

## Prohibited Practices

### ❌ NEVER Do This

1. **Root Directory Documentation**
   ```
   ❌ /project-root/SESSION-SUMMARY.md
   ❌ /project-root/ANALYSIS-REPORT.md
   ❌ /project-root/VERIFICATION-REPORT.md
   ```

2. **Duplicate Specifications**
   ```
   ❌ Create new summary file when spec exists
   ❌ E1.2-VERIFICATION-REPORT.md (when specs/E1.2.md exists)
   ❌ FEATURE-SUMMARY.md (when specs/sections/feature.md exists)
   ```

3. **Permanent Session Logs**
   ```
   ❌ Commit chat transcripts
   ❌ Commit session summaries
   ❌ Commit "what we did today" files
   ```

4. **Nested Temporary Files**
   ```
   ❌ docs/TEMP-ANALYSIS.md
   ❌ specs/VERIFICATION-REPORT.md
   ✅ .claude/reports/analysis-YYYY-MM-DD.md (then DELETE)
   ```

### ✅ ALWAYS Do This

1. **Update Existing Specs**
   ```
   ✅ Update specs/sections/01-schema.md with new schema
   ✅ Update docs/operations/DEPLOYMENT-RUNBOOK.md with new steps
   ✅ Update docs/DESIGN-SYSTEM.md with new components
   ```

2. **Use Temporary Reports Correctly**
   ```
   ✅ Create .claude/reports/verification-2024-12-04.md
   ✅ Add "DELETE AFTER REVIEW" header
   ✅ Delete after incorporating findings into specs
   ```

3. **Follow Directory Structure**
   ```
   ✅ Operations guide → docs/operations/
   ✅ Setup guide → docs/setup/
   ✅ Epic spec → specs/
   ✅ Detailed spec → specs/sections/
   ```

---

## File Lifecycle

### Permanent Documentation

```
1. Create in correct directory (see table above)
2. Update as needed
3. Keep as single source of truth
4. Reference from other docs (don't duplicate)
```

### Temporary Reports

```
1. Create in .claude/reports/[name]-[date].md
2. Add "DELETE AFTER REVIEW" header
3. Review findings
4. Update relevant permanent docs
5. DELETE temporary report
6. Commit changes
```

### Session Summaries

```
1. DON'T create session summary files
2. If insights are valuable:
   - Update relevant specs/docs
   - Store pattern in AgentDB
   - Sync to Cortex knowledge base
3. DON'T commit chat transcripts
```

---

## Naming Conventions

### ✅ Good Names

```
DEPLOYMENT-RUNBOOK.md       # Clear purpose
STRIPE-PRODUCT-SYNC.md      # Specific integration
MONITORING-GUIDE.md         # Clear scope
verification-2024-12-04.md  # Temporary, dated
```

### ❌ Bad Names

```
REPORT.md                   # Too generic
SUMMARY.md                  # What summary?
NOTES.md                    # No context
SESSION-LOG.md              # Don't commit these
VERIFICATION-REPORT.md      # Missing date, unclear permanence
```

---

## Documentation Standards

### Required Headers

```markdown
# [Document Title]

**Purpose**: [What this document covers]
**Audience**: [Who should read this]
**Last Updated**: YYYY-MM-DD

## Contents

[Clear table of contents for docs > 100 lines]
```

### For Temporary Reports

```markdown
# [Report Title]

**Status**: DELETE AFTER REVIEW
**Created**: YYYY-MM-DD
**Purpose**: [Why this was created]
**Action Required**: [What needs to be done]
**Delete After**: [Specific milestone or date]

[Content...]

---

## Cleanup Checklist

- [ ] Findings incorporated into specs/sections/*.md
- [ ] Permanent docs updated
- [ ] This file ready for deletion
```

---

## Examples

### Example 1: Epic Verification

**Wrong Approach:**
```
Create: docs/E1.2-VERIFICATION-REPORT.md (permanent file in docs/)
```

**Correct Approach:**
```
1. Create: .claude/reports/e1.2-verification-2024-12-04.md
2. Add "DELETE AFTER REVIEW" header
3. Review findings
4. Update: specs/sections/01-schema.md with corrections
5. Update: specs/E1.2.md with completion notes
6. Delete: .claude/reports/e1.2-verification-2024-12-04.md
7. Commit updates to specs
```

### Example 2: New Feature Documentation

**Wrong Approach:**
```
Create: STRIPE-INTEGRATION-SUMMARY.md in root
```

**Correct Approach:**
```
Update existing: docs/STRIPE-PRODUCT-SYNC.md
OR
Create new: docs/STRIPE-WEBHOOKS.md (if distinct topic)
```

### Example 3: Operations Playbook

**Wrong Approach:**
```
Create: DEPLOYMENT-STEPS.md in root
```

**Correct Approach:**
```
Update: docs/operations/DEPLOYMENT-RUNBOOK.md
Add section for new deployment steps
```

---

## Cleanup Commands

### Find Misplaced Documentation

```bash
# Find markdown files in project root
find /path/to/project -maxdepth 1 -name "*.md" -not -name "README.md" -not -name "CLAUDE.md"

# Find temporary files that should be deleted
grep -r "DELETE AFTER" --include="*.md" .
```

### Review Temporary Reports

```bash
# List all temporary reports
ls -la .claude/reports/

# Check age of temporary files
find .claude/reports/ -type f -mtime +7
```

---

## Migration Checklist

When cleaning up existing documentation:

- [ ] Identify duplicate content
- [ ] Find canonical source (specs, docs/operations, etc.)
- [ ] Merge unique insights into canonical source
- [ ] Delete duplicates
- [ ] Update cross-references
- [ ] Commit changes with clear message

---

## Quick Reference

| Question | Answer |
|----------|--------|
| Where do epic specs go? | `specs/` (top level) or `specs/sections/` (detailed) |
| Where do deployment guides go? | `docs/operations/` |
| Where do setup guides go? | `docs/setup/` |
| Where do temporary reports go? | `.claude/reports/` (DELETE after use) |
| Can I create docs in project root? | ❌ NO (except README.md, CLAUDE.md) |
| Should I commit session summaries? | ❌ NO (update specs/docs, then delete) |
| How do I handle verification reports? | Temporary in `.claude/reports/`, update specs, delete report |
| What if I'm not sure? | Ask: "Does this replace or duplicate existing docs?" |

---

## Enforcement

1. **Pre-commit Check**: No `.md` files in project root (except README, CLAUDE)
2. **Weekly Review**: Check `.claude/reports/` for files older than 7 days
3. **Spec Updates**: Prefer updating existing specs over creating summaries
4. **One Source of Truth**: If topic exists, update it. Don't create new doc.

---

**Remember**: Documentation is for finding information, not storing it. Keep it organized, keep it updated, keep it clean.
