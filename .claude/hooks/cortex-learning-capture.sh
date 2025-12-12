#!/bin/bash

# Load .env with exports
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Cortex Learning Capture Hook - Store learnings in knowledge base
# KEY LEARNINGS FROM CORTEX FIX PROJECT:
# 1. Use upsert_doc() to prevent duplicates (check-update-create pattern)
# 2. Source cortex-helpers.sh for shared upsert logic
# 3. Block reference syntax: ((block-id 'title')) in CONTENT creates refs
# 4. Backlinks appear on document whose ID is in refs.def_block_id
# 5. macOS uses bash 3.x - NO associative arrays (declare -A)
# 6. SiYuan must rebuild index after adding refs programmatically

set -e

# Source helper library for upsert logic
HELPER_LIB="${PROJECT_DIR}/.claude/lib/cortex-helpers.sh"
if [ ! -f "$HELPER_LIB" ]; then
    echo "❌ ERROR: Helper library not found: $HELPER_LIB"
    exit 1
fi
source "$HELPER_LIB"

# Arguments
LEARNING_TITLE="${1:-New Learning}"
LEARNING_CONTENT="${2:-No content provided}"
CATEGORY="${3:-technical}"  # technical, process, integration, api

# Resources notebook for learnings (Updated 2025-12-01)
NOTEBOOK_ID="20251201183343-ujsixib"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build learning document title
FULL_TITLE="Learning: ${LEARNING_TITLE}"

# Create learning document content
DOC_CONTENT="# ${FULL_TITLE}

**Category:** #${CATEGORY}
**Captured:** ${TIMESTAMP}

## Problem

[What was the issue?]

## Investigation

[What was tried?]

## Solution

${LEARNING_CONTENT}

## Key Insights

- ${LEARNING_TITLE}

## Tags

#learning #${CATEGORY}

---
*Auto-captured by cortex-learning-capture hook*
"

# Build document path (used for new documents)
DOC_PATH="learnings/${LEARNING_TITLE}.md"

# Build metadata (construct directly to avoid nesting issues, use -c for compact)
METADATA=$(jq -nc \
    --arg cat "$CATEGORY" \
    '{
        "custom-type": "learning",
        "custom-project": "codebuild",
        "custom-category": $cat
    }')

# UPSERT: Update if exists, create if not
DOC_ID=$(upsert_doc "$FULL_TITLE" "$DOC_CONTENT" "$NOTEBOOK_ID" "$DOC_PATH" "learning-hook" "$METADATA")

if [ -n "$DOC_ID" ]; then
    EXISTING_VERSION=$(get_doc_attribute "$DOC_ID" "custom-version")
    if [ "$EXISTING_VERSION" = "1" ]; then
        echo "✅ Learning created: ${LEARNING_TITLE} (ID: ${DOC_ID})"
    else
        echo "✅ Learning updated: ${LEARNING_TITLE} (ID: ${DOC_ID}, v${EXISTING_VERSION})"
    fi
else
    echo "❌ Failed to capture learning: ${LEARNING_TITLE}"
    exit 1
fi
