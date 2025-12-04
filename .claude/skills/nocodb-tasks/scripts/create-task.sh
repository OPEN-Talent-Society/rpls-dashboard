#!/bin/bash
# Create a task in NocoDB using API v3
# Usage: create-task.sh "Task title" "Status" "Priority"
# Priority values: "P1 (Top Priority)", "P2", "P3", or leave empty

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

TITLE="${1:-Untitled Task}"
STATUS="${2:-To Do}"
PRIORITY="${3:-}"
TASKS_TABLE="${NOCODB_TASKS_TABLE_ID:-mmx3z4zxdj9ysfk}"

# Build fields JSON - v3 uses "fields" wrapper
FIELDS="{\"task name\": \"${TITLE}\", \"Status\": \"${STATUS}\", \"Assignee\": [{\"id\": \"uskfxdybo8kofowf\"}]"

# Only add priority if provided (avoid validation errors)
if [ -n "$PRIORITY" ]; then
  FIELDS="${FIELDS}, \"Priority\": \"${PRIORITY}\""
fi

FIELDS="${FIELDS}}"

# API v3 endpoint: POST /api/v3/data/{baseId}/{tableId}/records
# v3 format: {"fields": {...}} wrapper required
curl -s --max-time 30 -X POST "${NOCODB_URL}/api/v3/data/${NOCODB_DATABASE_ID}/${TASKS_TABLE}/records" \
  -H "xc-token: ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"fields\": ${FIELDS}}" | jq '.records[0] | {id: .id, name: .fields."task name", status: .fields.Status}'

echo "Task created: ${TITLE}"
