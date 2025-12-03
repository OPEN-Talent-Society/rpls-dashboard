#!/bin/bash
# Index all memory sources to Qdrant for semantic search
# Uses persistent Qdrant instance at qdrant.harbor.fyi
# Usage: index-to-qdrant.sh [--collection name]
#
# EMBEDDING MODEL STANDARD:
# -------------------------
# PRIMARY: Gemini text-embedding-004 (768 dimensions)
# REASON: Higher quality semantic understanding for production use
# FREE TIER: 1500 requests/minute (sufficient for our needs)
#
# STANDARD CONFIGURATION:
# - All Qdrant collections MUST use 768 dimensions
# - Gemini embeddings are the chosen approach (NOT migrating to FastEmbed)
# - Direct API calls are preferred over MCP server
#
# MCP SERVER (OPTIONAL):
# The Qdrant MCP server with FastEmbed (384 dims) is available as a fallback
# option only. It is NOT our primary approach. Use Gemini 768-dim for all
# production indexing and search operations.
#
# WHY GEMINI OVER FASTEMBED:
# 1. Better quality: Superior semantic understanding
# 2. Free tier: 1500 req/min is sufficient for our workload
# 3. Already configured: Working and tested in production
# 4. Direct control: API calls give us more flexibility than MCP

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

COLLECTION="${1:-agent_memory}"
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
QDRANT_URL="${QDRANT_URL:-http://qdrant.harbor.fyi}"
GEMINI_KEY="${GEMINI_API_KEY}"

echo "🔍 Indexing to Qdrant collection: $COLLECTION"
echo "   Endpoint: $QDRANT_URL"
echo "   Embedding: Gemini text-embedding-004 (768 dims)"
echo "   ✅ Standard: All collections use 768-dim Gemini embeddings"

# Function to get embedding from Gemini (768 dimensions)
#
# STANDARD APPROACH (DO NOT CHANGE):
# Uses Gemini text-embedding-004 API for high-quality 768-dim embeddings.
# This is our PRIMARY embedding provider. FastEmbed is a fallback option only.
#
# CONFIGURATION:
# - Model: text-embedding-004
# - Dimensions: 768
# - Free tier: 1500 requests/minute
# - Max input: 5000 characters (truncated below)
#
# NOTE: All Qdrant collections MUST be created with 768 dimensions to match.
get_embedding() {
    local text="$1"
    # Escape text for JSON (handle newlines and special chars)
    local escaped_text=$(echo "$text" | head -c 5000 | jq -Rs '.')

    local response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/text-embedding-004\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]}
        }")

    echo "$response" | jq -c '.embedding.values // empty'
}

# Function to upsert point to Qdrant
upsert_to_qdrant() {
    local id="$1"
    local vector="$2"
    local payload="$3"

    # Convert string ID to numeric hash (Qdrant requires numeric IDs or UUIDs)
    local numeric_id=$(echo -n "$id" | md5sum | cut -c1-16)
    numeric_id=$((16#$numeric_id % 2147483647))

    curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $numeric_id,
                \"vector\": $vector,
                \"payload\": $payload
            }]
        }" > /dev/null
}

# Ensure collection exists with 768 dimensions to match Gemini embeddings
# STANDARD: All Qdrant collections use 768 dimensions for Gemini compatibility.
# This is our primary approach - NOT migrating to FastEmbed (384 dims).
# MCP server with FastEmbed is available as a fallback option only.
echo "📦 Ensuring collection exists..."
echo "   Creating/verifying 768-dim collection for Gemini embeddings..."
curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}" \
    -H "Content-Type: application/json" \
    -d '{"vectors": {"size": 768, "distance": "Cosine"}}' 2>/dev/null || true

INDEXED=0

# Index from Supabase learnings
echo "📚 Indexing learnings..."
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=id,topic,content,category&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

echo "$LEARNINGS" | jq -c '.[]' 2>/dev/null | while read -r learning; do
    ID=$(echo "$learning" | jq -r '.id')
    TOPIC=$(echo "$learning" | jq -r '.topic // empty')
    CONTENT=$(echo "$learning" | jq -r '.content // empty')
    CATEGORY=$(echo "$learning" | jq -r '.category // "general"')

    if [ -z "$CONTENT" ]; then continue; fi

    TEXT="$TOPIC: $CONTENT"
    EMBEDDING=$(get_embedding "$TEXT")

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
        PAYLOAD="{\"type\":\"learning\",\"category\":\"$CATEGORY\",\"source\":\"supabase\",\"original_id\":\"$ID\",\"topic\":\"$TOPIC\"}"
        upsert_to_qdrant "learning-$ID" "$EMBEDDING" "$PAYLOAD"
        INDEXED=$((INDEXED + 1))
        echo -n "."
    fi
done
echo ""

# Index from Supabase patterns
echo "🎯 Indexing patterns..."
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=id,name,description,category&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

echo "$PATTERNS" | jq -c '.[]' 2>/dev/null | while read -r pattern; do
    ID=$(echo "$pattern" | jq -r '.id')
    NAME=$(echo "$pattern" | jq -r '.name // empty')
    DESC=$(echo "$pattern" | jq -r '.description // empty')
    CATEGORY=$(echo "$pattern" | jq -r '.category // "general"')

    if [ -z "$NAME" ]; then continue; fi

    TEXT="$NAME: $DESC"
    EMBEDDING=$(get_embedding "$TEXT")

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
        PAYLOAD="{\"type\":\"pattern\",\"category\":\"$CATEGORY\",\"source\":\"supabase\",\"original_id\":\"$ID\",\"name\":\"$NAME\"}"
        upsert_to_qdrant "pattern-$ID" "$EMBEDDING" "$PAYLOAD"
        echo -n "."
    fi
done
echo ""

# Index from agent_memory
echo "🧠 Indexing agent memory..."
MEMORIES=$(curl -s "${SUPABASE_URL}/rest/v1/agent_memory?select=id,key,value,namespace&limit=100" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

echo "$MEMORIES" | jq -c '.[]' 2>/dev/null | while read -r memory; do
    ID=$(echo "$memory" | jq -r '.id')
    KEY=$(echo "$memory" | jq -r '.key // empty')
    VALUE=$(echo "$memory" | jq -r '.value | tostring' 2>/dev/null || echo "")
    NS=$(echo "$memory" | jq -r '.namespace // "default"')

    if [ -z "$KEY" ]; then continue; fi

    TEXT="$KEY: $VALUE"
    EMBEDDING=$(get_embedding "$TEXT")

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
        PAYLOAD="{\"type\":\"memory\",\"namespace\":\"$NS\",\"source\":\"supabase\",\"original_id\":\"$ID\",\"key\":\"$KEY\"}"
        upsert_to_qdrant "memory-$ID" "$EMBEDDING" "$PAYLOAD"
        echo -n "."
    fi
done
echo ""

# Show stats
echo ""
echo "📊 Qdrant Collection Stats:"
curl -s "${QDRANT_URL}/collections/${COLLECTION}" | jq '{
    points_count: .result.points_count,
    vectors_count: .result.vectors_count,
    indexed_vectors_count: .result.indexed_vectors_count,
    status: .result.status
}'

echo ""
echo "✅ Indexing complete"
