#!/bin/bash
# Sync knowledge from Cortex (SiYuan) to Supabase
# Usage: sync-from-cortex.sh [--force]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Cortex/SiYuan config - uses Global API Key auth
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_API_TOKEN="${CORTEX_TOKEN}"
CF_AUTH_EMAIL="${CF_AUTH_EMAIL:-adam@aienablement.academy}"
CF_GLOBAL_KEY="${CF_GLOBAL_API_KEY}"

# Supabase config (target) - use anon key, falls back to service role
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY:-${SUPABASE_SERVICE_ROLE_KEY}}"

echo "🔄 Syncing from Cortex (SiYuan) → Supabase"
echo "   Source: $CORTEX_URL"

# Search for documents with specific tags (with Cloudflare headers)
search_cortex() {
    local QUERY="$1"
    curl -s -X POST "${CORTEX_URL}/api/search/fullTextSearchBlock" \
        -H "Authorization: Token ${CORTEX_API_TOKEN}" \
        -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$QUERY\"}" 2>/dev/null
}

# Get document content (with Cloudflare headers)
get_doc_content() {
    local DOC_ID="$1"
    curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
        -H "Authorization: Token ${CORTEX_API_TOKEN}" \
        -H "X-Auth-Email: ${CF_AUTH_EMAIL}" \
        -H "X-Auth-Key: ${CF_GLOBAL_KEY}" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"$DOC_ID\"}" 2>/dev/null
}

echo "📚 Searching Cortex for learnings..."

# Search for learning-tagged content
RESULTS=$(search_cortex "learning")

if [ -z "$RESULTS" ] || [ "$RESULTS" = "{}" ]; then
    echo "ℹ️  No learnings found in Cortex"
else
    echo "$RESULTS" | jq -c '.data.blocks[]?' 2>/dev/null | head -20 | while read -r block; do
        BLOCK_ID=$(echo "$block" | jq -r '.id // empty')
        CONTENT=$(echo "$block" | jq -r '.content // empty')

        if [ -z "$BLOCK_ID" ] || [ -z "$CONTENT" ]; then continue; fi

        # Extract title (first line or heading)
        TITLE=$(echo "$CONTENT" | head -1 | sed 's/^#* *//')

        # Create learning in Supabase
        LEARNING=$(jq -n \
            --arg topic "$TITLE" \
            --arg content "$CONTENT" \
            --arg category "cortex_import" \
            '{
                learning_id: ("cortex-" + ($topic | gsub(" "; "-") | ascii_downcase)),
                topic: $topic,
                content: $content,
                category: $category,
                context: "Imported from Cortex knowledge base",
                agent_id: "cortex-sync",
                tags: ["cortex", "imported", "knowledge"]
            }')

        RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" \
            -H "Content-Type: application/json" \
            -H "Prefer: resolution=merge-duplicates" \
            -d "$LEARNING" 2>&1)

        if echo "$RESPONSE" | grep -q "error"; then
            echo "⚠️  Failed: $TITLE"
        else
            echo "✅ Imported: $TITLE"
        fi
    done
fi

echo ""
echo "✅ Cortex → Supabase sync complete"
