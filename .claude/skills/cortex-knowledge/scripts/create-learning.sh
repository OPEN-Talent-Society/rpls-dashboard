#!/bin/bash
# Create a learning document in Cortex
# Usage: create-learning.sh "Title" "Content"

set -e

# Load credentials from .env (NEVER hardcode!)
if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
    set -a; source "/Users/adamkovacs/Documents/codebuild/.env"; set +a
fi

[ -z "$CORTEX_TOKEN" ] && { echo "Error: CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "Error: CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "Error: CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

TITLE="${1:-Untitled Learning}"
CONTENT="${2:-}"
CORTEX_URL="https://cortex.aienablement.academy"
NOTEBOOK="20251201183343-ujsixib"  # Resources notebook

# Sanitize title for path
PATH_TITLE=$(echo "$TITLE" | tr ' ' '-' | tr -cd '[:alnum:]-')

curl -s -X POST "${CORTEX_URL}/api/filetree/createDocWithMd" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"${NOTEBOOK}\",
    \"path\": \"/${PATH_TITLE}\",
    \"markdown\": \"# ${TITLE}\\n\\n${CONTENT}\"
  }" | jq

echo "Learning created: ${TITLE}"
