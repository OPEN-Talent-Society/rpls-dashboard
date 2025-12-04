#!/bin/bash

# Load .env with exports
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Cortex Learning Capture Hook - Store learnings in knowledge base
# KEY LEARNINGS FROM CORTEX FIX PROJECT:
# 1. Use /api/block/insertBlock NOT /api/attr/setBlockAttrs for creating refs
# 2. Block reference syntax: ((block-id 'title')) in CONTENT creates refs
# 3. Backlinks appear on document whose ID is in refs.def_block_id
# 4. macOS uses bash 3.x - NO associative arrays (declare -A)
# 5. SiYuan must rebuild index after adding refs programmatically

set -e

TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
URL="https://cortex.aienablement.academy"

# Arguments
LEARNING_TITLE="${1:-New Learning}"
LEARNING_CONTENT="${2:-No content provided}"
CATEGORY="${3:-technical}"  # technical, process, integration, api

# Resources notebook for learnings (Updated 2025-12-01)
NOTEBOOK_ID="20251201183343-ujsixib"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create learning document
DOC_CONTENT="# Learning: ${LEARNING_TITLE}

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

ESCAPED_CONTENT=$(echo "$DOC_CONTENT" | sed 's/"/\\"/g' | tr '\n' ' ')

INSERT_RESULT=$(curl -s -X POST "${URL}/api/block/insertBlock" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"${ESCAPED_CONTENT}\", \"previousID\": \"\", \"parentID\": \"${NOTEBOOK_ID}\"}")

CODE=$(echo "$INSERT_RESULT" | jq -r '.code')
if [ "$CODE" = "0" ]; then
  echo "✅ Learning captured: ${LEARNING_TITLE}"
else
  echo "❌ Failed to capture learning"
  exit 1
fi
