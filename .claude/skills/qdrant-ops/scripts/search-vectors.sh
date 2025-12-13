#!/bin/bash
# Semantic search with automatic embedding generation

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

QUERY="${1:-}"
COLLECTION="${2:-agent_memory}"
LIMIT="${3:-10}"

if [ -z "$QUERY" ]; then
  echo "Usage: $0 <query> [collection] [limit]"
  echo "Example: $0 'How to batch update NocoDB records' agent_memory 5"
  exit 1
fi

echo "Searching Qdrant for: $QUERY"
echo "Collection: $COLLECTION"
echo "==========================================="

# Generate embedding using Gemini
echo -e "\n1. Generating embedding..."
EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"models/gemini-embedding-001\",
    \"content\": {
      \"parts\": [{
        \"text\": \"$QUERY\"
      }]
    },
    \"outputDimensionality\": 768
  }" | jq -c '.embedding.values')

if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
  echo "Error: Failed to generate embedding"
  exit 1
fi

echo "Embedding generated ($(echo $EMBEDDING | jq 'length') dimensions)"

# Search Qdrant
echo -e "\n2. Searching collection..."
RESULTS=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/search" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"vector\": $EMBEDDING,
    \"limit\": $LIMIT,
    \"with_payload\": true,
    \"with_vector\": false,
    \"score_threshold\": 0.6
  }")

echo -e "\n3. Results:"
echo "$RESULTS" | jq -r '.result[] |
  "Score: \(.score | tonumber * 100 | round / 100)\n" +
  "Content: \(.payload.content // .payload.problem // .payload.description // "N/A")\n" +
  "---"'

echo -e "\nSearch complete!"
