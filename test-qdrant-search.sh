#!/bin/bash
set -e

# Load environment
source /Users/adamkovacs/Documents/codebuild/.env

echo "=== Step 1: Insert test vector into Qdrant ==="
TEXT="Test memory about Docker container deployment on homelab"
ESCAPED=$(echo "$TEXT" | jq -Rs '.')

# Generate embedding
EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/text-embedding-004\", \"content\": {\"parts\": [{\"text\": $ESCAPED}]}}" | jq -c '.embedding.values')

echo "Generated embedding (first 5 values): $(echo "$EMBEDDING" | jq '.[:5]')"

# Insert into Qdrant
INSERT_RESULT=$(curl -s -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/points" \
    -H "Content-Type: application/json" \
    -d "{\"points\": [{\"id\": 99999, \"vector\": $EMBEDDING, \"payload\": {\"text\": \"$TEXT\", \"type\": \"test\"}}]}")

echo "Insert result: $INSERT_RESULT"

echo ""
echo "=== Step 2: Search for the test vector ==="
QUERY="homelab Docker setup"
QUERY_ESCAPED=$(echo "$QUERY" | jq -Rs '.')

# Generate query embedding
QUERY_EMBED=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/text-embedding-004\", \"content\": {\"parts\": [{\"text\": $QUERY_ESCAPED}]}}" | jq -c '.embedding.values')

echo "Query: $QUERY"

# Search in Qdrant
SEARCH_RESULT=$(curl -s -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/search" \
    -H "Content-Type: application/json" \
    -d "{\"vector\": $QUERY_EMBED, \"limit\": 3, \"with_payload\": true}")

echo "Search results:"
echo "$SEARCH_RESULT" | jq '.'

echo ""
echo "=== Step 3: Clean up test point ==="
DELETE_RESULT=$(curl -s -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/delete" \
    -H "Content-Type: application/json" \
    -d '{"points": [99999]}')

echo "Delete result: $DELETE_RESULT"

echo ""
echo "=== Test Summary ==="
# Check if our test point was found
FOUND=$(echo "$SEARCH_RESULT" | jq '.result[] | select(.id == 99999) | .score')
if [ -n "$FOUND" ]; then
    echo "✅ SUCCESS: Test vector found with score: $FOUND"
    echo "✅ Semantic search is working correctly"
else
    echo "❌ FAILURE: Test vector not found in search results"
fi
