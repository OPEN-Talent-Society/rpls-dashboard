#!/bin/bash
# Check Qdrant collection status and configuration

set -euo pipefail

# Load environment variables
source /Users/adamkovacs/Documents/codebuild/.env

# Use HTTPS URL (second QDRANT_URL in .env overrides first)
QDRANT_URL="https://qdrant.harbor.fyi"

COLLECTION="${1:-agent_memory}"

echo "Checking Qdrant collection: $COLLECTION"
echo "==========================================="

# Check health first
echo -e "\n1. Health Check:"
curl -s "${QDRANT_URL}/healthz"

# Get collection info
echo -e "\n2. Collection Info:"
curl -s "${QDRANT_URL}/collections/${COLLECTION}" \
  -H "api-key: ${QDRANT_API_KEY}" | jq '.result | {
    status: .status,
    points_count: .points_count,
    segments_count: .segments_count,
    vector_size: .config.params.vectors.size,
    distance: .config.params.vectors.distance,
    indexed_vectors: .indexed_vectors_count
  }'

# Get collection stats
echo -e "\n3. Collection Statistics:"
curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/count" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.result'

echo -e "\nCollection check complete!"
