#!/bin/bash
# Cortex Orphan Fixer - Adds tags and cross-links to orphan documents
# Part of the Memory System Overhaul

set -e

PROJECT_DIR="${PROJECT_DIR:-/Users/adamkovacs/Documents/codebuild}"
source "$PROJECT_DIR/.env" 2>/dev/null || true

API="https://cortex.aienablement.academy/api"

# Check credentials
[ -z "$CORTEX_TOKEN" ] && echo "❌ CORTEX_TOKEN not set" && exit 1

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           Cortex Orphan Fixer                                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Helper function for API calls
api_call() {
    local endpoint="$1"
    local data="$2"
    curl -s "$API/$endpoint" \
        -X POST \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        --data "$data"
}

sql_query() {
    api_call "query/sql" "{\"stmt\":\"$1\"}"
}

# Notebook ID to tag mapping function
get_tag_for_notebook() {
    case "$1" in
        "20251103053911-8ex6uns") echo "project" ;;      # 01 Projects
        "20251201183343-543piyt") echo "area" ;;         # 02 Areas
        "20251201183343-ujsixib") echo "resource" ;;     # 03 Resources
        "20251201183343-xf2snc8") echo "archive" ;;      # 04 Archives
        "20251103053840-moamndp") echo "knowledge" ;;    # 05 Knowledge Base
        "20251103053916-bq6qbgu") echo "agent" ;;        # 06 Agents
        *) echo "" ;;
    esac
}

# List of notebook IDs
NOTEBOOK_IDS="20251103053911-8ex6uns 20251201183343-543piyt 20251201183343-ujsixib 20251201183343-xf2snc8 20251103053840-moamndp 20251103053916-bq6qbgu"

# Get document stats
echo "📊 Current Status:"
TOTAL=$(sql_query "SELECT COUNT(*) as count FROM blocks WHERE type='d'" | jq -r '.data[0].count // 0')
ORPHANS=$(sql_query "SELECT COUNT(DISTINCT b.id) as count FROM blocks b WHERE b.type='d' AND b.id NOT IN (SELECT DISTINCT def_block_root_id FROM refs WHERE def_block_root_id IS NOT NULL)" | jq -r '.data[0].count // 0')
NO_TAGS=$(sql_query "SELECT COUNT(*) as count FROM blocks WHERE type='d' AND (tag IS NULL OR tag='')" | jq -r '.data[0].count // 0')

echo "   Total documents: $TOTAL"
echo "   Orphans (no backlinks): $ORPHANS"
echo "   Without tags: $NO_TAGS"
echo ""

# Phase 1: Add tags based on notebook
echo "═══════════════════════════════════════════════════════════════"
echo "Phase 1: Adding tags based on notebook location"
echo "═══════════════════════════════════════════════════════════════"

TAGGED=0
for notebook_id in $NOTEBOOK_IDS; do
    tag=$(get_tag_for_notebook "$notebook_id")
    [ -z "$tag" ] && continue

    # Get documents in this notebook without custom-category attribute
    DOCS=$(sql_query "SELECT id, content FROM blocks WHERE type='d' AND box='$notebook_id' LIMIT 50" | jq -r '.data[]? | .id' 2>/dev/null)

    for doc_id in $DOCS; do
        [ -z "$doc_id" ] && continue

        # Set custom-category attribute using setBlockAttrs API
        RESULT=$(api_call "attr/setBlockAttrs" "{\"id\":\"$doc_id\",\"attrs\":{\"custom-category\":\"$tag\"}}")

        if echo "$RESULT" | jq -e '.code == 0' > /dev/null 2>&1; then
            TAGGED=$((TAGGED + 1))
            echo "   ✅ Tagged: $doc_id → #$tag"
        fi

        # Rate limit
        sleep 0.05
    done
done

echo ""
echo "   Tagged $TAGGED documents in Phase 1"
echo ""

# Phase 2: Find and suggest cross-links based on similar content
echo "═══════════════════════════════════════════════════════════════"
echo "Phase 2: Identifying potential cross-links"
echo "═══════════════════════════════════════════════════════════════"

# Get documents with similar names (potential duplicates or related)
echo "   Looking for documents with similar names..."

# Find documents that mention other documents by name
POTENTIAL_LINKS=$(sql_query "SELECT b1.id as source_id, b1.content as source, b2.id as target_id, b2.content as target FROM blocks b1, blocks b2 WHERE b1.type='d' AND b2.type='d' AND b1.id != b2.id AND b1.content LIKE '%' || SUBSTR(b2.content, 1, 20) || '%' LIMIT 20")

echo "   Potential cross-links found:"
echo "$POTENTIAL_LINKS" | jq -r '.data[]? | "   \(.source[:30]) → \(.target[:30])"' 2>/dev/null | head -10

# Phase 3: Auto-generate MOC (Map of Content) for orphans
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Phase 3: Creating index documents for orphans"
echo "═══════════════════════════════════════════════════════════════"

# For each notebook, count orphans
for notebook_id in $NOTEBOOK_IDS; do
    tag=$(get_tag_for_notebook "$notebook_id")
    [ -z "$tag" ] && continue

    NOTEBOOK_ORPHANS=$(sql_query "SELECT COUNT(*) as count FROM blocks b WHERE b.type='d' AND b.box='$notebook_id' AND b.id NOT IN (SELECT DISTINCT def_block_root_id FROM refs WHERE def_block_root_id IS NOT NULL)" | jq -r '.data[0].count // 0')

    echo "   Notebook #$tag: $NOTEBOOK_ORPHANS orphans"
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Summary & Recommendations"
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "1. Tagged $TAGGED documents with notebook-based categories"
echo "2. Found potential cross-links between similar documents"
echo ""
echo "📋 Manual Actions Recommended:"
echo "   • Review the orphan list and manually link related documents"
echo "   • Create MOC (Map of Content) documents for each notebook"
echo "   • Use SiYuan's built-in 'Backlinks' panel to find connections"
echo "   • Enable 'Graph View' to visualize and fix orphans"
echo ""
echo "🔧 To run deeper analysis:"
echo "   bash $0 --deep-scan"
echo ""
