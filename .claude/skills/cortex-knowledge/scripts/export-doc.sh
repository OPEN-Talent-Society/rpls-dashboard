#!/bin/bash
# Export a Cortex document to markdown
# Usage: export-doc.sh <document_id>

set -e

# Load credentials from .env (NEVER hardcode!)
if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
    set -a; source "/Users/adamkovacs/Documents/codebuild/.env"; set +a
fi

[ -z "$CORTEX_TOKEN" ] && { echo "Error: CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "Error: CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "Error: CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

DOC_ID="${1}"
CORTEX_URL="https://cortex.aienablement.academy"

if [ -z "$DOC_ID" ]; then
  echo "Usage: export-doc.sh <document_id>"
  exit 1
fi

curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"${DOC_ID}\"}" | jq -r '.data.content'
