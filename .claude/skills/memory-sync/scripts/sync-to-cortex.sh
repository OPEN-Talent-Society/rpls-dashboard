#!/bin/bash
# Sync learnings and patterns to Cortex (SiYuan) knowledge base
# Usage: sync-to-cortex.sh [--force]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Cortex/SiYuan config
SIYUAN_BASE_URL="${SIYUAN_BASE_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${SIYUAN_API_TOKEN:-0fkvtzw0jrat2oht}"

# Supabase config (source)
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

echo "🔄 Syncing to Cortex (SiYuan)"
echo "   Target: $SIYUAN_BASE_URL"

# Function to create a document in Cortex
create_cortex_doc() {
    local NOTEBOOK="$1"
    local TITLE="$2"
    local CONTENT="$3"
    local TAGS="$4"

    # Create markdown content
    local MD_CONTENT="# $TITLE

$CONTENT

---
*Synced from Supabase: $(date -u +%Y-%m-%dT%H:%M:%SZ)*
*Tags: $TAGS*"

    # Create document via SiYuan API
    curl -s -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"notebook\": \"$NOTEBOOK\",
            \"path\": \"/Synced/$TITLE\",
            \"markdown\": $(echo "$MD_CONTENT" | jq -Rs .)
        }" 2>/dev/null
}

# Get Resources notebook ID (for learnings)
RESOURCES_NOTEBOOK="20231114112235-resources"

# Fetch and sync learnings from Supabase
echo "📚 Syncing learnings to Cortex..."
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=*&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

echo "$LEARNINGS" | jq -c '.[]' | while read -r learning; do
    TOPIC=$(echo "$learning" | jq -r '.topic // empty')
    CONTENT=$(echo "$learning" | jq -r '.content // empty')
    CATEGORY=$(echo "$learning" | jq -r '.category // "general"')
    TAGS=$(echo "$learning" | jq -r '.tags | if . then join(", ") else "synced" end')

    if [ -z "$TOPIC" ]; then continue; fi

    # Create in Cortex
    RESULT=$(create_cortex_doc "$RESOURCES_NOTEBOOK" "Learning: $TOPIC" "$CONTENT" "$TAGS")

    if echo "$RESULT" | grep -q '"code":0'; then
        echo "✅ Synced learning: $TOPIC"
    else
        echo "⚠️  Failed: $TOPIC - $RESULT"
    fi
done

# Sync patterns
echo ""
echo "🎯 Syncing patterns to Cortex..."
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=*&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

echo "$PATTERNS" | jq -c '.[]' | while read -r pattern; do
    NAME=$(echo "$pattern" | jq -r '.name // empty')
    DESC=$(echo "$pattern" | jq -r '.description // empty')
    CATEGORY=$(echo "$pattern" | jq -r '.category // "general"')
    TEMPLATE=$(echo "$pattern" | jq -r '.template | tostring' 2>/dev/null || echo "{}")

    if [ -z "$NAME" ]; then continue; fi

    CONTENT="**Category:** $CATEGORY

**Description:**
$DESC

**Template:**
\`\`\`json
$TEMPLATE
\`\`\`"

    RESULT=$(create_cortex_doc "$RESOURCES_NOTEBOOK" "Pattern: $NAME" "$CONTENT" "$CATEGORY,pattern,synced")

    if echo "$RESULT" | grep -q '"code":0'; then
        echo "✅ Synced pattern: $NAME"
    else
        echo "⚠️  Failed: $NAME"
    fi
done

echo ""
echo "✅ Cortex sync complete"
