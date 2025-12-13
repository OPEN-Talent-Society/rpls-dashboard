#!/bin/bash
# Index contacts, leads, and profiles to Qdrant
# Features:
#   - Multi-source profile extraction (LinkedIn, CRM, manual, forms)
#   - Lead/prospect data handling
#   - Company data association
#   - Form submission data
#   - CRM export processing (CSV, JSON)
#   - Incremental indexing via manifest
#
# Usage: index-contacts-to-qdrant.sh [directory] [--force] [--dry-run]
#
# Supported file types: MD, CSV, JSON, PDF, XLSX, TXT
#
# Supported patterns:
#   - LinkedIn exports (*linkedin*.*)
#   - Profile data (*profile*.*, *cv*.*, *resume*.*)
#   - Lead files (*lead*.*, *prospect*.*)
#   - Company profiles (*company*.*, *organization*.*)
#   - Form responses (*form*.*, *response*.*, *submission*.*)
#   - CRM exports (*crm*.*, *hubspot*.*, *salesforce*.*)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Load environment
source "$PROJECT_DIR/.env" 2>/dev/null || true
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
COLLECTION_NAME="contacts"

# Gemini config
GEMINI_API_KEY="${GOOGLE_GEMINI_API_KEY:-$GEMINI_API_KEY}"
EMBEDDING_MODEL="gemini-embedding-001"
GEMINI_MODEL="gemini-1.5-flash"

# Chunking config - moderate for contact data
MAX_CHUNK_SIZE=2000
CHUNK_OVERLAP=300
MAX_FILE_SIZE=2097152  # 2MB

# Manifest for incremental indexing
MANIFEST_DIR="$PROJECT_DIR/.claude/skills/memory-sync/manifests"
MANIFEST_FILE="$MANIFEST_DIR/contacts-index-manifest.json"
mkdir -p "$MANIFEST_DIR"

# Parse arguments
SCAN_DIR="${PROJECT_DIR}"
FORCE_REINDEX=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force) FORCE_REINDEX=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) SCAN_DIR="$1"; shift ;;
    esac
done

# Initialize manifest if not exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo '{}' > "$MANIFEST_FILE"
fi
MANIFEST=$(cat "$MANIFEST_FILE")

# Counters
TOTAL_FILES=0
INDEXED_FILES=0
SKIPPED_FILES=0
TOTAL_CHUNKS=0

echo -e "${BLUE}Contact & Lead Indexer${NC}"
echo -e "${BLUE}${NC}"
echo -e "${YELLOW}Scanning: $SCAN_DIR${NC}"
echo -e "${YELLOW}Qdrant: $QDRANT_URL/collections/$COLLECTION_NAME${NC}"
if [ "$FORCE_REINDEX" = true ]; then
    echo -e "${YELLOW}Force mode: Re-indexing all files${NC}"
fi
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No actual indexing${NC}"
fi

# Contact/Lead file patterns - Multi-source support
# Supports: MD, CSV, JSON, PDF, XLSX, TXT
CONTACT_PATTERNS=(
    # LinkedIn exports (primary)
    "*linkedin*.*"
    "*LINKEDIN*.*"
    # Generic profiles (any source: CRM, manual, scraped)
    "*profile*.*"
    "*PROFILE*.*"
    "*cv*.*"
    "*CV*.*"
    "*resume*.*"
    "*RESUME*.*"
    # Lead/prospect data
    "*lead*.*"
    "*LEAD*.*"
    "*prospect*.*"
    "*PROSPECT*.*"
    # Company profiles
    "*company*.*"
    "*COMPANY*.*"
    "*organization*.*"
    # Form submissions
    "*form*.*"
    "*submission*.*"
    "*response*.*"
    # Generic contacts
    "*contact*.*"
    "*CONTACT*.*"
    # CRM exports
    "*crm*.*"
    "*CRM*.*"
    "*hubspot*.*"
    "*salesforce*.*"
    "*pipedrive*.*"
    # Talent data (for The Talent Foundation)
    "*candidate*.*"
    "*applicant*.*"
    "*talent*.*"
)

# Supported file extensions
SUPPORTED_EXTENSIONS="md|csv|json|pdf|xlsx|xls|txt|html|docx"

# Known contact/CRM directories
CONTACT_DIRS=(
    "contacts"
    "leads"
    "prospects"
    "crm"
    "profiles"
    "companies"
)

# Directories to skip
SKIP_DIRS=(
    "node_modules" ".next" ".git" "dist" "build" ".cache"
    "coverage" ".turbo" ".vercel" "__pycache__" "venv"
    "archives" "backups" "claude-backups" "vendor"
    ".github" "templates"
)

# Content hash for incremental indexing
compute_content_hash() {
    local file="$1"
    cat "$file" 2>/dev/null | md5 2>/dev/null || cat "$file" 2>/dev/null | md5sum | cut -d' ' -f1
}

# Check if file needs indexing
needs_indexing() {
    local file_path="$1"
    local current_hash="$2"

    if [ "$FORCE_REINDEX" = true ]; then
        return 0
    fi

    local prev_hash=$(echo "$MANIFEST" | jq -r --arg fp "$file_path" '.[$fp].hash // ""')
    if [ "$prev_hash" = "$current_hash" ]; then
        return 1
    fi
    return 0
}

# Update manifest
update_manifest() {
    local file_path="$1"
    local hash="$2"
    local chunks="$3"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    MANIFEST=$(echo "$MANIFEST" | jq --arg fp "$file_path" --arg h "$hash" --argjson c "$chunks" --arg ts "$timestamp" \
        '.[$fp] = {hash: $h, chunks: $c, indexed_at: $ts}')
}

# Generate embedding
generate_embedding() {
    local text="$1"
    local escaped_text=$(echo -n "$text" | jq -Rs '.')

    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"models/${EMBEDDING_MODEL}\",
            \"content\": {\"parts\":[{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" 2>/dev/null)

    echo "$response" | jq -c '.embedding.values'
}

# Extract contact metadata using AI
extract_contact_metadata() {
    local text="$1"
    local filename="$2"

    local sample="${text:0:4000}"

    local prompt="Extract contact/profile information from this document:
1. Person name (if individual)
2. Company/organization name
3. Job title/role
4. Contact type (linkedin_profile, lead, prospect, company, form_response, other)
5. Email addresses mentioned
6. Phone numbers mentioned
7. Location/region
8. Industry
9. Key interests or notes

Document: $filename
Content:
$sample

Respond in JSON format:
{
  \"person_name\": \"...\",
  \"company_name\": \"...\",
  \"job_title\": \"...\",
  \"contact_type\": \"linkedin_profile|lead|prospect|company|form_response|other\",
  \"emails\": [\"email@example.com\"],
  \"phones\": [\"+1234567890\"],
  \"location\": \"...\",
  \"industry\": \"...\",
  \"notes\": \"...\"
}"

    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"contents\": [{\"parts\":[{\"text\": $(echo -n "$prompt" | jq -Rs '.')}]}],
            \"generationConfig\": {\"temperature\": 0.2, \"maxOutputTokens\": 512}
        }" 2>/dev/null)

    local ai_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

    if [ -n "$ai_text" ]; then
        echo "$ai_text" | grep -o '{[^}]*}' | head -1
    else
        echo '{"person_name":"","company_name":"unknown","job_title":"","contact_type":"other","emails":[],"phones":[],"location":"","industry":"","notes":""}'
    fi
}

# Create chunk summary for breadcrumbs
create_chunk_summary() {
    local chunk="$1"
    echo "$chunk" | head -c 100 | tr '\n' ' ' | sed 's/  */ /g; s/^ *//; s/ *$//'
}

# Index a single file
index_file() {
    local file="$1"
    local rel_path="${file#$PROJECT_DIR/}"

    TOTAL_FILES=$((TOTAL_FILES + 1))

    # Check file size
    local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        echo -e "${YELLOW}Skipping (too large): $rel_path${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return
    fi

    # Compute hash and check if needs indexing
    local content_hash=$(compute_content_hash "$file")
    if ! needs_indexing "$rel_path" "$content_hash"; then
        echo -e "${BLUE}Unchanged: $rel_path${NC}"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return
    fi

    echo -e "${GREEN}Processing: $rel_path${NC}"

    if [ "$DRY_RUN" = true ]; then
        return
    fi

    # Read content
    local content=$(cat "$file")
    local filename=$(basename "$file")

    # Extract contact metadata
    local contact_meta=$(extract_contact_metadata "$content" "$filename")
    local person_name=$(echo "$contact_meta" | jq -r '.person_name // ""')
    local company_name=$(echo "$contact_meta" | jq -r '.company_name // "unknown"')
    local job_title=$(echo "$contact_meta" | jq -r '.job_title // ""')
    local contact_type=$(echo "$contact_meta" | jq -r '.contact_type // "other"')
    local emails=$(echo "$contact_meta" | jq -c '.emails // []')
    local phones=$(echo "$contact_meta" | jq -c '.phones // []')
    local location=$(echo "$contact_meta" | jq -r '.location // ""')
    local industry=$(echo "$contact_meta" | jq -r '.industry // ""')
    local notes=$(echo "$contact_meta" | jq -r '.notes // ""')

    # Split into chunks
    local text_length=${#content}
    local num_chunks=1
    if [ $text_length -gt $MAX_CHUNK_SIZE ]; then
        num_chunks=$(( (text_length + MAX_CHUNK_SIZE - CHUNK_OVERLAP - 1) / (MAX_CHUNK_SIZE - CHUNK_OVERLAP) ))
    fi

    # Collect chunks first for breadcrumbs
    declare -a chunks
    local start=0
    while [ $start -lt $text_length ]; do
        local end=$((start + MAX_CHUNK_SIZE))
        [ $end -gt $text_length ] && end=$text_length
        chunks+=("${content:$start:$((end - start))}")
        start=$((end - CHUNK_OVERLAP))
        [ $end -eq $text_length ] && break
    done

    # Index each chunk with breadcrumbs
    local chunk_index=0
    local total=${#chunks[@]}
    for chunk in "${chunks[@]}"; do
        local prev_summary=""
        local next_summary=""

        [ $chunk_index -gt 0 ] && prev_summary=$(create_chunk_summary "${chunks[$((chunk_index - 1))]}")
        [ $chunk_index -lt $((total - 1)) ] && next_summary=$(create_chunk_summary "${chunks[$((chunk_index + 1))]}")

        # Position context
        local position_pct=$(( (chunk_index * 100) / total ))
        local position="beginning"
        [ $position_pct -gt 75 ] && position="end"
        [ $position_pct -gt 50 ] && [ $position_pct -le 75 ] && position="latter half"
        [ $position_pct -gt 25 ] && [ $position_pct -le 50 ] && position="middle"
        [ $position_pct -gt 0 ] && [ $position_pct -le 25 ] && position="early"

        # Generate embedding
        local embedding=$(generate_embedding "$chunk")
        if [ -z "$embedding" ] || [ "$embedding" == "null" ]; then
            echo -e "${RED}  Failed to generate embedding for chunk $chunk_index${NC}"
            continue
        fi

        # Generate point ID
        local point_id=$(echo -n "${rel_path}:chunk${chunk_index}" | md5 2>/dev/null | cut -c1-8 || echo -n "${rel_path}:chunk${chunk_index}" | md5sum | cut -c1-8)
        point_id=$(printf "%lu" "0x$point_id")

        # Create payload
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        local payload=$(jq -n \
            --argjson id "$point_id" \
            --arg type "contact" \
            --arg contact_type "$contact_type" \
            --arg person_name "$person_name" \
            --arg company_name "$company_name" \
            --arg job_title "$job_title" \
            --argjson emails "$emails" \
            --argjson phones "$phones" \
            --arg location "$location" \
            --arg industry "$industry" \
            --arg notes "$notes" \
            --arg file_path "$rel_path" \
            --arg filename "$filename" \
            --arg content "$chunk" \
            --argjson chunk_index "$chunk_index" \
            --argjson total_chunks "$total" \
            --arg prev_chunk_summary "$prev_summary" \
            --arg next_chunk_summary "$next_summary" \
            --arg position_in_file "$position" \
            --arg indexed_at "$timestamp" \
            --argjson vector "$embedding" \
            '{
              points: [{
                id: $id,
                vector: $vector,
                payload: {
                  type: $type,
                  contact_type: $contact_type,
                  person_name: $person_name,
                  company_name: $company_name,
                  job_title: $job_title,
                  emails: $emails,
                  phones: $phones,
                  location: $location,
                  industry: $industry,
                  notes: $notes,
                  file_path: $file_path,
                  filename: $filename,
                  content: $content,
                  chunk_index: $chunk_index,
                  total_chunks: $total_chunks,
                  prev_chunk_summary: $prev_chunk_summary,
                  next_chunk_summary: $next_chunk_summary,
                  position_in_file: $position_in_file,
                  indexed_at: $indexed_at
                }
              }]
            }')

        # Upload to Qdrant
        local response=$(curl -s -X PUT \
            "$QDRANT_URL/collections/$COLLECTION_NAME/points" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "$payload")

        if echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1; then
            TOTAL_CHUNKS=$((TOTAL_CHUNKS + 1))
            echo -e "${GREEN}  Chunk $((chunk_index + 1))/$total ($contact_type: $person_name)${NC}"
        else
            echo -e "${RED}  Failed chunk $chunk_index: $(echo "$response" | jq -r '.status.error // "unknown"')${NC}"
        fi

        chunk_index=$((chunk_index + 1))

        # Rate limit
        sleep 0.3
    done

    INDEXED_FILES=$((INDEXED_FILES + 1))
    update_manifest "$rel_path" "$content_hash" "$total"
}

# Check Qdrant connection
echo -e "${YELLOW}Checking Qdrant connection...${NC}"
COLLECTION_CHECK=$(curl -s "${QDRANT_URL}/collections/${COLLECTION_NAME}" -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null)
if ! echo "$COLLECTION_CHECK" | jq -e '.result' > /dev/null 2>&1; then
    echo -e "${YELLOW}Collection '$COLLECTION_NAME' not found, creating...${NC}"
    curl -s -X PUT "${QDRANT_URL}/collections/${COLLECTION_NAME}" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d '{"vectors": {"size": 768, "distance": "Cosine"}, "on_disk_payload": true}' > /dev/null
fi
echo -e "${GREEN}Connected to Qdrant${NC}"

# Find and index contact files
echo -e "${YELLOW}Scanning for contacts & leads...${NC}"

# Build find command with patterns
find_cmd="find \"$SCAN_DIR\" -type f \\("
first=true
for pattern in "${CONTACT_PATTERNS[@]}"; do
    if [ "$first" = true ]; then
        find_cmd="$find_cmd -name \"$pattern\""
        first=false
    else
        find_cmd="$find_cmd -o -name \"$pattern\""
    fi
done
find_cmd="$find_cmd \\)"

# Add skip directories
for skip in "${SKIP_DIRS[@]}"; do
    find_cmd="$find_cmd -not -path \"*/$skip/*\""
done

# Execute find and process files
eval "$find_cmd" 2>/dev/null | while read -r file; do
    index_file "$file"
done

# Also scan known contact directories for all markdown
for contact_dir in "${CONTACT_DIRS[@]}"; do
    if [ -d "$SCAN_DIR/$contact_dir" ]; then
        echo -e "${YELLOW}Scanning contacts directory: $contact_dir${NC}"
        find "$SCAN_DIR/$contact_dir" -type f -name "*.md" 2>/dev/null | while read -r file; do
            index_file "$file"
        done
    fi
done

# Save manifest
echo "$MANIFEST" > "$MANIFEST_FILE"

# Summary
echo ""
echo -e "${BLUE}${NC}"
echo -e "${GREEN}Contact & Lead Indexing Summary${NC}"
echo -e "  Total files found: $TOTAL_FILES"
echo -e "  Files indexed: $INDEXED_FILES"
echo -e "  Files skipped: $SKIPPED_FILES"
echo -e "  Total chunks: $TOTAL_CHUNKS"
echo -e "${BLUE}${NC}"

echo -e "${GREEN}Contact & lead indexing complete${NC}"
