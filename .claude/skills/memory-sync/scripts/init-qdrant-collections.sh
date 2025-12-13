#!/bin/bash
# Initialize all required Qdrant collections with proper schemas
# Run this to ensure all collections exist before syncing
#
# ⚠️  IMPORTANT: This script NEVER deletes collections!
# ⚠️  Deleting a collection loses ALL vectors and requires FULL reindexing!
# ⚠️  The incremental indexing manifest tracks what's been indexed -
#     if you delete the collection, the manifest is now stale.
#
# If you MUST reset a collection:
#   1. Delete from Qdrant API directly (manual confirmation required)
#   2. Delete the manifest: rm .claude/skills/memory-sync/manifests/codebase-index-manifest.json
#   3. Run indexer with --force flag

set -a
source /Users/adamkovacs/Documents/codebuild/.env 2>/dev/null || true
set +a

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║           QDRANT COLLECTION INITIALIZATION                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Collections to create with their purposes (bash 3 compatible)
COLLECTION_NAMES=(
    "agent_memory"
    "learnings"
    "patterns"
    "codebase"
    "cortex"
    "research"
    "transcripts"
    "clients"
    "communications"
    "contacts"
)

COLLECTION_DESCS=(
    "Primary semantic memory for agent learnings and patterns"
    "Supabase learnings mirror with vector search"
    "Reasoning patterns for semantic matching"
    "Codebase chunks for code-aware search"
    "Cortex/SiYuan document embeddings"
    "Market research, competitive intelligence, analysis documents"
    "Audio/video transcriptions with speaker attribution"
    "Client profiles, interactions, proposals, contracts"
    "Emails, meeting notes, chat logs"
    "LinkedIn profiles, leads, prospects, company data, form submissions"
)

create_collection() {
    local name="$1"
    local desc="$2"

    echo "┌─ Creating: $name"
    echo "│  Purpose: $desc"

    # Check if exists
    EXISTS=$(curl -s "${QDRANT_URL}/collections/${name}" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.status // "error"')

    if [ "$EXISTS" = "ok" ]; then
        COUNT=$(curl -s "${QDRANT_URL}/collections/${name}" \
            -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0')
        echo "│  Status: Already exists ($COUNT points)"
        echo "└──────────────────────────────────────────────────────────────"
        return 0
    fi

    # Create with 768 dimensions (Gemini gemini-embedding-001 via MRL - upgraded from text-embedding-004)
    RESULT=$(curl -s -X PUT "${QDRANT_URL}/collections/${name}" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{
            "vectors": {
                "size": 768,
                "distance": "Cosine"
            },
            "on_disk_payload": true,
            "optimizers_config": {
                "indexing_threshold": 10000
            }
        }')

    if echo "$RESULT" | jq -e '.result == true' > /dev/null 2>&1; then
        echo "│  Status: ✅ Created successfully"
    else
        echo "│  Status: ❌ Failed"
        echo "│  Error: $(echo "$RESULT" | jq -r '.status.error // .status // "unknown"')"
    fi
    echo "└──────────────────────────────────────────────────────────────"
}

# Create all collections (bash 3 compatible loop)
i=0
while [ $i -lt ${#COLLECTION_NAMES[@]} ]; do
    create_collection "${COLLECTION_NAMES[$i]}" "${COLLECTION_DESCS[$i]}"
    echo ""
    i=$((i + 1))
done

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    COLLECTION SUMMARY                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# List all collections with counts
curl -s "${QDRANT_URL}/collections" -H "api-key: ${QDRANT_API_KEY}" | \
    jq -r '.result.collections[] | .name' | while read coll; do
    COUNT=$(curl -s "${QDRANT_URL}/collections/${coll}" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0')
    printf "   %-20s %s points\n" "$coll:" "$COUNT"
done

echo ""
echo "✅ Initialization complete"
