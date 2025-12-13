#!/bin/bash
# Deduplicate Supabase learnings - keeps latest entry per topic
# Run with --dry-run to see what would be deleted

set -a
source /Users/adamkovacs/Documents/codebuild/.env 2>/dev/null || true
set +a

SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo "🔍 DRY RUN MODE - No changes will be made"
fi

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           SUPABASE LEARNINGS DEDUPLICATION                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get total count
TOTAL=$(curl -s -I "${SUPABASE_URL}/rest/v1/learnings?select=id&limit=1" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Prefer: count=exact" | grep -i "content-range" | sed 's/.*\///' | tr -d '\r\n')

echo "📊 Current State:"
echo "   Total learnings: $TOTAL"

# Find duplicate topics
echo ""
echo "🔍 Finding duplicate topics..."

# Get all topics and find duplicates
DUPLICATES=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=topic" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Range: 0-9999" | jq -r '.[].topic' | sort | uniq -d)

DUP_COUNT=$(echo "$DUPLICATES" | grep -c . || echo 0)

if [ "$DUP_COUNT" -eq 0 ] || [ -z "$DUPLICATES" ]; then
    echo "✅ No duplicate topics found!"
    exit 0
fi

echo "   Found $DUP_COUNT topics with duplicates"
echo ""
echo "📋 Duplicate Topics (showing first 10):"
echo "$DUPLICATES" | head -10 | while read topic; do
    COUNT=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?topic=eq.$(echo "$topic" | jq -sRr @uri)&select=id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" | jq 'length')
    echo "   [$COUNT copies] ${topic:0:60}..."
done

if [ "$DRY_RUN" = true ]; then
    echo ""
    echo "🔍 Would process $DUP_COUNT duplicate topics"
    echo "   Run without --dry-run to execute"
    exit 0
fi

echo ""
echo "🗑️  Removing duplicates (keeping latest per topic)..."

DELETED=0

# Process each duplicate topic
echo "$DUPLICATES" | while read topic; do
    [ -z "$topic" ] && continue

    # Get all IDs for this topic, ordered by created_at desc
    IDS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?topic=eq.$(echo "$topic" | jq -sRr @uri)&select=id,created_at&order=created_at.desc" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" | jq -r '.[1:] | .[].id')

    # Delete all but the first (latest)
    for id in $IDS; do
        [ -z "$id" ] && continue
        curl -s -X DELETE "${SUPABASE_URL}/rest/v1/learnings?id=eq.${id}" \
            -H "apikey: ${SUPABASE_KEY}" \
            -H "Authorization: Bearer ${SUPABASE_KEY}" > /dev/null
        ((DELETED++)) || true
    done
done

# Get new count
NEW_TOTAL=$(curl -s -I "${SUPABASE_URL}/rest/v1/learnings?select=id&limit=1" \
    -H "apikey: ${SUPABASE_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_KEY}" \
    -H "Prefer: count=exact" | grep -i "content-range" | sed 's/.*\///' | tr -d '\r\n')

echo ""
echo "✅ Deduplication Complete:"
echo "   Before: $TOTAL learnings"
echo "   After: $NEW_TOTAL learnings"
echo "   Deleted: $((TOTAL - NEW_TOTAL)) duplicates"
