#!/bin/bash
# Batch upsert points from JSON file with automatic embedding generation

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

JSON_FILE="${1:-}"
COLLECTION="${2:-agent_memory}"
BATCH_SIZE="${3:-100}"

if [ -z "$JSON_FILE" ] || [ ! -f "$JSON_FILE" ]; then
  echo "Usage: $0 <json_file> [collection] [batch_size]"
  echo ""
  echo "JSON file format:"
  echo '[
  {
    "id": "unique-id-1",
    "content": "text to embed",
    "metadata": {"key": "value"}
  },
  ...
]'
  exit 1
fi

echo "Batch upserting to Qdrant"
echo "Collection: $COLLECTION"
echo "Batch size: $BATCH_SIZE"
echo "==========================================="

# Read JSON file
ITEMS=$(cat "$JSON_FILE")
TOTAL=$(echo "$ITEMS" | jq 'length')

echo "Total items to process: $TOTAL"

# Process in batches
BATCH_NUM=1
echo "$ITEMS" | jq -c ".[] | {id, content, metadata}" | while read -r item; do
  ITEM_ID=$(echo "$item" | jq -r '.id')
  CONTENT=$(echo "$item" | jq -r '.content')
  METADATA=$(echo "$item" | jq '.metadata // {}')

  echo -e "\nProcessing item: $ITEM_ID"

  # Generate embedding
  EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"models/gemini-embedding-001\",
      \"content\": {
        \"parts\": [{
          \"text\": \"$CONTENT\"
        }]
      },
      \"outputDimensionality\": 768
    }" | jq -c '.embedding.values')

  # Prepare payload
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  PAYLOAD=$(echo "$METADATA" | jq --arg content "$CONTENT" --arg ts "$TIMESTAMP" '. + {
    content: $content,
    timestamp: $ts
  }')

  # Upsert point
  curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
    -H "api-key: ${QDRANT_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"points\": [{
        \"id\": \"$ITEM_ID\",
        \"vector\": $EMBEDDING,
        \"payload\": $PAYLOAD
      }]
    }" | jq -r '.status'

  echo "Item $ITEM_ID: OK"
done

echo -e "\n==========================================="
echo "Batch upsert complete!"
