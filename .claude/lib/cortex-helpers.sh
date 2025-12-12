#!/bin/bash
# Cortex Helper Library - Upsert Logic to Prevent Duplicates
# Created: 2025-12-11
# Purpose: Shared functions for all Cortex integration scripts
# Implements proper check-update-create pattern

# CRITICAL: This library prevents duplicate document creation in Cortex
# All scripts MUST use upsert_doc() instead of direct createDocWithMd API calls

set -e

# ============================================================================
# CONFIGURATION & ENVIRONMENT
# ============================================================================

PROJECT_DIR="${PROJECT_DIR:-/Users/adamkovacs/Documents/codebuild}"

# Load environment variables if not already set
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Cortex/SiYuan configuration
SIYUAN_BASE_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${CORTEX_TOKEN}"

# Cloudflare Zero Trust Service Token auth
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"

# PARA Notebook IDs (Updated 2025-12-01)
NOTEBOOK_PROJECTS="20251103053911-8ex6uns"     # 01 Projects
NOTEBOOK_AREAS="20251201183343-543piyt"        # 02 Areas
NOTEBOOK_RESOURCES="20251201183343-ujsixib"    # 03 Resources
NOTEBOOK_ARCHIVES="20251201183343-xf2snc8"     # 04 Archives
NOTEBOOK_KB="20251103053840-moamndp"           # 05 Knowledge Base
NOTEBOOK_AGENTS="20251103053916-bq6qbgu"       # 06 Agents

# ============================================================================
# CORE HELPER FUNCTIONS
# ============================================================================

# Check if a document exists by title and custom-source attribute
# Args: $1=title, $2=source (e.g., "agentdb", "swarm", "hook")
# Returns: doc_id if exists, empty string if not
# Exit code: 0 if exists, 1 if not exists
doc_exists() {
    local SEARCH_TITLE="$1"
    local SEARCH_SOURCE="${2:-unknown}"

    # Search for existing document with same title
    local SEARCH_RESULT=$(curl -s -m 10 -X POST "${SIYUAN_BASE_URL}/api/search/fullTextSearchBlock" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg q "$SEARCH_TITLE" '{query: $q}')" 2>/dev/null)

    # Check if we found a match with matching custom-source attribute
    local DOC_ID=$(echo "$SEARCH_RESULT" | jq -r --arg src "$SEARCH_SOURCE" \
        '.data.blocks[]? | select(.ial."custom-source" == $src) | .id' | head -1)

    if [ -n "$DOC_ID" ]; then
        echo "$DOC_ID"
        return 0  # Exists
    fi

    return 1  # Doesn't exist
}

# Create a new document in Cortex
# Args: $1=notebook_id, $2=path, $3=markdown, $4=source, $5=metadata_json
# Returns: doc_id on success, empty on failure
# Exit code: 0 on success, 1 on failure
create_doc() {
    local NOTEBOOK_ID="$1"
    local DOC_PATH="$2"
    local MARKDOWN="$3"
    local SOURCE="$4"
    local METADATA_JSON="$5"

    # Set defaults AFTER assignment to avoid brace expansion issues
    SOURCE="${SOURCE:-unknown}"
    METADATA_JSON="${METADATA_JSON:-\{\}}"

    # Create document in Cortex
    local RESPONSE=$(curl -s -m 30 -X POST "${SIYUAN_BASE_URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg nb "$NOTEBOOK_ID" \
            --arg path "$DOC_PATH" \
            --arg md "$MARKDOWN" \
            '{notebook: $nb, path: $path, markdown: $md}')" 2>&1)

    # Check for success
    if echo "$RESPONSE" | jq -e '.code == 0' >/dev/null 2>&1; then
        local DOC_ID=$(echo "$RESPONSE" | jq -r '.data // ""')

        # Add metadata attributes if document was created
        if [ -n "$DOC_ID" ]; then
            # Build base attributes
            local BASE_ATTRS=$(jq -n \
                --arg src "$SOURCE" \
                --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{
                    "custom-source": $src,
                    "custom-synced": $ts,
                    "custom-version": "1"
                }')

            # Merge with provided metadata (compact both to ensure valid JSON)
            local COMPACT_BASE=$(echo "$BASE_ATTRS" | jq -c '.')
            # Ensure metadata is valid JSON before compacting
            local SAFE_METADATA="${METADATA_JSON:-\{\}}"
            if ! echo "$SAFE_METADATA" | jq empty 2>/dev/null; then
                SAFE_METADATA="{}"
            fi
            local COMPACT_META=$(echo "$SAFE_METADATA" | jq -c '.')
            local FULL_ATTRS=$(jq -nc --argjson base "$COMPACT_BASE" --argjson meta "$COMPACT_META" '$base + $meta')

            # Set attributes on the document
            curl -s -m 10 -X POST "${SIYUAN_BASE_URL}/api/attr/setBlockAttrs" \
                -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
                -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
                -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
                -H "Content-Type: application/json" \
                -d "$(jq -n \
                    --arg id "$DOC_ID" \
                    --argjson attrs "$FULL_ATTRS" \
                    '{id: $id, attrs: $attrs}')" >/dev/null 2>&1

            echo "$DOC_ID"
            return 0
        fi
    fi

    return 1  # Failed to create
}

# Update an existing document in Cortex
# Args: $1=doc_id, $2=new_markdown, $3=metadata_json
# Returns: doc_id on success, empty on failure
# Exit code: 0 on success, 1 on failure
update_doc() {
    local DOC_ID="$1"
    local NEW_MARKDOWN="$2"
    local METADATA_JSON="$3"

    # Set default AFTER assignment to avoid brace expansion issues
    METADATA_JSON="${METADATA_JSON:-\{\}}"

    # Update document content
    local RESPONSE=$(curl -s -m 30 -X POST "${SIYUAN_BASE_URL}/api/block/updateBlock" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n \
            --arg id "$DOC_ID" \
            --arg md "$NEW_MARKDOWN" \
            '{id: $id, dataType: "markdown", data: $md}')" 2>&1)

    # Check for success
    if echo "$RESPONSE" | jq -e '.code == 0' >/dev/null 2>&1; then
        # Get existing attributes to preserve them
        local EXISTING_ATTRS=$(curl -s -m 10 -X POST "${SIYUAN_BASE_URL}/api/attr/getBlockAttrs" \
            -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg id "$DOC_ID" '{id: $id}')" | jq -c '.data // {}')

        # Filter to only custom-* attributes
        local EXISTING_CUSTOM=$(echo "$EXISTING_ATTRS" | jq -c 'with_entries(select(.key | startswith("custom-")))')

        # Build update attributes
        local UPDATE_ATTRS=$(jq -n \
            --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '{"custom-updated": $ts}')

        # Ensure metadata is valid JSON
        local SAFE_METADATA="${METADATA_JSON:-{}}"
        if ! echo "$SAFE_METADATA" | jq empty 2>/dev/null; then
            SAFE_METADATA="{}"
        fi
        local COMPACT_META=$(echo "$SAFE_METADATA" | jq -c '.')

        # Increment version number
        local CURRENT_VERSION=$(echo "$EXISTING_CUSTOM" | jq -r '.["custom-version"] // "0"')
        local NEW_VERSION=$((${CURRENT_VERSION:-0} + 1))

        # Merge: existing + new metadata + update timestamp + version
        local FULL_ATTRS=$(jq -nc \
            --argjson existing "$EXISTING_CUSTOM" \
            --argjson meta "$COMPACT_META" \
            --argjson update "$(echo "$UPDATE_ATTRS" | jq -c '.')" \
            --arg ver "$NEW_VERSION" \
            '$existing + $meta + $update + {"custom-version": $ver}')

        # Set updated attributes
        local ATTRS_PAYLOAD=$(jq -n \
            --arg id "$DOC_ID" \
            --argjson attrs "$FULL_ATTRS" \
            '{id: $id, attrs: $attrs}' 2>/dev/null)

        curl -s -m 10 -X POST "${SIYUAN_BASE_URL}/api/attr/setBlockAttrs" \
            -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "$ATTRS_PAYLOAD" >/dev/null 2>&1

        echo "$DOC_ID"
        return 0
    fi

    return 1  # Failed to update
}

# Get a document attribute value
# Args: $1=doc_id, $2=attribute_name
# Returns: attribute value or empty string
get_doc_attribute() {
    local DOC_ID="$1"
    local ATTR_NAME="$2"

    local RESPONSE=$(curl -s -m 10 -X POST "${SIYUAN_BASE_URL}/api/attr/getBlockAttrs" \
        -H "Authorization: Token ${SIYUAN_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$(jq -n --arg id "$DOC_ID" '{id: $id}')" 2>/dev/null)

    echo "$RESPONSE" | jq -r --arg attr "$ATTR_NAME" '.data[$attr] // ""'
}

# ============================================================================
# PRIMARY UPSERT FUNCTION (USE THIS!)
# ============================================================================

# Upsert a document: update if exists, create if not
# This is the MAIN function all scripts should use
# Args: $1=title, $2=markdown, $3=notebook_id, $4=path, $5=source, $6=metadata_json
# Returns: doc_id on success, empty on failure
# Exit code: 0 on success, 1 on failure
upsert_doc() {
    local TITLE="$1"
    local MARKDOWN="$2"
    local NOTEBOOK_ID="$3"
    local DOC_PATH="$4"
    local SOURCE="$5"
    local METADATA_JSON="$6"

    # Set defaults AFTER assignment to avoid brace expansion issues
    SOURCE="${SOURCE:-unknown}"
    METADATA_JSON="${METADATA_JSON:-\{\}}"

    # Check if document already exists
    local EXISTING_DOC_ID=$(doc_exists "$TITLE" "$SOURCE")

    if [ -n "$EXISTING_DOC_ID" ]; then
        # Document exists - UPDATE it
        local DOC_ID=$(update_doc "$EXISTING_DOC_ID" "$MARKDOWN" "$METADATA_JSON")
        if [ -n "$DOC_ID" ]; then
            echo "$DOC_ID"
            return 0
        fi
        return 1
    else
        # Document doesn't exist - CREATE it
        local DOC_ID=$(create_doc "$NOTEBOOK_ID" "$DOC_PATH" "$MARKDOWN" "$SOURCE" "$METADATA_JSON")
        if [ -n "$DOC_ID" ]; then
            echo "$DOC_ID"
            return 0
        fi
        return 1
    fi
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Resolve notebook name to ID
# Args: $1=notebook_name (projects, areas, resources, etc.)
# Returns: notebook_id
resolve_notebook_id() {
    local NOTEBOOK_NAME="$1"

    case "$NOTEBOOK_NAME" in
        projects) echo "$NOTEBOOK_PROJECTS" ;;
        areas) echo "$NOTEBOOK_AREAS" ;;
        resources) echo "$NOTEBOOK_RESOURCES" ;;
        archives) echo "$NOTEBOOK_ARCHIVES" ;;
        knowledge_base|kb) echo "$NOTEBOOK_KB" ;;
        agents|agent_logs) echo "$NOTEBOOK_AGENTS" ;;
        *) echo "$NOTEBOOK_RESOURCES" ;;  # Default to resources
    esac
}

# Build standard metadata JSON for common use cases
# Args: $1=doc_type, $2=project_name, $3=additional_json
# Returns: metadata JSON string
build_metadata() {
    local DOC_TYPE="${1:-note}"
    local PROJECT_NAME="${2:-codebuild}"
    local ADDITIONAL_JSON="${3:-{}}"

    local BASE_META=$(jq -n \
        --arg type "$DOC_TYPE" \
        --arg proj "$PROJECT_NAME" \
        '{
            "custom-type": $type,
            "custom-project": $proj
        }')

    # Compact the additional JSON first to remove newlines
    local COMPACT_ADD=$(echo "$ADDITIONAL_JSON" | jq -c '.')
    echo "$BASE_META" | jq -c --argjson add "$COMPACT_ADD" '. + $add'
}

# ============================================================================
# BATCH OPERATIONS
# ============================================================================

# Batch upsert multiple documents (reduces API calls)
# Args: $1=json_array of documents (format: [{title, markdown, notebook, path, source, metadata}, ...])
# Returns: count of successful operations
batch_upsert() {
    local DOCS_JSON="$1"
    local SUCCESS_COUNT=0

    echo "$DOCS_JSON" | jq -c '.[]' | while read -r doc_json; do
        local TITLE=$(echo "$doc_json" | jq -r '.title')
        local MARKDOWN=$(echo "$doc_json" | jq -r '.markdown')
        local NOTEBOOK=$(echo "$doc_json" | jq -r '.notebook')
        local PATH=$(echo "$doc_json" | jq -r '.path')
        local SOURCE=$(echo "$doc_json" | jq -r '.source // "unknown"')
        local METADATA=$(echo "$doc_json" | jq -r '.metadata // "{}"')

        local NOTEBOOK_ID=$(resolve_notebook_id "$NOTEBOOK")

        if upsert_doc "$TITLE" "$MARKDOWN" "$NOTEBOOK_ID" "$PATH" "$SOURCE" "$METADATA" >/dev/null; then
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        fi
    done

    echo "$SUCCESS_COUNT"
}

# ============================================================================
# LIBRARY INFO
# ============================================================================

cortex_helpers_version() {
    echo "Cortex Helpers Library v1.0.0 (2025-12-11)"
    echo "Functions: doc_exists, create_doc, update_doc, upsert_doc, resolve_notebook_id, build_metadata, batch_upsert"
}

# Export functions for use in other scripts
export -f doc_exists
export -f create_doc
export -f update_doc
export -f upsert_doc
export -f get_doc_attribute
export -f resolve_notebook_id
export -f build_metadata
export -f batch_upsert
export -f cortex_helpers_version
