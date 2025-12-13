#!/bin/bash
# Index GitHub repos across multiple orgs to Qdrant
# Indexes READMEs, docs, and key files for semantic search
# Created: 2025-12-10

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

[ -z "$QDRANT_API_KEY" ] && { echo "QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "GEMINI_API_KEY not set"; exit 1; }

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
COLLECTION="codebase"
CACHE_DIR="$PROJECT_DIR/.github-cache"
SYNC_STATE_FILE="/tmp/github-qdrant-sync-state.json"

# Organizations to index
ORGS=("adambkovacs" "ai-enablement-academy" "The-Talent-Foundation" "heymax-agency" "campfire-creative")

echo "🔗 GitHub Repository Indexer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📂 Cache: $CACHE_DIR"
echo "🔌 Qdrant: $QDRANT_URL/collections/$COLLECTION"

mkdir -p "$CACHE_DIR"

# Get Gemini embedding
get_embedding() {
    local text="$1"
    local escaped_text=$(echo "$text" | jq -Rs '.')

    curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/gemini-embedding-001\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" | jq -c '.embedding.values // empty'
}

# Upsert to Qdrant
upsert_to_qdrant() {
    local id="$1"
    local vector="$2"
    local payload="$3"

    local numeric_id=$(echo -n "$id" | md5sum | cut -c1-16)
    numeric_id=$((16#$numeric_id % 2147483647))

    curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $numeric_id,
                \"vector\": $vector,
                \"payload\": $payload
            }]
        }" > /dev/null
}

TOTAL_INDEXED=0

for ORG in "${ORGS[@]}"; do
    echo ""
    echo "🏢 Processing: $ORG"
    echo "─────────────────────────"

    # Get repos for org
    REPOS=$(gh repo list "$ORG" --limit 50 --json name,description,pushedAt,url --jq '.[] | @base64' 2>/dev/null || echo "")

    if [ -z "$REPOS" ]; then
        echo "  ⚠️  No repos found or access denied"
        continue
    fi

    for REPO_B64 in $REPOS; do
        REPO_JSON=$(echo "$REPO_B64" | base64 -d)
        REPO_NAME=$(echo "$REPO_JSON" | jq -r '.name')
        REPO_DESC=$(echo "$REPO_JSON" | jq -r '.description // "No description"')
        REPO_URL=$(echo "$REPO_JSON" | jq -r '.url')
        PUSHED_AT=$(echo "$REPO_JSON" | jq -r '.pushedAt')

        REPO_CACHE="$CACHE_DIR/$ORG/$REPO_NAME"

        echo "  📦 $REPO_NAME"

        # Check if we need to update (based on pushedAt)
        LAST_INDEXED=""
        if [ -f "$REPO_CACHE/.last_indexed" ]; then
            LAST_INDEXED=$(cat "$REPO_CACHE/.last_indexed")
        fi

        if [ "$LAST_INDEXED" = "$PUSHED_AT" ]; then
            echo "    ⏭️  Already indexed (no changes)"
            continue
        fi

        # Clone or update repo
        if [ -d "$REPO_CACHE/.git" ]; then
            echo "    🔄 Updating..."
            (cd "$REPO_CACHE" && git pull -q 2>/dev/null) || true
        else
            echo "    📥 Cloning..."
            mkdir -p "$CACHE_DIR/$ORG"
            gh repo clone "$ORG/$REPO_NAME" "$REPO_CACHE" -- --depth 1 -q 2>/dev/null || {
                echo "    ❌ Clone failed, skipping"
                continue
            }
        fi

        # Index README
        for README in "$REPO_CACHE"/README* "$REPO_CACHE"/readme*; do
            [ ! -f "$README" ] && continue

            echo "    📄 Indexing README..."
            CONTENT=$(cat "$README" | head -c 8000)

            if [ ${#CONTENT} -gt 100 ]; then
                EMBEDDING=$(get_embedding "$CONTENT")

                if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
                    PAYLOAD=$(jq -n \
                        --arg type "github-readme" \
                        --arg source "github" \
                        --arg content "$CONTENT" \
                        --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        --arg repo_name "$REPO_NAME" \
                        --arg org "$ORG" \
                        --arg description "$REPO_DESC" \
                        --arg url "$REPO_URL" \
                        --arg file_path "README.md" \
                        '{
                            type: $type,
                            source: $source,
                            content: $content,
                            indexed_at: $indexed_at,
                            version: 1,
                            github: {
                                org: $org,
                                repo: $repo_name,
                                description: $description,
                                url: $url,
                                file_path: $file_path
                            }
                        }')

                    upsert_to_qdrant "github-$ORG-$REPO_NAME-readme" "$EMBEDDING" "$PAYLOAD"
                    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
                    echo -n "."
                fi
            fi
            break  # Only first README
        done

        # Index key documentation files
        for DOC in "$REPO_CACHE"/docs/*.md "$REPO_CACHE"/DOCS/*.md "$REPO_CACHE"/*.md "$REPO_CACHE"/CHANGELOG* "$REPO_CACHE"/CONTRIBUTING*; do
            [ ! -f "$DOC" ] && continue
            # Skip READMEs (already indexed)
            [[ "$(basename "$DOC")" =~ ^[Rr][Ee][Aa][Dd][Mm][Ee] ]] && continue

            DOC_NAME=$(basename "$DOC")
            CONTENT=$(cat "$DOC" | head -c 5000)

            if [ ${#CONTENT} -gt 100 ]; then
                EMBEDDING=$(get_embedding "$CONTENT")

                if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
                    PAYLOAD=$(jq -n \
                        --arg type "github-doc" \
                        --arg source "github" \
                        --arg content "$CONTENT" \
                        --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        --arg repo_name "$REPO_NAME" \
                        --arg org "$ORG" \
                        --arg url "$REPO_URL" \
                        --arg file_path "$DOC_NAME" \
                        '{
                            type: $type,
                            source: $source,
                            content: $content,
                            indexed_at: $indexed_at,
                            version: 1,
                            github: {
                                org: $org,
                                repo: $repo_name,
                                url: $url,
                                file_path: $file_path
                            }
                        }')

                    upsert_to_qdrant "github-$ORG-$REPO_NAME-$DOC_NAME" "$EMBEDDING" "$PAYLOAD"
                    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
                    echo -n "."
                fi
            fi
        done

        # Mark as indexed
        echo "$PUSHED_AT" > "$REPO_CACHE/.last_indexed"
        echo ""
    done
done

# Update sync state
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
jq -n --arg last_sync "$NOW" --argjson indexed "$TOTAL_INDEXED" \
    '{last_sync: $last_sync, last_indexed_count: $indexed}' > "$SYNC_STATE_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ GitHub indexing complete"
echo "   Total indexed: $TOTAL_INDEXED documents"
