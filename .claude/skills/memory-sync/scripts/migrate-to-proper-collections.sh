#!/bin/bash
# ====================================================
# QDRANT COLLECTION MIGRATION
# Moves data from agent_memory to proper collections
# ====================================================

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../.env" 2>/dev/null || true

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔄 Qdrant Collection Migration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This will migrate data from agent_memory to proper collections:"
echo "  - type=code → codebase"
echo "  - type=learning → learnings"
echo "  - type=pattern → patterns"
echo "  - type=episode → stays in agent_memory"
echo ""

# Ensure target collections exist with correct schema
ensure_collection() {
    local name=$1
    echo -e "${YELLOW}📦 Ensuring collection: $name${NC}"

    # Check if exists
    EXISTS=$(curl -s "$QDRANT_URL/collections/$name" \
        -H "api-key: $QDRANT_API_KEY" | jq -r '.result.status // "not_found"')

    if [ "$EXISTS" = "not_found" ]; then
        echo -e "  Creating collection..."
        curl -s -X PUT "$QDRANT_URL/collections/$name" \
            -H "api-key: $QDRANT_API_KEY" \
            -H "Content-Type: application/json" \
            -d '{
                "vectors": {
                    "size": 768,
                    "distance": "Cosine"
                }
            }' | jq -r '.status'
    else
        echo -e "  Collection exists"
    fi
}

# Migrate points from agent_memory to target collection
migrate_type() {
    local type=$1
    local target=$2
    local batch_size=100
    local offset=""
    local total_migrated=0

    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📦 Migrating type=$type → $target${NC}"

    # Count points to migrate
    local count=$(curl -s -X POST "$QDRANT_URL/collections/agent_memory/points/count" \
        -H "api-key: $QDRANT_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"filter\": {\"must\": [{\"key\": \"type\", \"match\": {\"value\": \"$type\"}}]}}" | jq -r '.result.count')

    echo -e "  Points to migrate: $count"

    if [ "$count" = "0" ]; then
        echo -e "  ${YELLOW}Nothing to migrate${NC}"
        return
    fi

    # Scroll through and migrate in batches
    while true; do
        # Build scroll request
        local scroll_body
        if [ -z "$offset" ]; then
            scroll_body="{\"limit\": $batch_size, \"with_payload\": true, \"with_vector\": true, \"filter\": {\"must\": [{\"key\": \"type\", \"match\": {\"value\": \"$type\"}}]}}"
        else
            scroll_body="{\"limit\": $batch_size, \"offset\": \"$offset\", \"with_payload\": true, \"with_vector\": true, \"filter\": {\"must\": [{\"key\": \"type\", \"match\": {\"value\": \"$type\"}}]}}"
        fi

        # Get batch of points
        local result=$(curl -s -X POST "$QDRANT_URL/collections/agent_memory/points/scroll" \
            -H "api-key: $QDRANT_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$scroll_body")

        local points=$(echo "$result" | jq -c '.result.points')
        local next_offset=$(echo "$result" | jq -r '.result.next_page_offset // empty')
        local batch_count=$(echo "$points" | jq 'length')

        if [ "$batch_count" = "0" ]; then
            break
        fi

        # Upsert to target collection
        local upsert_body=$(echo "$points" | jq '{points: .}')

        local upsert_result=$(curl -s -X PUT "$QDRANT_URL/collections/$target/points" \
            -H "api-key: $QDRANT_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$upsert_body")

        local status=$(echo "$upsert_result" | jq -r '.status')

        if [ "$status" = "ok" ]; then
            total_migrated=$((total_migrated + batch_count))
            echo -e "  Migrated batch: $batch_count (total: $total_migrated/$count)"
        else
            echo -e "${RED}  Error: $(echo "$upsert_result" | jq -r '.status.error // "unknown"')${NC}"
        fi

        # Move to next batch
        if [ -z "$next_offset" ]; then
            break
        fi
        offset="$next_offset"

        # Rate limit
        sleep 0.5
    done

    echo -e "${GREEN}  ✅ Migrated $total_migrated points to $target${NC}"
}

# Delete migrated points from agent_memory
cleanup_type() {
    local type=$1

    echo -e "${YELLOW}🧹 Cleaning up type=$type from agent_memory...${NC}"

    # Delete by filter
    local result=$(curl -s -X POST "$QDRANT_URL/collections/agent_memory/points/delete" \
        -H "api-key: $QDRANT_API_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"filter\": {\"must\": [{\"key\": \"type\", \"match\": {\"value\": \"$type\"}}]}}")

    local status=$(echo "$result" | jq -r '.status')
    if [ "$status" = "ok" ]; then
        echo -e "${GREEN}  ✅ Deleted type=$type from agent_memory${NC}"
    else
        echo -e "${RED}  Error: $(echo "$result" | jq -r '.status.error // "unknown"')${NC}"
    fi
}

# Main migration
echo -e "${YELLOW}Step 1: Ensure target collections exist${NC}"
ensure_collection "codebase"
ensure_collection "learnings"
ensure_collection "patterns"

echo ""
echo -e "${YELLOW}Step 2: Migrate data to proper collections${NC}"
migrate_type "code" "codebase"
migrate_type "learning" "learnings"
migrate_type "pattern" "patterns"

echo ""
echo -e "${YELLOW}Step 3: Clean up agent_memory (remove migrated data)${NC}"
cleanup_type "code"
cleanup_type "learning"
cleanup_type "pattern"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Migration Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Final counts
echo ""
echo "📊 Final Collection Counts:"
for col in agent_memory codebase learnings patterns; do
    COUNT=$(curl -s "$QDRANT_URL/collections/$col" \
        -H "api-key: $QDRANT_API_KEY" | jq -r '.result.points_count // 0')
    echo "  $col: $COUNT"
done
