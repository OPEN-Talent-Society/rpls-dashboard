#!/bin/bash
# Store content with automatic embedding generation

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

CONTENT="${1:-}"
COLLECTION="${2:-agent_memory}"
METADATA="${3:-{}}"

if [ -z "$CONTENT" ]; then
  echo "Usage: $0 <content> [collection] [metadata_json]"
  echo "Example: $0 'Learned NocoDB batch limit is 10 records' learnings '{\"category\":\"learning\"}'"
  exit 1
fi

echo "Storing content to Qdrant"
echo "Collection: $COLLECTION"
echo "==========================================="

# Generate unique UUID
POINT_ID="$(uuidgen | tr '[:upper:]' '[:lower:]')"

# Generate embedding
echo -e "\n1. Generating embedding..."
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

if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
  echo "Error: Failed to generate embedding"
  exit 1
fi

echo "Embedding generated ($(echo $EMBEDDING | jq 'length') dimensions)"

# Prepare payload
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
# Parse metadata or use empty object
if [ "$METADATA" = "{}" ]; then
  PAYLOAD=$(jq -n --arg content "$CONTENT" --arg ts "$TIMESTAMP" '{
    content: $content,
    timestamp: $ts
  }')
else
  PAYLOAD=$(echo "$METADATA" | jq --arg content "$CONTENT" --arg ts "$TIMESTAMP" '. + {
    content: $content,
    timestamp: $ts
  }')
fi

# Store in Qdrant
echo -e "\n2. Storing point..."
RESPONSE=$(curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"points\": [{
      \"id\": \"$POINT_ID\",
      \"vector\": $EMBEDDING,
      \"payload\": $PAYLOAD
    }]
  }")

echo "$RESPONSE" | jq '.'

if echo "$RESPONSE" | jq -e '.status == "ok"' > /dev/null; then
  echo -e "\nSuccess! Point ID: $POINT_ID"
else
  echo -e "\nError storing point"
  exit 1
fi
