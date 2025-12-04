#!/bin/bash
# Search Cortex documents
# Usage: search.sh <query> [limit]

set -e

# Load credentials from .env (NEVER hardcode!)
if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
    set -a; source "/Users/adamkovacs/Documents/codebuild/.env"; set +a
fi

[ -z "$CORTEX_TOKEN" ] && { echo "Error: CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "Error: CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "Error: CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

QUERY="${1:-}"
LIMIT="${2:-20}"
CORTEX_URL="https://cortex.aienablement.academy"

if [ -z "$QUERY" ]; then
  echo "Usage: search.sh <query> [limit]"
  exit 1
fi

SQL="SELECT id, content, box FROM blocks WHERE type='d' AND content LIKE '%${QUERY}%' LIMIT ${LIMIT}"

curl -s -X POST "${CORTEX_URL}/api/query/sql" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"${SQL}\"}" | jq '.data[] | {id: .id, content: .content[0:100]}'
