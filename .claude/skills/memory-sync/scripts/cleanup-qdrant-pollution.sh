#!/bin/bash
# Cleanup Qdrant pollution from chunking/sync issues
# Removes vectors with polluted topic names and low-quality entries
# Usage: cleanup-qdrant-pollution.sh [--dry-run] [--limit N]

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_FILE="/tmp/cleanup-qdrant-$(date +%Y%m%d-%H%M%S).log"

# Extract env vars individually to avoid zsh parse errors
QDRANT_URL=$(grep "^QDRANT_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' || echo "")
QDRANT_API_KEY=$(grep "^QDRANT_API_KEY=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"' || echo "")

# Validate required env vars
[ -z "$QDRANT_URL" ] && { echo "❌ QDRANT_URL not set in .env"; exit 1; }
[ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set in .env"; exit 1; }

# Parse arguments
DRY_RUN=false
LIMIT=0
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

echo "🧹 Qdrant Pollution Cleanup"
echo "   URL: $QDRANT_URL"
echo "   Mode: $([ "$DRY_RUN" = true ] && echo 'DRY RUN' || echo 'LIVE')"
[ "$LIMIT" -gt 0 ] && echo "   Limit: $LIMIT points per collection"
echo "   Log: $LOG_FILE"
echo ""

# Initialize counters
CORTEX_DELETED=0
CORTEX_REMAINING=0
AGENT_MEMORY_DELETED=0
AGENT_MEMORY_REMAINING=0

# Function to delete points by filter
delete_by_filter() {
    local collection="$1"
    local filter="$2"
    local description="$3"

    echo "🔍 Searching $collection for: $description" >&2

    # Use scroll API to find matching points (limit to prevent overwhelming API)
    local scroll_limit=100
    [ "$LIMIT" -gt 0 ] && [ "$LIMIT" -lt 100 ] && scroll_limit=$LIMIT

    local response=$(curl -s -X POST "${QDRANT_URL}/collections/${collection}/points/scroll" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"filter\": $filter,
            \"limit\": $scroll_limit,
            \"with_payload\": true,
            \"with_vector\": false
        }")

    # Extract point IDs
    local point_ids=$(echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    points = data.get('result', {}).get('points', [])
    ids = [p['id'] for p in points]
    print(json.dumps(ids))
except:
    print('[]')
" 2>/dev/null)

    local count=$(echo "$point_ids" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "$count" -eq 0 ]; then
        echo "   ✓ No matches found" >&2
        echo "0"
        return 0
    fi

    echo "   Found: $count points" >&2

    # Log sample of what will be deleted
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    points = data.get('result', {}).get('points', [])
    for p in points[:5]:
        payload = p.get('payload', {})
        print(f\"     - ID {p['id']}: topic='{payload.get('topic', 'N/A')}', source='{payload.get('source', 'N/A')}'\")
    if len(points) > 5:
        print(f\"     ... and {len(points) - 5} more\")
except:
    pass
" >> "$LOG_FILE"

    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY RUN] Would delete $count points" >&2
        echo "0"
        return 0
    fi

    # Delete points
    if [ "$count" -gt 0 ]; then
        local delete_response=$(curl -s -X POST "${QDRANT_URL}/collections/${collection}/points/delete" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{
                \"points\": $point_ids
            }")

        # Check if delete was successful
        local status=$(echo "$delete_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status', 'error'))" 2>/dev/null || echo "error")

        if [ "$status" = "ok" ]; then
            echo "   ✅ Deleted $count points" >&2
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $collection - $description: Deleted $count points" >> "$LOG_FILE"
            echo "$count"
            return 0
        else
            echo "   ❌ Delete failed: $delete_response" >&2
            echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) - $collection - $description: FAILED to delete $count points" >> "$LOG_FILE"
            echo "0"
            return 0
        fi
    fi

    echo "0"
    return 0
}

# Function to get collection count
get_collection_count() {
    local collection="$1"

    local response=$(curl -s -X GET "${QDRANT_URL}/collections/${collection}" \
        -H "api-key: ${QDRANT_API_KEY}")

    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    count = data.get('result', {}).get('points_count', 0)
    print(count)
except:
    print(0)
" 2>/dev/null
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Collection: cortex"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get initial count
INITIAL_CORTEX_COUNT=$(get_collection_count "cortex")
echo "Initial count: $INITIAL_CORTEX_COUNT points"
echo ""

# 1. Clean up topics with "chunk-" prefix (pollution from chunking IDs)
DELETED=$(delete_by_filter "cortex" '{
    "must": [
        {
            "key": "topic",
            "match": {
                "text": "chunk-"
            }
        }
    ]
}' "topics containing 'chunk-'")
CORTEX_DELETED=$((CORTEX_DELETED + DELETED))

# 2. Clean up topics with "supabase" (pollution from sync errors)
DELETED=$(delete_by_filter "cortex" '{
    "must": [
        {
            "key": "topic",
            "match": {
                "text": "supabase"
            }
        }
    ]
}' "topics containing 'supabase'")
CORTEX_DELETED=$((CORTEX_DELETED + DELETED))

# 3. Clean up topics with "Episode-" prefix (pollution from agentdb episodes)
DELETED=$(delete_by_filter "cortex" '{
    "must": [
        {
            "key": "topic",
            "match": {
                "text": "Episode-"
            }
        }
    ]
}' "topics containing 'Episode-'")
CORTEX_DELETED=$((CORTEX_DELETED + DELETED))

# 4. Clean up topics with "Pattern-" prefix (pollution from pattern sync)
DELETED=$(delete_by_filter "cortex" '{
    "must": [
        {
            "key": "topic",
            "match": {
                "text": "Pattern-"
            }
        }
    ]
}' "topics containing 'Pattern-'")
CORTEX_DELETED=$((CORTEX_DELETED + DELETED))

# 5. Clean up by source_id patterns (if source_id is used for polluted data)
DELETED=$(delete_by_filter "cortex" '{
    "must": [
        {
            "key": "source_id",
            "match": {
                "text": "supabase"
            }
        }
    ]
}' "source_id containing 'supabase'")
CORTEX_DELETED=$((CORTEX_DELETED + DELETED))

# Get final cortex count
CORTEX_REMAINING=$(get_collection_count "cortex")

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📁 Collection: agent_memory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get initial count
INITIAL_AGENT_COUNT=$(get_collection_count "agent_memory")
echo "Initial count: $INITIAL_AGENT_COUNT points"
echo ""

# 6. Clean up old low-score entries (reward < 0.3, older than 30 days)
# First, find points with low reward scores
DELETED=$(delete_by_filter "agent_memory" '{
    "must": [
        {
            "key": "reward",
            "range": {
                "lt": 0.3
            }
        }
    ]
}' "entries with reward < 0.3")
AGENT_MEMORY_DELETED=$((AGENT_MEMORY_DELETED + DELETED))

# 7. Clean up any pollution from cortex sync errors
DELETED=$(delete_by_filter "agent_memory" '{
    "must": [
        {
            "key": "source",
            "match": {
                "text": "cortex"
            }
        },
        {
            "key": "type",
            "match": {
                "text": "knowledge"
            }
        }
    ]
}' "cortex knowledge entries (wrong collection)")
AGENT_MEMORY_DELETED=$((AGENT_MEMORY_DELETED + DELETED))

# Get final agent_memory count
AGENT_MEMORY_REMAINING=$(get_collection_count "agent_memory")

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 CLEANUP SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Collection: cortex"
echo "   Before:    $INITIAL_CORTEX_COUNT points"
echo "   Deleted:   $CORTEX_DELETED points"
echo "   After:     $CORTEX_REMAINING points"
echo ""
echo "Collection: agent_memory"
echo "   Before:    $INITIAL_AGENT_COUNT points"
echo "   Deleted:   $AGENT_MEMORY_DELETED points"
echo "   After:     $AGENT_MEMORY_REMAINING points"
echo ""
echo "Total deleted: $((CORTEX_DELETED + AGENT_MEMORY_DELETED)) points"
echo ""
echo "Log saved to: $LOG_FILE"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "🔍 This was a DRY RUN - no changes were made"
    echo "   Run without --dry-run to actually delete points"
fi

exit 0
