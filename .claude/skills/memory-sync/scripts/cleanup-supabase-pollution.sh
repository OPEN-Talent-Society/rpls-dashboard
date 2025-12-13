#!/bin/bash
# Cleanup Supabase pollution from sync issues
# Removes polluted entries from learnings and patterns tables
# Usage: cleanup-supabase-pollution.sh [--dry-run] [--limit N]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_FILE="/tmp/cleanup-supabase-$(date +%Y%m%d-%H%M%S).log"

# Extract env vars individually to avoid zsh parse errors
SUPABASE_URL=$(grep "^PUBLIC_SUPABASE_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' || echo "")
SUPABASE_KEY=$(grep "^SUPABASE_SERVICE_ROLE_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' || echo "")

# Validate required env vars
[ -z "$SUPABASE_URL" ] && { echo "❌ PUBLIC_SUPABASE_URL not set in .env"; exit 1; }
[ -z "$SUPABASE_KEY" ] && { echo "❌ SUPABASE_SERVICE_ROLE_KEY not set in .env"; exit 1; }

# Parse arguments
DRY_RUN=false
LIMIT=100  # Default safety limit per query
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--dry-run] [--limit N]"
            exit 1
            ;;
    esac
done

echo "🧹 Supabase Pollution Cleanup"
echo "   URL: $SUPABASE_URL"
echo "   Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE')"
echo "   Limit: $LIMIT rows per query"
echo "   Log: $LOG_FILE"
echo ""

# Initialize counters
LEARNINGS_DELETED=0
LEARNINGS_REMAINING=0
PATTERNS_DELETED=0
PATTERNS_REMAINING=0

# Function to get count from table with filter
get_count() {
    local table="$1"
    local filter="$2"

    local response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/${table}?select=count&${filter}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact")

    # Extract count from Content-Range header via separate call
    # Supabase returns count in response when using count=exact
    echo "$response" | python3 -c "
import sys, json
try:
    # For count queries, Supabase returns array with single object
    data = json.load(sys.stdin)
    if isinstance(data, list) and len(data) > 0:
        print(data[0].get('count', 0))
    else:
        print(0)
except:
    print(0)
" 2>/dev/null
}

# Function to delete from table with filter
delete_from_table() {
    local table="$1"
    local filter="$2"
    local description="$3"

    echo "🔍 Searching $table for: $description" >&2

    # First, count how many we'll delete
    local count_response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/${table}?select=id&${filter}&limit=${LIMIT}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}")

    local count=$(echo "$count_response" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        echo "   ✓ No matches found" >&2
        echo "0"
        return 0
    fi

    echo "   Found: $count rows" >&2

    # Log sample of what will be deleted
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $table - $description: Found $count rows" >> "$LOG_FILE"
    echo "$count_response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for row in data[:5]:
        print(f\"     - ID {row.get('id', 'N/A')}\")
    if len(data) > 5:
        print(f\"     ... and {len(data) - 5} more\")
except:
    pass
" >> "$LOG_FILE"

    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY RUN] Would delete $count rows" >&2
        echo "0"
        return 0
    fi

    # Delete with limit for safety
    local delete_response=$(curl -s -X DELETE "${SUPABASE_URL}/rest/v1/${table}?${filter}&limit=${LIMIT}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: return=minimal")

    # Check HTTP status (204 = success for DELETE)
    # Supabase returns empty response on successful delete with return=minimal
    if [ -z "$delete_response" ] || echo "$delete_response" | grep -qi "error" ; then
        if [ -z "$delete_response" ]; then
            echo "   ✅ Deleted $count rows" >&2
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $table - $description: Deleted $count rows" >> "$LOG_FILE"
            echo "$count"
            return 0
        else
            echo "   ❌ Delete failed: $delete_response" >&2
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $table - $description: FAILED - $delete_response" >> "$LOG_FILE"
            echo "0"
            return 0
        fi
    else
        echo "   ✅ Deleted $count rows" >&2
        echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $table - $description: Deleted $count rows" >> "$LOG_FILE"
        echo "$count"
        return 0
    fi
}

# Function to get total table count
get_table_count() {
    local table="$1"

    local response=$(curl -s -X GET "${SUPABASE_URL}/rest/v1/${table}?select=id&limit=1" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact")

    # Extract count from response header simulation
    # For actual count, we need to make a dedicated count query
    curl -s -X HEAD "${SUPABASE_URL}/rest/v1/${table}?select=id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact" \
        -D - 2>/dev/null | grep -i "content-range" | sed 's/.*\///' | tr -d '\r\n' || echo "0"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Table: learnings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get initial count (approximate - Supabase count queries can be expensive)
echo "Counting initial rows..."
echo ""

# 1. Delete topics starting with "supabase"
DELETED=$(delete_from_table "learnings" "topic=like.supabase*" "topics starting with 'supabase'")
LEARNINGS_DELETED=$((LEARNINGS_DELETED + DELETED))

# 2. Delete topics starting with "chunk"
DELETED=$(delete_from_table "learnings" "topic=like.chunk*" "topics starting with 'chunk'")
LEARNINGS_DELETED=$((LEARNINGS_DELETED + DELETED))

# 3. Delete topics starting with "Episode-"
DELETED=$(delete_from_table "learnings" "topic=like.Episode-*" "topics starting with 'Episode-'")
LEARNINGS_DELETED=$((LEARNINGS_DELETED + DELETED))

# Alternative: Use OR filter for efficiency (if one pattern covers multiple)
# DELETED=$(delete_from_table "learnings" "or=(topic.like.supabase*,topic.like.chunk*,topic.like.Episode-*)" "polluted topics (combined)")
# LEARNINGS_DELETED=$((LEARNINGS_DELETED + DELETED))

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Table: patterns"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 4. Delete pattern names starting with "supabase"
DELETED=$(delete_from_table "patterns" "name=like.supabase*" "names starting with 'supabase'")
PATTERNS_DELETED=$((PATTERNS_DELETED + DELETED))

# 5. Delete pattern names starting with "Episode-"
DELETED=$(delete_from_table "patterns" "name=like.Episode-*" "names starting with 'Episode-'")
PATTERNS_DELETED=$((PATTERNS_DELETED + DELETED))

# 6. Delete patterns with category "agent_episode" that look polluted
# (These should be in agent_memory, not patterns)
DELETED=$(delete_from_table "patterns" "and=(category.eq.agent_episode,or=(name.like.Episode-*,name.like.chunk*))" "polluted agent_episodes")
PATTERNS_DELETED=$((PATTERNS_DELETED + DELETED))

# Get final counts
echo ""
echo "Counting remaining rows..."
LEARNINGS_REMAINING=$(get_table_count "learnings")
PATTERNS_REMAINING=$(get_table_count "patterns")

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CLEANUP SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Table: learnings"
echo "   Deleted:   $LEARNINGS_DELETED rows"
echo "   Remaining: $LEARNINGS_REMAINING rows (approximate)"
echo ""
echo "Table: patterns"
echo "   Deleted:   $PATTERNS_DELETED rows"
echo "   Remaining: $PATTERNS_REMAINING rows (approximate)"
echo ""
echo "Total deleted: $((LEARNINGS_DELETED + PATTERNS_DELETED)) rows"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 This was a DRY RUN - no changes were made"
    echo "   Run without --dry-run to actually delete rows"
    echo ""
    echo "💡 To delete all pollution at once, run:"
    echo "   bash $0"
fi

exit 0
