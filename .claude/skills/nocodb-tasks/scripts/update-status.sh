#!/bin/bash
# Update task status in NocoDB using API v3
# Usage: update-status.sh <task_id> <new_status>

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

TASK_ID="${1}"
NEW_STATUS="${2:-Done}"
TASKS_TABLE="${NOCODB_TASKS_TABLE_ID:-mmx3z4zxdj9ysfk}"

if [ -z "$TASK_ID" ]; then
  echo "Usage: update-status.sh <task_id> <status>"
  echo "Statuses: To Do, In Progress, Review/QA, Done, Blocked, Backlog"
  exit 1
fi

# API v3 endpoint: PATCH /api/v3/data/{baseId}/{tableId}/records
# v3 format: [{"id": X, "fields": {...}}] array
curl -s --max-time 30 -X PATCH "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${TASKS_TABLE}/records" \
  -H "xc-token: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "[{\"id\": ${TASK_ID}, \"fields\": {\"Status\": \"${NEW_STATUS}\"}}]" | jq '.records[0] | {id: .id, status: .fields.Status}'

echo "Task ${TASK_ID} updated to: ${NEW_STATUS}"
