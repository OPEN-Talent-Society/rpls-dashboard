#!/bin/bash
# ====================================================
# Sync Episodes from AgentDB to Qdrant
# Reads episodes from SQLite, generates embeddings, uploads to Qdrant
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
AGENTDB_PATH="/Users/adamkovacs/Documents/codebuild/agentdb.db"
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [ -z "$QDRANT_API_KEY" ]; then
    echo "Warning: QDRANT_API_KEY not set, requests may fail"
fi
QDRANT_COLLECTION="${QDRANT_COLLECTION:-agent_memory}"
GEMINI_KEY="${GEMINI_API_KEY}"
GEMINI_MODEL="${QDRANT_EMBEDDING_MODEL:-text-embedding-004}"

echo "🔄 Starting Episodes (AgentDB) → Qdrant sync..."
echo "🗄️  AgentDB: ${AGENTDB_PATH}"
echo "🗄️  Qdrant: ${QDRANT_URL}"
echo "📦 Collection: ${QDRANT_COLLECTION}"
echo ""

# Check if AgentDB exists
if [ ! -f "$AGENTDB_PATH" ]; then
  echo "❌ AgentDB not found: $AGENTDB_PATH"
  exit 1
fi

# Fetch all episodes from AgentDB
echo "📥 Fetching episodes from AgentDB..."
EPISODES=$(sqlite3 "$AGENTDB_PATH" -json "SELECT * FROM episodes")

# Count episodes
EPISODE_COUNT=$(echo "$EPISODES" | jq '. | length')
echo "✅ Found ${EPISODE_COUNT} episodes"
echo ""

# Process each episode
SUCCESSFUL=0
FAILED=0

echo "$EPISODES" | jq -c '.[]' | while read -r episode; do
  EPISODE_ID=$(echo "$episode" | jq -r '.id')
  SESSION_ID=$(echo "$episode" | jq -r '.session_id // ""')
  TASK=$(echo "$episode" | jq -r '.task // ""')
  INPUT=$(echo "$episode" | jq -r '.input // ""')
  OUTPUT=$(echo "$episode" | jq -r '.output // ""')
  CRITIQUE=$(echo "$episode" | jq -r '.critique // ""')
  REWARD=$(echo "$episode" | jq -r '.reward // 0')
  SUCCESS=$(echo "$episode" | jq -r '.success // 0')
  TOKENS=$(echo "$episode" | jq -r '.tokens_used // 0')
  LATENCY=$(echo "$episode" | jq -r '.latency_ms // 0')
  CREATED=$(echo "$episode" | jq -r '.created_at // ""')

  echo "🔄 Processing Episode #${EPISODE_ID}: ${TASK:0:50}..."

  # Create text for embedding: combine task and critique (most semantic value)
  EMBEDDING_TEXT="${TASK} ${CRITIQUE}"

  # Generate embedding using Gemini
  echo "  🧠 Generating embedding..."
  EMBEDDING_RESPONSE=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:embedContent?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"models/${GEMINI_MODEL}\", \"content\": {\"parts\":[{\"text\": $(echo "$EMBEDDING_TEXT" | jq -Rs .)}]}}")

  # Extract embedding vector
  EMBEDDING=$(echo "$EMBEDDING_RESPONSE" | jq -c '.embedding.values')

  if [ "$EMBEDDING" == "null" ] || [ -z "$EMBEDDING" ]; then
    echo "  ❌ Failed to generate embedding"
    ((FAILED++))
    continue
  fi

  # Create Qdrant point
  POINT_ID=$((2000000 + EPISODE_ID))  # Offset to avoid collision with patterns and learnings

  QDRANT_POINT=$(jq -n \
    --argjson id "$POINT_ID" \
    --argjson vector "$EMBEDDING" \
    --arg type "episode" \
    --arg source "agentdb" \
    --arg session_id "$SESSION_ID" \
    --arg task "$TASK" \
    --arg input "$INPUT" \
    --arg output "$OUTPUT" \
    --arg critique "$CRITIQUE" \
    --argjson reward "$REWARD" \
    --argjson success "$SUCCESS" \
    --argjson tokens "$TOKENS" \
    --argjson latency "$LATENCY" \
    --arg created_at "$CREATED" \
    --arg agentdb_id "$EPISODE_ID" \
    '{
      points: [{
        id: $id,
        vector: $vector,
        payload: {
          type: $type,
          source: $source,
          session_id: $session_id,
          task: $task,
          input: $input,
          output: $output,
          critique: $critique,
          reward: $reward,
          success: ($success == 1),
          tokens_used: $tokens,
          latency_ms: $latency,
          created_at: $created_at,
          agentdb_id: $agentdb_id
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
    echo "  ✅ Successfully synced Episode #${EPISODE_ID}"
    ((SUCCESSFUL++))
  else
    echo "  ❌ Failed to upload Episode #${EPISODE_ID}"
    echo "  Response: $UPLOAD_RESPONSE"
    ((FAILED++))
  fi

  echo ""
done

# Final report
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Sync Complete!"
echo "✅ Successful: ${SUCCESSFUL}"
echo "❌ Failed: ${FAILED}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Query final count from Qdrant
echo ""
echo "🔍 Querying Qdrant for total point count..."
QDRANT_INFO=$(curl -s -H "api-key: ${QDRANT_API_KEY}" "${QDRANT_URL}/collections/${QDRANT_COLLECTION}")
TOTAL_POINTS=$(echo "$QDRANT_INFO" | jq -r '.result.points_count // 0')
echo "📦 Total points in Qdrant: ${TOTAL_POINTS}"
