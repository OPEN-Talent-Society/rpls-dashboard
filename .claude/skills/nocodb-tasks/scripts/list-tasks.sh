#!/bin/bash
# List tasks from NocoDB using API v3 (embedded relations, richer data)
# Usage: list-tasks.sh [status]

set -e

# Load credentials from .env (NEVER hardcode!)
if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
    set -a; source "/Users/adamkovacs/Documents/codebuild/.env"; set +a
fi

[ -z "$NOCODB_URL" ] && { echo "Error: NOCODB_URL not set"; exit 1; }
[ -z "$NOCODB_DATABASE_ID" ] && { echo "Error: NOCODB_DATABASE_ID not set"; exit 1; }

# Use API token for REST calls
TOKEN="${NOCODB_API_TOKEN:-$NOCODB_MCP_TOKEN}"
[ -z "$TOKEN" ] && { echo "Error: NOCODB_API_TOKEN or NOCODB_MCP_TOKEN not set"; exit 1; }

STATUS="${1:-}"
TASKS_TABLE="${NOCODB_TASKS_TABLE_ID:-mmx3z4zxdj9ysfk}"

# Build where clause for v3 (supports quoted values)
if [ -n "$STATUS" ]; then
  WHERE="where=(Status,eq,\"${STATUS}\")"
else
  WHERE=""
fi

# API v3 endpoint: /api/v3/data/{baseId}/{tableId}/records
# v3 benefits: embedded relations (SPRINTS inline), standardized responses
curl -s --max-time 30 -X GET "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${TASKS_TABLE}/records?${WHERE}&limit=50" \
  -H "xc-token: ${TOKEN}" | jq '.records[] | {id: .id, name: .fields."task name", status: .fields.Status, priority: .fields.Priority, sprint: .fields.SPRINTS.fields."Sprint Name"}'
