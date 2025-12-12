#!/bin/bash
# Sync learnings and patterns to Cortex (SiYuan) knowledge base
# Usage: sync-to-cortex.sh [--force]
# Updated: 2025-12-11 - Added upsert logic via cortex-helpers.sh to prevent duplicates

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load cortex-helpers.sh for upsert functionality
CORTEX_HELPERS="$PROJECT_DIR/.claude/lib/cortex-helpers.sh"
if [ ! -f "$CORTEX_HELPERS" ]; then
    echo "❌ ERROR: cortex-helpers.sh not found at $CORTEX_HELPERS"
    exit 1
fi
source "$CORTEX_HELPERS"

source "$PROJECT_DIR/.env" 2>/dev/null || true

# Supabase config (source) - use anon key, falls back to service role
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY:-${SUPABASE_SERVICE_ROLE_KEY}}"

echo "🔄 Syncing to Cortex (SiYuan)"
echo "   Target: $SIYUAN_BASE_URL"
echo "   🔄 Using upsert logic - no duplicates will be created"

# Function to upsert a document in Cortex (with Cloudflare headers)
# Uses cortex-helpers.sh upsert_doc function
upsert_cortex_doc() {
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

    # Build metadata
    local METADATA=$(jq -n --arg tags "$TAGS" '{"custom-tags": $tags}')

    # Resolve notebook name to ID
    local NOTEBOOK_ID=$(resolve_notebook_id "$NOTEBOOK")

    # Upsert document (update if exists, create if not)
    upsert_doc "$TITLE" "$MD_CONTENT" "$NOTEBOOK_ID" "/Synced/$TITLE" "supabase" "$METADATA"
}

# Get Resources notebook ID (for learnings)
RESOURCES_NOTEBOOK="20231114112235-resources"

# Fetch and sync learnings from Supabase
echo "📚 Syncing learnings to Cortex..."
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=*&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

LEARNING_COUNT=0
LEARNING_UPDATED=0
LEARNING_CREATED=0

echo "$LEARNINGS" | jq -c '.[]' | while read -r learning; do
    TOPIC=$(echo "$learning" | jq -r '.topic // empty')
    CONTENT=$(echo "$learning" | jq -r '.content // empty')
    CATEGORY=$(echo "$learning" | jq -r '.category // "general"')
    TAGS=$(echo "$learning" | jq -r '.tags | if . then join(", ") else "synced" end')

    if [ -z "$TOPIC" ]; then continue; fi

    # Upsert in Cortex (updates if exists, creates if not)
    DOC_ID=$(upsert_cortex_doc "resources" "Learning: $TOPIC" "$CONTENT" "$TAGS")

    if [ -n "$DOC_ID" ]; then
        echo "✅ Synced learning: $TOPIC (ID: $DOC_ID)"
        LEARNING_COUNT=$((LEARNING_COUNT + 1))
    else
        echo "⚠️  Failed: $TOPIC"
    fi
done

echo "   Processed: $LEARNING_COUNT learnings"

# Sync patterns
echo ""
echo "🎯 Syncing patterns to Cortex..."
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=*&limit=50" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}")

PATTERN_COUNT=0
PATTERN_UPDATED=0
PATTERN_CREATED=0

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

    # Upsert in Cortex (updates if exists, creates if not)
    DOC_ID=$(upsert_cortex_doc "resources" "Pattern: $NAME" "$CONTENT" "$CATEGORY,pattern,synced")

    if [ -n "$DOC_ID" ]; then
        echo "✅ Synced pattern: $NAME (ID: $DOC_ID)"
        PATTERN_COUNT=$((PATTERN_COUNT + 1))
    else
        echo "⚠️  Failed: $NAME"
    fi
done

echo "   Processed: $PATTERN_COUNT patterns"

echo ""
echo "✅ Cortex sync complete (Learnings: $LEARNING_COUNT, Patterns: $PATTERN_COUNT)"
echo "   All documents tagged with source=supabase for duplicate prevention"
