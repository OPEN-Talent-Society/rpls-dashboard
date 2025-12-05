#!/bin/bash
# Store a new learning across all memory backends
# Usage: store-learning.sh "topic" "content" [category] [tags]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

TOPIC="${1:-}"
CONTENT="${2:-}"
CATEGORY="${3:-general}"
TAGS="${4:-learning,automated}"

if [ -z "$TOPIC" ] || [ -z "$CONTENT" ]; then
    echo "Usage: store-learning.sh \"topic\" \"content\" [category] [tags]"
    exit 1
fi

# Generate learning ID
LEARNING_ID="learning-$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')-$(date +%Y-%m-%d)"

# Store in Supabase
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY}"

echo "📝 Storing learning: $TOPIC"

# Create learning in Supabase
RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "{
    \"learning_id\": \"$LEARNING_ID\",
    \"topic\": \"$TOPIC\",
    \"content\": \"$CONTENT\",
    \"category\": \"$CATEGORY\",
    \"agent_id\": \"claude-code\",
    \"agent_email\": \"claude-code@aienablement.academy\",
    \"tags\": [\"$TAGS\"],
    \"related_docs\": [],
    \"metadata\": {}
  }" 2>&1)

if echo "$RESPONSE" | grep -q "error"; then
    echo "❌ Failed to store in Supabase: $RESPONSE"
    exit 1
else
    echo "✅ Stored in Supabase"
fi

# Sync to other backends
echo "🔄 Syncing to other backends..."
bash "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-supabase-to-qdrant.sh" > /dev/null 2>&1 &

echo "✅ Learning stored successfully"
echo "   ID: $LEARNING_ID"
echo "   Backends: Supabase ✅, Qdrant (indexing in background)"
