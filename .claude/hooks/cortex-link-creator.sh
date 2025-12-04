#!/bin/bash

# Load .env with exports
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Cortex Link Creator Hook - Create bidirectional links between documents
# CRITICAL: Uses /api/block/insertBlock with ((block-id 'title')) syntax
# This creates ACTUAL refs that appear in the refs table and backlinks panel

set -e

TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
URL="https://cortex.aienablement.academy"

# Arguments
SOURCE_DOC_ID="${1}"
TARGET_DOC_ID="${2}"
TARGET_TITLE="${3:-Related Document}"

if [ -z "$SOURCE_DOC_ID" ] || [ -z "$TARGET_DOC_ID" ]; then
  echo "Usage: $0 <source_doc_id> <target_doc_id> [target_title]"
  echo "Example: $0 20241201123456-abc123 20241130111111-xyz789 'My Related Doc'"
  exit 1
fi

# Clean title for safe JSON
CLEAN_TITLE=$(echo "$TARGET_TITLE" | sed 's/["\\]//g' | head -c 50)

# Create link content using block reference syntax
# ((block-id 'anchor text')) creates a ref in the refs table
LINK_CONTENT="---\\n\\n**Related:** (($TARGET_DOC_ID '$CLEAN_TITLE'))"

INSERT_RESULT=$(curl -s -X POST "${URL}/api/block/insertBlock" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"${LINK_CONTENT}\", \"previousID\": \"\", \"parentID\": \"${SOURCE_DOC_ID}\"}")

CODE=$(echo "$INSERT_RESULT" | jq -r '.code')
if [ "$CODE" = "0" ]; then
  echo "✅ Link created: ${SOURCE_DOC_ID} → ${TARGET_DOC_ID}"
else
  MSG=$(echo "$INSERT_RESULT" | jq -r '.msg // "unknown error"')
  echo "❌ Failed: ${MSG}"
  exit 1
fi
