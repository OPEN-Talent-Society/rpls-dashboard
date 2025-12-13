#!/bin/bash
# Export all points from a collection to JSON

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

COLLECTION="${1:-agent_memory}"
OUTPUT_FILE="${2:-${COLLECTION}-export-$(date +%Y%m%d-%H%M%S).json}"

echo "Exporting Qdrant collection: $COLLECTION"
echo "Output file: $OUTPUT_FILE"
echo "==========================================="

# Initialize output
echo "[" > "$OUTPUT_FILE"

OFFSET=""
PAGE=1
TOTAL=0

while true; do
  echo "Fetching page $PAGE..."

  # Scroll through points
  if [ -z "$OFFSET" ]; then
    RESPONSE=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/scroll" \
      -H "api-key: ${QDRANT_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{
        "limit": 100,
        "with_payload": true,
        "with_vector": false
      }')
  else
    RESPONSE=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/scroll" \
      -H "api-key: ${QDRANT_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "{
        \"limit\": 100,
        \"offset\": \"$OFFSET\",
        \"with_payload\": true,
        \"with_vector\": false
      }")
  fi

  POINTS=$(echo "$RESPONSE" | jq '.result.points')
  COUNT=$(echo "$POINTS" | jq 'length')

  if [ "$COUNT" -eq 0 ]; then
    break
  fi

  # Append points (with comma separator except for first page)
  if [ $PAGE -gt 1 ]; then
    echo "," >> "$OUTPUT_FILE"
  fi
  echo "$POINTS" | jq -c '.[]' | tr '\n' ',' | sed 's/,$//' >> "$OUTPUT_FILE"

  TOTAL=$((TOTAL + COUNT))
  echo "Exported $COUNT points (total: $TOTAL)"

  # Get next offset
  NEXT_OFFSET=$(echo "$RESPONSE" | jq -r '.result.next_page_offset // empty')
  if [ -z "$NEXT_OFFSET" ]; then
    break
  fi
  OFFSET="$NEXT_OFFSET"
  PAGE=$((PAGE + 1))
done

echo "]" >> "$OUTPUT_FILE"

echo -e "\n==========================================="
echo "Export complete!"
echo "Total points: $TOTAL"
echo "File: $OUTPUT_FILE"
