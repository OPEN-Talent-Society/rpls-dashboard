#!/bin/bash
# cortex-write.sh - Write documents to Cortex with upsert logic
# Prevents duplicates by checking for existing documents with same title/path
# Per MEMORY-SYSTEM-SPECIFICATION.md v3.0
#
# Usage:
#   cortex-write.sh --title "Title" --content "Content" --notebook "Resources" [--tags "tag1,tag2"] [--path "/custom/path"] [--type "learning|task|adr|sop"]
#
# Notebooks: Projects, Areas, Resources, Archives, Agents, Knowledge-Base
#
# Features:
#   - Upsert: Updates existing doc if path matches, creates new if not
#   - Content hash: Skips update if content unchanged
#   - YAML frontmatter: Adds structured metadata
#   - Auto-linking: Sets custom-semantic-links attribute
#   - Cross-reference URL: Stores Cortex URL for Qdrant retrieval

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Load env - extract vars individually to avoid zsh parse issues
if [ -f "$PROJECT_DIR/.env" ]; then
    CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
    CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
    CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2 | tr -d '"')
fi

CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_WEB_URL="https://cortex.aienablement.academy"  # For cross-reference links

# PARA Notebook mapping (sh-compatible function)
get_notebook_id() {
    case "$1" in
        Projects) echo "20251103053911-8ex6uns" ;;
        Areas) echo "20251201183343-543piyt" ;;
        Resources) echo "20251201183343-ujsixib" ;;
        Archives) echo "20251201183343-xf2snc8" ;;
        Knowledge-Base) echo "20251103053840-moamndp" ;;
        Agents) echo "20251103053916-bq6qbgu" ;;
        *) echo "" ;;
    esac
}

# Document type defaults
get_default_type() {
    case "$1" in
        Projects) echo "project" ;;
        Areas) echo "area" ;;
        Resources) echo "reference" ;;
        Archives) echo "archive" ;;
        Knowledge-Base) echo "kb" ;;
        Agents) echo "agent" ;;
        *) echo "reference" ;;
    esac
}

# Parse arguments
TITLE=""
CONTENT=""
NOTEBOOK="Resources"
TAGS=""
CUSTOM_PATH=""
DOC_TYPE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --title) TITLE="$2"; shift 2 ;;
        --content) CONTENT="$2"; shift 2 ;;
        --notebook) NOTEBOOK="$2"; shift 2 ;;
        --tags) TAGS="$2"; shift 2 ;;
        --path) CUSTOM_PATH="$2"; shift 2 ;;
        --type) DOC_TYPE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Validate
if [ -z "$TITLE" ]; then
    echo "Error: --title is required"
    exit 1
fi

if [ -z "$CONTENT" ]; then
    echo "Error: --content is required"
    exit 1
fi

NOTEBOOK_ID=$(get_notebook_id "$NOTEBOOK")
if [ -z "$NOTEBOOK_ID" ]; then
    echo "Error: Invalid notebook '$NOTEBOOK'. Valid: Projects, Areas, Resources, Archives, Agents, Knowledge-Base"
    exit 1
fi

# Set document type (use --type if provided, otherwise use notebook default)
if [ -z "$DOC_TYPE" ]; then
    DOC_TYPE=$(get_default_type "$NOTEBOOK")
fi

# Generate content hash for dedup
CONTENT_HASH=$(echo -n "$TITLE$CONTENT" | md5 | cut -c1-16)

# Sanitize title for path
PATH_TITLE=$(echo "$TITLE" | tr ' ' '-' | tr -cd '[:alnum:]-' | head -c 50)
DOC_PATH="${CUSTOM_PATH:-/$PATH_TITLE}"

# Check if document with same hpath exists (upsert logic - hpath-based detection)
# hpath = human-readable path (e.g., /Test-Document), path = internal (e.g., /20251212-xxx.sy)
EXISTING_DOC=$(curl -s -X POST "${CORTEX_URL}/api/query/sql" \
    -H "Authorization: Token ${CORTEX_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "{\"stmt\": \"SELECT id FROM blocks WHERE type='d' AND box='${NOTEBOOK_ID}' AND hpath='${DOC_PATH}' LIMIT 1\"}" 2>/dev/null)

EXISTING_ID=$(echo "$EXISTING_DOC" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',[{}])[0].get('id',''))" 2>/dev/null || echo "")

# Build markdown with YAML frontmatter and metadata
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
CREATED_DATE=$(date -u +%Y-%m-%d)

# Build YAML frontmatter
YAML_FRONTMATTER="---
title: $TITLE
type: $DOC_TYPE
created: $CREATED_DATE"

if [ -n "$TAGS" ]; then
    # Convert comma-separated tags to YAML array
    TAG_ARRAY=$(echo "$TAGS" | tr ',' '\n' | awk '{print "  - " $1}')
    YAML_FRONTMATTER+="
tags:
$TAG_ARRAY"
fi

# Cortex URL will be added after document creation/update
YAML_FRONTMATTER+="
cortex_url: TO_BE_UPDATED
---
"

# Build full markdown
MARKDOWN="${YAML_FRONTMATTER}
# $TITLE

"

if [ -n "$TAGS" ]; then
    for tag in $(echo "$TAGS" | tr ',' ' '); do
        MARKDOWN+="#$tag "
    done
    MARKDOWN+="

"
fi

MARKDOWN+="$CONTENT

---
*Auto-synced: $NOW | Hash: $CONTENT_HASH*"

if [ -n "$EXISTING_ID" ]; then
    # UPDATE existing document
    echo "Updating existing document: $EXISTING_ID"

    # Get existing content to check if update needed
    EXISTING_CONTENT=$(curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"id\": \"${EXISTING_ID}\"}" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('content',''))" 2>/dev/null || echo "")

    # Check if content hash is same (no update needed)
    EXISTING_HASH=$(echo "$EXISTING_CONTENT" | grep -o 'Hash: [a-f0-9]*' | cut -d' ' -f2 || echo "")
    if [ "$EXISTING_HASH" = "$CONTENT_HASH" ]; then
        echo "Content unchanged (hash: $CONTENT_HASH), skipping update"
        exit 0
    fi

    # Update Cortex URL in frontmatter before updating
    CORTEX_DOC_URL="${CORTEX_WEB_URL}/?id=${EXISTING_ID}"
    FINAL_MARKDOWN=$(echo "$MARKDOWN" | sed "s|cortex_url: TO_BE_UPDATED|cortex_url: ${CORTEX_DOC_URL}|")

    # Update document content using updateBlock API
    ESCAPED_MARKDOWN=$(echo "$FINAL_MARKDOWN" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

    RESULT=$(curl -s -X POST "${CORTEX_URL}/api/block/updateBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"id\": \"${EXISTING_ID}\",
            \"dataType\": \"markdown\",
            \"data\": $ESCAPED_MARKDOWN
        }" 2>/dev/null)

    echo "Updated: $TITLE (id: $EXISTING_ID, url: $CORTEX_DOC_URL)"
else
    # CREATE new document
    echo "Creating new document: $TITLE"

    # Create with temporary URL (will update after getting ID)
    ESCAPED_MARKDOWN=$(echo "$MARKDOWN" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

    RESULT=$(curl -s -X POST "${CORTEX_URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"notebook\": \"${NOTEBOOK_ID}\",
            \"path\": \"${DOC_PATH}\",
            \"markdown\": $ESCAPED_MARKDOWN
        }" 2>/dev/null)

    NEW_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',''))" 2>/dev/null || echo "")

    if [ -n "$NEW_ID" ]; then
        # Update document with correct Cortex URL
        CORTEX_DOC_URL="${CORTEX_WEB_URL}/?id=${NEW_ID}"
        FINAL_MARKDOWN=$(echo "$MARKDOWN" | sed "s|cortex_url: TO_BE_UPDATED|cortex_url: ${CORTEX_DOC_URL}|")
        ESCAPED_FINAL=$(echo "$FINAL_MARKDOWN" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")

        curl -s -X POST "${CORTEX_URL}/api/block/updateBlock" \
            -H "Authorization: Token ${CORTEX_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"${NEW_ID}\",
                \"dataType\": \"markdown\",
                \"data\": $ESCAPED_FINAL
            }" >/dev/null 2>&1

        echo "Created: $TITLE (id: $NEW_ID, url: $CORTEX_DOC_URL)"

        # Set custom attributes including doc type
        curl -s -X POST "${CORTEX_URL}/api/attr/setBlockAttrs" \
            -H "Authorization: Token ${CORTEX_TOKEN}" \
            -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
            -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
            -H "Content-Type: application/json" \
            -d "{
                \"id\": \"${NEW_ID}\",
                \"attrs\": {
                    \"custom-category\": \"$(echo "$NOTEBOOK" | tr '[:upper:]' '[:lower:]' | tr '-' '_')\",
                    \"custom-doc-type\": \"${DOC_TYPE}\",
                    \"custom-content-hash\": \"${CONTENT_HASH}\",
                    \"custom-auto-synced\": \"true\"
                }
            }" >/dev/null 2>&1
    else
        echo "Error creating document"
        echo "$RESULT"
        exit 1
    fi
fi

echo "Done"
