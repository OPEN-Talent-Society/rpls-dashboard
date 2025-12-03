#!/bin/bash
# Sync all Supabase learnings to Qdrant semantic layer
# Uses Gemini embeddings (768 dims)

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
QDRANT_URL="${QDRANT_URL:-http://qdrant.harbor.fyi}"
GEMINI_KEY="${GEMINI_API_KEY}"

echo "🔄 Syncing Supabase → Qdrant"
echo "   Source: $SUPABASE_URL"
echo "   Target: $QDRANT_URL"
echo ""

# Fetch all learnings from Supabase
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=id,topic,content,category&limit=500" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

COUNT=$(echo "$LEARNINGS" | jq 'length')
echo "📊 Found $COUNT learnings to index"
echo ""

SUCCESS=0
FAILED=0

echo "$LEARNINGS" | jq -c '.[]' | while read -r learning; do
    TOPIC=$(echo "$learning" | jq -r '.topic // empty')
    CONTENT=$(echo "$learning" | jq -r '.content // empty' | head -c 2000)
    CATEGORY=$(echo "$learning" | jq -r '.category // "general"')
    ID=$(echo "$learning" | jq -r '.id // empty')
    
    [ -z "$TOPIC" ] && continue
    [ ${#CONTENT} -lt 20 ] && continue
    
    printf "📄 %-50s " "${TOPIC:0:50}"
    
    # Get Gemini embedding
    EMBED_TEXT=$(printf '%s: %s' "$TOPIC" "${CONTENT:0:1500}" | jq -Rs '.')
    
    EMBED_RESULT=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"models/text-embedding-004\", \"content\": {\"parts\": [{\"text\": $EMBED_TEXT}]}}" 2>/dev/null)
    
    EMBEDDING=$(echo "$EMBED_RESULT" | jq -c '.embedding.values // empty' 2>/dev/null)
    
    if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
        echo "❌ EMB"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Generate numeric ID from UUID
    HASH=$(echo -n "$ID" | md5)
    POINT_ID=$((16#${HASH:0:7}))
    
    # Escape for JSON
    CONTENT_ESC=$(echo "${CONTENT:0:800}" | jq -Rs '.')
    TOPIC_ESC=$(echo "$TOPIC" | jq -Rs '.')
    
    # Upload to Qdrant
    QDRANT_RESULT=$(curl -s --max-time 10 -X PUT "${QDRANT_URL}/collections/agent_memory/points" \
        -H "Content-Type: application/json" \
        -d "{\"points\": [{\"id\": $POINT_ID, \"vector\": $EMBEDDING, \"payload\": {\"type\": \"learning\", \"topic\": $TOPIC_ESC, \"content\": $CONTENT_ESC, \"category\": \"$CATEGORY\", \"source\": \"supabase-sync\"}}]}" 2>/dev/null)
    
    if echo "$QDRANT_RESULT" | grep -q '"status":"ok"'; then
        echo "✅"
        SUCCESS=$((SUCCESS + 1))
    else
        echo "❌ QD"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "📊 Sync Complete"
echo "   ✅ Success: $SUCCESS"
echo "   ❌ Failed: $FAILED"
