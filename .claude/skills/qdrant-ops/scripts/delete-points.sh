#!/bin/bash
# Delete specific points by ID

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

COLLECTION="${1:-agent_memory}"
shift
POINT_IDS=("$@")

if [ ${#POINT_IDS[@]} -eq 0 ]; then
  echo "Usage: $0 <collection> <id1> [id2] [id3] ..."
  echo "Example: $0 agent_memory point-123 point-456"
  exit 1
fi

echo "Deleting points from Qdrant"
echo "Collection: $COLLECTION"
echo "Point IDs: ${POINT_IDS[*]}"
echo "==========================================="

# Build JSON array of IDs
IDS_JSON=$(printf '%s\n' "${POINT_IDS[@]}" | jq -R . | jq -s .)

# Delete points
RESPONSE=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/delete" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"points\": $IDS_JSON
  }")

echo "$RESPONSE" | jq '.'

if echo "$RESPONSE" | jq -e '.status == "ok"' > /dev/null; then
  echo -e "\nSuccess! Deleted ${#POINT_IDS[@]} points"
else
  echo -e "\nError deleting points"
  exit 1
fi
