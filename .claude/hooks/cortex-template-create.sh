#!/bin/bash

# Load .env with exports
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# cortex-template-create.sh - Create documents from SiYuan templates
# Uses Templates API for consistent document creation (underutilized feature)
# Updated: 2025-12-01

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
URL="https://cortex.aienablement.academy"

# PARA Notebook IDs (2025-12-01)
NOTEBOOK_PROJECTS="20251103053911-8ex6uns"
NOTEBOOK_AREAS="20251201183343-543piyt"
NOTEBOOK_RESOURCES="20251201183343-ujsixib"
NOTEBOOK_ARCHIVES="20251201183343-xf2snc8"
NOTEBOOK_KB="20251103053840-moamndp"

# ============================================================================
# USAGE
# ============================================================================
usage() {
    cat << EOF
Usage: $0 <template_type> <title> [notebook] [extra_vars]

Template Types:
  learning     - Learning/Discovery document
  task         - Task documentation
  adr          - Architecture Decision Record
  sop          - Standard Operating Procedure
  meeting      - Meeting notes
  daily        - Daily log entry
  project      - Project overview
  reference    - Reference documentation

Arguments:
  template_type  Required. One of the template types above.
  title          Required. Document title.
  notebook       Optional. Target notebook (projects|areas|resources|archives|kb).
                 Defaults based on template type.
  extra_vars     Optional. JSON object with additional template variables.

Examples:
  $0 learning "SiYuan Templates API" resources
  $0 task "Implement Auth Flow" projects '{"priority":"P1","sprint":"SP04"}'
  $0 adr "Use PostgreSQL for Metadata"
  $0 daily "2025-12-01"

EOF
    exit 1
}

# ============================================================================
# TEMPLATE DEFINITIONS
# ============================================================================

get_learning_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: Learning - ${title}
created: ${date}
agent: ${agent}
type: learning
tags: [learning]
---

# ${title}

## Context
What prompted this learning?

## Discovery
What was learned? Technical details.

## Application
How was it applied? Code examples.

## Key Insights
- Insight 1
- Insight 2
- Insight 3

## Related
- [[Related Doc 1]]
- [[Related Doc 2]]

## Tags
#learning #technical

---
*Logged by ${agent} on ${date}*
{: custom-agent="${agent}" custom-type="learning" }
EOF
}

get_task_template() {
    local title="$1"
    local date="$2"
    local agent="$3"
    local priority="${4:-P2}"
    local sprint="${5:-Current}"

    cat << EOF
---
title: Task - ${title}
created: ${date}
agent: ${agent}
type: task
status: in_progress
priority: ${priority}
sprint: ${sprint}
---

# ${title}

**Priority**: ${priority} | **Sprint**: ${sprint} | **Status**: In Progress

## Objective
[DESCRIPTION]

## Work Performed
### Actions
1. Action 1
2. Action 2

### Decisions Made
- Decision 1: Rationale
- Decision 2: Rationale

### Files Changed
- \`path/to/file.ts\` - Description

## Findings
- Finding 1
- Finding 2

## Learnings
- [[Learning-Topic-1]]

## Status
In Progress - [SUMMARY]

---
{: custom-agent="${agent}" custom-type="task" custom-priority="${priority}" }
EOF
}

get_adr_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: ADR - ${title}
created: ${date}
agent: ${agent}
type: adr
status: proposed
---

# ADR: ${title}

## Status
Proposed

## Context
What is the issue we're facing? What forces are at play?

## Decision
What did we decide? Be specific.

## Consequences

### Positive
- Benefit 1
- Benefit 2

### Negative
- Drawback 1
- Drawback 2

### Neutral
- Impact 1

## Alternatives Considered
1. **Alternative 1**: Description - Why rejected
2. **Alternative 2**: Description - Why rejected

## Related
- [[Related ADR 1]]
- [[Related Doc 1]]

---
{: custom-type="adr" custom-status="proposed" }
EOF
}

get_sop_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: SOP - ${title}
created: ${date}
agent: ${agent}
type: sop
version: 1.0
---

# SOP: ${title}

## Purpose
Why does this procedure exist?

## Scope
Who/what does this apply to?

## Prerequisites
- Prerequisite 1
- Prerequisite 2

## Procedure

### Step 1: [Step Name]
Description of step 1.

### Step 2: [Step Name]
Description of step 2.

### Step 3: [Step Name]
Description of step 3.

## Verification
How to verify successful completion?

## Troubleshooting
| Issue | Cause | Resolution |
|-------|-------|------------|
| Issue 1 | Cause 1 | Fix 1 |

## Related
- [[Related SOP]]
- [[Related Reference]]

---
{: custom-type="sop" custom-version="1.0" }
EOF
}

get_meeting_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: Meeting - ${title}
created: ${date}
agent: ${agent}
type: meeting
---

# Meeting: ${title}

**Date**: ${date}
**Attendees**: [List attendees]
**Duration**: [Duration]

## Agenda
1. Topic 1
2. Topic 2
3. Topic 3

## Discussion

### Topic 1
Notes on topic 1.

### Topic 2
Notes on topic 2.

## Decisions
- [ ] Decision 1
- [ ] Decision 2

## Action Items
| Action | Owner | Due Date |
|--------|-------|----------|
| Action 1 | Person | Date |

## Next Steps
- Next step 1
- Next step 2

---
{: custom-type="meeting" }
EOF
}

get_daily_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: Daily Log - ${title}
created: ${date}
agent: ${agent}
type: daily
---

# Daily Log: ${title}

## Summary
Brief overview of the day's activities.

## Completed
- [x] Task 1
- [x] Task 2

## In Progress
- [ ] Task 3
- [ ] Task 4

## Blockers
- Blocker 1 (if any)

## Learnings
- Learning 1
- Learning 2

## Tomorrow
- Priority 1
- Priority 2

## Metrics
| Metric | Value |
|--------|-------|
| Tasks Completed | X |
| Learnings Captured | X |

---
{: custom-type="daily" custom-date="${date}" }
EOF
}

get_project_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: Project - ${title}
created: ${date}
agent: ${agent}
type: project
status: active
---

# Project: ${title}

## Overview
Brief description of the project.

## Goals
1. Goal 1
2. Goal 2
3. Goal 3

## Scope
### In Scope
- Item 1
- Item 2

### Out of Scope
- Item 1

## Timeline
| Phase | Start | End | Status |
|-------|-------|-----|--------|
| Phase 1 | Date | Date | Status |

## Team
| Role | Person |
|------|--------|
| Lead | Person |

## Key Documents
- [[Design Doc]]
- [[Requirements]]

## Status Updates
### ${date}
Initial project setup.

---
{: custom-type="project" custom-status="active" }
EOF
}

get_reference_template() {
    local title="$1"
    local date="$2"
    local agent="$3"

    cat << EOF
---
title: Reference - ${title}
created: ${date}
agent: ${agent}
type: reference
---

# ${title}

## Overview
What is this reference about?

## Quick Reference
| Item | Value |
|------|-------|
| Item 1 | Value 1 |

## Details

### Section 1
Details for section 1.

### Section 2
Details for section 2.

## Examples

### Example 1
\`\`\`
Code or example here
\`\`\`

## Related
- [[Related Reference 1]]
- [[Related Reference 2]]

## Tags
#reference #documentation

---
{: custom-type="reference" }
EOF
}

# ============================================================================
# NOTEBOOK SELECTION
# ============================================================================

get_default_notebook() {
    local template_type="$1"

    case "$template_type" in
        learning|reference|sop)
            echo "resources"
            ;;
        task|project)
            echo "projects"
            ;;
        adr)
            echo "kb"
            ;;
        meeting|daily)
            echo "areas"
            ;;
        *)
            echo "resources"
            ;;
    esac
}

get_notebook_id() {
    local notebook="$1"

    case "$notebook" in
        projects)
            echo "$NOTEBOOK_PROJECTS"
            ;;
        areas)
            echo "$NOTEBOOK_AREAS"
            ;;
        resources)
            echo "$NOTEBOOK_RESOURCES"
            ;;
        archives)
            echo "$NOTEBOOK_ARCHIVES"
            ;;
        kb|knowledge_base)
            echo "$NOTEBOOK_KB"
            ;;
        *)
            echo "$NOTEBOOK_RESOURCES"
            ;;
    esac
}

# ============================================================================
# API FUNCTIONS
# ============================================================================

create_document() {
    local notebook_id="$1"
    local path="$2"
    local markdown="$3"

    local response
    response=$(curl -s -X POST "${URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"notebook\": \"${notebook_id}\",
            \"path\": \"${path}\",
            \"markdown\": $(echo "$markdown" | jq -Rs .)
        }")

    echo "$response"
}

set_block_attrs() {
    local block_id="$1"
    local attrs="$2"

    curl -s -X POST "${URL}/api/attr/setBlockAttrs" \
        -H "Authorization: Token ${TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"${block_id}\",
            \"attrs\": ${attrs}
        }"
}

# ============================================================================
# MAIN
# ============================================================================

# Check arguments
if [ $# -lt 2 ]; then
    usage
fi

TEMPLATE_TYPE="$1"
TITLE="$2"
NOTEBOOK="${3:-$(get_default_notebook "$TEMPLATE_TYPE")}"
EXTRA_VARS="${4:-{}}"

# Get current date and agent
DATE=$(date +%Y-%m-%d)
AGENT="${CLAUDE_VARIANT:-claude-code}@aienablement.academy"

# Parse extra vars for specific templates
PRIORITY=$(echo "$EXTRA_VARS" | jq -r '.priority // "P2"' 2>/dev/null || echo "P2")
SPRINT=$(echo "$EXTRA_VARS" | jq -r '.sprint // "Current"' 2>/dev/null || echo "Current")

# Generate template content
case "$TEMPLATE_TYPE" in
    learning)
        CONTENT=$(get_learning_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="Learnings/$(date +%Y-%m)"
        ;;
    task)
        CONTENT=$(get_task_template "$TITLE" "$DATE" "$AGENT" "$PRIORITY" "$SPRINT")
        PATH_PREFIX="Tasks/$(date +%Y-%m)"
        ;;
    adr)
        CONTENT=$(get_adr_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="ADRs"
        ;;
    sop)
        CONTENT=$(get_sop_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="SOPs"
        ;;
    meeting)
        CONTENT=$(get_meeting_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="Meetings/$(date +%Y-%m)"
        ;;
    daily)
        CONTENT=$(get_daily_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="Daily/$(date +%Y-%m)"
        ;;
    project)
        CONTENT=$(get_project_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="Projects"
        ;;
    reference)
        CONTENT=$(get_reference_template "$TITLE" "$DATE" "$AGENT")
        PATH_PREFIX="References"
        ;;
    *)
        echo "Error: Unknown template type: $TEMPLATE_TYPE"
        usage
        ;;
esac

# Get notebook ID
NOTEBOOK_ID=$(get_notebook_id "$NOTEBOOK")

# Clean title for path (replace spaces with hyphens, remove special chars)
CLEAN_TITLE=$(echo "$TITLE" | tr ' ' '-' | tr -cd '[:alnum:]-_')

# Create document path
DOC_PATH="/${PATH_PREFIX}/${CLEAN_TITLE}"

echo "Creating document from template..."
echo "  Template: $TEMPLATE_TYPE"
echo "  Title: $TITLE"
echo "  Notebook: $NOTEBOOK ($NOTEBOOK_ID)"
echo "  Path: $DOC_PATH"

# Create the document
RESPONSE=$(create_document "$NOTEBOOK_ID" "$DOC_PATH" "$CONTENT")

# Extract document ID from response
DOC_ID=$(echo "$RESPONSE" | jq -r '.data // empty' 2>/dev/null)

if [ -n "$DOC_ID" ] && [ "$DOC_ID" != "null" ]; then
    echo "✅ Document created successfully!"
    echo "  Document ID: $DOC_ID"

    # Set additional attributes
    ATTRS="{\"custom-template\":\"${TEMPLATE_TYPE}\",\"custom-created-by\":\"${AGENT}\",\"custom-created-date\":\"${DATE}\"}"
    set_block_attrs "$DOC_ID" "$ATTRS" > /dev/null

    echo "  Attributes set: template=$TEMPLATE_TYPE, agent=$AGENT"
    echo ""
    echo "Document URL: ${URL}/#${DOC_ID}"
else
    echo "❌ Failed to create document"
    echo "Response: $RESPONSE"
    exit 1
fi
