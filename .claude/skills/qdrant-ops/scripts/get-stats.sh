#!/bin/bash
# Get comprehensive Qdrant statistics

set -euo pipefail

source /Users/adamkovacs/Documents/codebuild/.env
QDRANT_URL="https://qdrant.harbor.fyi"

echo "Qdrant Database Statistics"
echo "==========================="

echo -e "\nAll Collections:"
curl -s "${QDRANT_URL}/collections" \
  -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.collections[] |
  "\(.name): \(.points_count) points"'

echo -e "\nDetailed Stats per Collection:"
for collection in agent_memory learnings patterns embeddings; do
  echo -e "\n--- $collection ---"
  curl -s "${QDRANT_URL}/collections/${collection}" \
    -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq '.result | {
      points: .points_count,
      segments: .segments_count,
      vectors: .vectors_count,
      indexed: .indexed_vectors_count,
      status: .status
    }' || echo "Collection not found"
done

echo -e "\n==========================="
echo "Stats complete!"
