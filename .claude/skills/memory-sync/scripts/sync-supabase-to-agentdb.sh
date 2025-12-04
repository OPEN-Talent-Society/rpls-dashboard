#!/bin/bash
# Sync Supabase patterns/learnings to AgentDB
# Usage: sync-supabase-to-agentdb.sh [--force]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load env with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Validate required vars - NO HARDCODED KEYS
[ -z "$PUBLIC_SUPABASE_URL" ] && { echo "❌ PUBLIC_SUPABASE_URL not set"; exit 1; }
[ -z "$SUPABASE_SERVICE_ROLE_KEY" ] && { echo "❌ SUPABASE_SERVICE_ROLE_KEY not set"; exit 1; }

SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

echo "🔄 Syncing Supabase → AgentDB"

# Fetch patterns from Supabase
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=*&limit=100" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

# Fetch learnings from Supabase
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=*&limit=100" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

PATTERN_COUNT=$(echo "$PATTERNS" | jq 'length' 2>/dev/null || echo "0")
LEARNING_COUNT=$(echo "$LEARNINGS" | jq 'length' 2>/dev/null || echo "0")

echo "📊 Found $PATTERN_COUNT patterns, $LEARNING_COUNT learnings"

# Store patterns to AgentDB via sqlite directly (faster, no CLI issues)
AGENTDB="$PROJECT_DIR/agentdb.db"

if [ -f "$AGENTDB" ]; then
    echo "$PATTERNS" | jq -c '.[]' 2>/dev/null | while read -r pattern; do
        NAME=$(echo "$pattern" | jq -r '.name // empty')
        DESC=$(echo "$pattern" | jq -r '.description // empty' | head -c 1000)
        CATEGORY=$(echo "$pattern" | jq -r '.category // "imported"')

        [ -z "$NAME" ] && continue

        # Escape for SQLite
        NAME_ESC=$(echo "$NAME" | sed "s/'/''/g")
        DESC_ESC=$(echo "$DESC" | sed "s/'/''/g")

        # Insert or replace in AgentDB episodes table
        sqlite3 "$AGENTDB" "INSERT OR REPLACE INTO episodes (task, reward, success, critique, session_id)
            VALUES ('Pattern: $NAME_ESC', 0.8, 1, '$DESC_ESC', 'supabase-import');" 2>/dev/null || true

        echo "✅ Imported pattern: $NAME"
    done

    echo "$LEARNINGS" | jq -c '.[]' 2>/dev/null | while read -r learning; do
        TOPIC=$(echo "$learning" | jq -r '.topic // empty')
        CONTENT=$(echo "$learning" | jq -r '.content // empty' | head -c 1000)

        [ -z "$TOPIC" ] && continue

        # Escape for SQLite
        TOPIC_ESC=$(echo "$TOPIC" | sed "s/'/''/g")
        CONTENT_ESC=$(echo "$CONTENT" | sed "s/'/''/g")

        # Insert or replace in AgentDB episodes table
        sqlite3 "$AGENTDB" "INSERT OR REPLACE INTO episodes (task, reward, success, critique, session_id)
            VALUES ('Learning: $TOPIC_ESC', 0.9, 1, '$CONTENT_ESC', 'supabase-import');" 2>/dev/null || true

        echo "✅ Imported learning: $TOPIC"
    done
else
    echo "⚠️  AgentDB not found at $AGENTDB, skipping import"
fi

echo ""
echo "✅ Sync complete: Supabase → AgentDB"
