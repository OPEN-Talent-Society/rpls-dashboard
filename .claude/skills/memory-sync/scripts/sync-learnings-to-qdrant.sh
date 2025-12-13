#!/bin/bash
# Sync Learnings from Supabase to Qdrant learnings collection

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source /Users/adamkovacs/Documents/codebuild/.env 2>/dev/null || true

SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY}"
# IMPORTANT: Always use "learnings" collection - don't rely on env var
QDRANT_COLLECTION="learnings"
GEMINI_KEY="${GEMINI_API_KEY}"

echo "🔄 Starting Learnings → Qdrant sync..."
echo "📦 Collection: ${QDRANT_COLLECTION}"

# Fetch learnings
echo "📥 Fetching learnings from Supabase..."
LEARNINGS=$(curl -s -X GET \
  "${SUPABASE_URL}/rest/v1/learnings?select=*" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}")

COUNT=$(echo "$LEARNINGS" | jq 'length')
echo "✅ Found $COUNT learnings"

# Track counters (use process substitution to avoid subshell)
SYNCED=0
SKIPPED=0

while read -r learning; do
  ID=$(echo "$learning" | jq -r '.id')
  CONTENT=$(echo "$learning" | jq -r '.content // .text // .description // ""')
  TITLE=$(echo "$learning" | jq -r '.title // .name // "Learning"')
  
  if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
    ((SKIPPED++))
    continue
  fi
  
  echo "🔄 Processing: $TITLE"
  
  # Generate embedding
  ESCAPED=$(echo "$CONTENT" | jq -Rs .)
  EMBEDDING=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/gemini-embedding-001\", \"content\": {\"parts\": [{\"text\": $ESCAPED}]}, \"outputDimensionality\": 768}" | jq -c '.embedding.values')
  
  if [ -z "$EMBEDDING" ] || [ "$EMBEDDING" = "null" ]; then
    echo "  ⚠️ Failed to generate embedding"
    continue
  fi
  
  # Create point ID from UUID
  POINT_ID=$(echo -n "$ID" | md5 | cut -c1-8)
  POINT_ID_NUM=$(printf "%lu" "0x$POINT_ID")
  
  # Upsert to Qdrant
  PAYLOAD=$(jq -n \
    --argjson id "$POINT_ID_NUM" \
    --argjson vector "$EMBEDDING" \
    --arg learning_id "$ID" \
    --arg title "$TITLE" \
    --arg content "$CONTENT" \
    --arg type "learning" \
    --arg source "supabase" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          learning_id: $learning_id,
          title: $title,
          content: $content,
          type: $type,
          source: $source,
          indexed_at: (now | todate)
        }
      }]
    }')
  
  RESULT=$(curl -s -X PUT \
    "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points?wait=true" \
    -H "api-key: ${QDRANT_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")
  
  if echo "$RESULT" | jq -e '.status == "ok"' > /dev/null 2>&1; then
    echo "  ✅ Synced"
    ((SYNCED++))
  else
    echo "  ❌ Failed: $(echo "$RESULT" | jq -r '.status.error // "unknown"')"
  fi

  sleep 0.3
done < <(echo "$LEARNINGS" | jq -c '.[]')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Sync Complete!"
echo "✅ Synced: ${SYNCED}"
echo "⏭️  Skipped (empty): ${SKIPPED}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
