#!/bin/bash
# Sync Supabase patterns/learnings to AgentDB
# Usage: sync-supabase-to-agentdb.sh [--force]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY:-sb_secret_g87UniWlZT7GYIQsrWEYYw_VJs7i0Ei}"

echo "🔄 Syncing Supabase → AgentDB"

# Fetch patterns from Supabase
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=*&limit=100" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

# Fetch learnings from Supabase
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=*&limit=100" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

PATTERN_COUNT=$(echo "$PATTERNS" | jq 'length')
LEARNING_COUNT=$(echo "$LEARNINGS" | jq 'length')

echo "📊 Found $PATTERN_COUNT patterns, $LEARNING_COUNT learnings"

# Store to AgentDB via MCP (uses the running claude-flow MCP server)
echo "$PATTERNS" | jq -c '.[]' | while read -r pattern; do
    NAME=$(echo "$pattern" | jq -r '.name // empty')
    DESC=$(echo "$pattern" | jq -r '.description // empty')
    CATEGORY=$(echo "$pattern" | jq -r '.category // "imported"')

    if [ -z "$NAME" ]; then continue; fi

    # Store as episode via CLI
    /opt/homebrew/bin/claude-flow memory store \
        --key "supabase/patterns/$CATEGORY" \
        --value "$pattern" \
        --namespace "imported" 2>/dev/null || true

    echo "✅ Imported pattern: $NAME"
done

echo "$LEARNINGS" | jq -c '.[]' | while read -r learning; do
    TOPIC=$(echo "$learning" | jq -r '.topic // empty')
    CONTENT=$(echo "$learning" | jq -r '.content // empty')

    if [ -z "$TOPIC" ]; then continue; fi

    /opt/homebrew/bin/claude-flow memory store \
        --key "supabase/learnings/$TOPIC" \
        --value "$learning" \
        --namespace "imported" 2>/dev/null || true

    echo "✅ Imported learning: $TOPIC"
done

echo ""
echo "✅ Sync complete: Supabase → AgentDB"
