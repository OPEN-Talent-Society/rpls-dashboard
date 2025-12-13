#!/bin/bash
# ====================================================
# Sync Patterns from Supabase to Qdrant
# Fetches all patterns, generates embeddings, uploads to Qdrant
# ====================================================

set -e  # Exit on error

# Load environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/Users/adamkovacs/Documents/codebuild/.env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "❌ Environment file not found: $ENV_FILE"
  exit 1
fi

# Configuration
SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [ -z "$QDRANT_API_KEY" ]; then
    echo "Warning: QDRANT_API_KEY not set, requests may fail"
fi
# IMPORTANT: Always use "patterns" collection - don't rely on env var
QDRANT_COLLECTION="patterns"
GEMINI_KEY="${GEMINI_API_KEY}"
GEMINI_MODEL="${QDRANT_EMBEDDING_MODEL:-gemini-embedding-001}"

echo "🔄 Starting Patterns → Qdrant sync..."
echo "📊 Supabase: ${SUPABASE_URL}"
echo "🗄️  Qdrant: ${QDRANT_URL}"
echo "📦 Collection: ${QDRANT_COLLECTION}"
echo ""

# Get total count of patterns first (Supabase has 1000 row default limit)
echo "📥 Checking total patterns in Supabase..."
TOTAL_COUNT=$(curl -s -I "${SUPABASE_URL}/rest/v1/patterns?select=id" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Prefer: count=exact" | grep -i content-range | sed 's/.*\///' | tr -d '\r\n')

if [ -z "$TOTAL_COUNT" ] || [ "$TOTAL_COUNT" = "0" ]; then
  TOTAL_COUNT=1000  # Fallback
fi

echo "📊 Total patterns in Supabase: ${TOTAL_COUNT}"

# Process each pattern
SUCCESSFUL=0
FAILED=0
PAGE_SIZE=1000
OFFSET=0

# Paginate through all patterns
while [ "$OFFSET" -lt "$TOTAL_COUNT" ]; do
  END=$((OFFSET + PAGE_SIZE - 1))
  echo ""
  echo "📥 Fetching patterns ${OFFSET}-${END}..."

  PATTERNS=$(curl -s -X GET \
    "${SUPABASE_URL}/rest/v1/patterns?select=*&order=id" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Range: ${OFFSET}-${END}")

  PAGE_COUNT=$(echo "$PATTERNS" | jq '. | length')
  echo "  📦 Got ${PAGE_COUNT} patterns in this page"

  if [ "$PAGE_COUNT" = "0" ]; then
    break
  fi

  # Process patterns in this page
  while read -r pattern; do
  PATTERN_ID=$(echo "$pattern" | jq -r '.id')
  PATTERN_NAME=$(echo "$pattern" | jq -r '.name')
  PATTERN_CATEGORY=$(echo "$pattern" | jq -r '.category // "uncategorized"')
  PATTERN_DESC=$(echo "$pattern" | jq -r '.description // ""')
  PATTERN_TEMPLATE=$(echo "$pattern" | jq -r '.template // ""')
  PATTERN_USE_CASES=$(echo "$pattern" | jq -r '.use_cases // ""')
  PATTERN_CREATED=$(echo "$pattern" | jq -r '.created_at // ""')

  echo "🔄 Processing: ${PATTERN_NAME} (ID: ${PATTERN_ID})"

  # Create text for embedding: combine name, description, and use cases
  EMBEDDING_TEXT="${PATTERN_NAME}. ${PATTERN_DESC} ${PATTERN_USE_CASES}"

  # Generate embedding using Gemini
  echo "  🧠 Generating embedding..."
  EMBEDDING_RESPONSE=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:embedContent?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/${GEMINI_MODEL}\", \"content\": {\"parts\":[{\"text\": $(echo "$EMBEDDING_TEXT" | jq -Rs .)}]}, \"outputDimensionality\": 768}")

  # Extract embedding vector
  EMBEDDING=$(echo "$EMBEDDING_RESPONSE" | jq -c '.embedding.values')

  if [ "$EMBEDDING" == "null" ] || [ -z "$EMBEDDING" ]; then
    echo "  ❌ Failed to generate embedding"
    ((FAILED++))
    continue
  fi

  # Create Qdrant point using UUID as string ID
  QDRANT_POINT=$(jq -n \
    --arg id "$PATTERN_ID" \
    --argjson vector "$EMBEDDING" \
    --arg type "pattern" \
    --arg source "supabase" \
    --arg name "$PATTERN_NAME" \
    --arg category "$PATTERN_CATEGORY" \
    --arg description "$PATTERN_DESC" \
    --arg template "$PATTERN_TEMPLATE" \
    --arg use_cases "$PATTERN_USE_CASES" \
    --arg created_at "$PATTERN_CREATED" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          type: $type,
          source: $source,
          name: $name,
          category: $category,
          description: $description,
          template: $template,
          use_cases: $use_cases,
          created_at: $created_at,
          supabase_id: $id
        }
      }]
    }')

  # Upload to Qdrant
  echo "  📤 Uploading to Qdrant..."
  UPLOAD_RESPONSE=$(curl -s -X PUT \
    "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points?wait=true" \
    -H "api-key: ${QDRANT_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "$QDRANT_POINT")

  UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | jq -r '.status // "error"')

  if [ "$UPLOAD_STATUS" == "ok" ]; then
    echo "  ✅ Successfully synced: ${PATTERN_NAME}"
    ((SUCCESSFUL++))
  else
    echo "  ❌ Failed to upload: ${PATTERN_NAME}"
    echo "  Response: $UPLOAD_RESPONSE"
    ((FAILED++))
  fi

  echo ""
  done < <(echo "$PATTERNS" | jq -c '.[]')

  # Move to next page
  OFFSET=$((OFFSET + PAGE_SIZE))
  echo "  📊 Progress: ${OFFSET}/${TOTAL_COUNT} patterns processed"
done

# Final report
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Sync Complete!"
echo "✅ Successful: ${SUCCESSFUL}"
echo "❌ Failed: ${FAILED}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Query final count from Qdrant
echo ""
echo "🔍 Querying Qdrant for pattern count..."
QDRANT_INFO=$(curl -s -H "api-key: ${QDRANT_API_KEY}" "${QDRANT_URL}/collections/${QDRANT_COLLECTION}")
TOTAL_POINTS=$(echo "$QDRANT_INFO" | jq -r '.result.points_count // 0')
echo "📦 Total points in Qdrant: ${TOTAL_POINTS}"
