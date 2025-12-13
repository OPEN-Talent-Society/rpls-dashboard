#!/bin/bash
# Index business documents (PDFs, DOCX, XLSX, MD, TXT) to Qdrant + Supabase catalog
# Features:
#   - AI-generated tags and descriptions
#   - Chunk context breadcrumbs (prev/next)
#   - Supabase document catalog (metadata without full content)
#
# Usage: index-documents-to-qdrant.sh [directory] [--dry-run]

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

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
COLLECTION_NAME="agent_memory"

# Supabase config (for document catalog)
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# Gemini config (for embeddings + AI tagging)
GEMINI_API_KEY="${GOOGLE_GEMINI_API_KEY:-}"
EMBEDDING_MODEL="gemini-embedding-001"
GEMINI_MODEL="gemini-1.5-flash"  # Fast model for tagging

# Chunking config
MAX_CHUNK_SIZE=1500
CHUNK_OVERLAP=200
MAX_FILE_SIZE=10485760  # 10MB

# Directory to scan
SCAN_DIR="${1:-$PROJECT_DIR}"
DRY_RUN="${2:-}"

# Skip directories
SKIP_DIRS=(
    "node_modules" ".next" ".svelte-kit" "dist" "build" ".git"
    ".cache" "__pycache__" "coverage" ".turbo" ".vercel"
    "venv" ".venv" ".tox" "vendor"
)

# Supported document types
DOC_EXTENSIONS=("pdf" "docx" "xlsx" "xls" "md" "txt" "csv" "json" "vtt" "srt")

echo -e "${BLUE}📄 Smart Document Indexer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📂 Scanning: $SCAN_DIR${NC}"
echo -e "${YELLOW}🔌 Qdrant: $QDRANT_URL/collections/$COLLECTION_NAME${NC}"
echo -e "${YELLOW}📋 Supabase: $SUPABASE_URL (document_catalog)${NC}"
echo -e "${YELLOW}🤖 AI Tagging: Gemini $GEMINI_MODEL${NC}"

if [ -n "$DRY_RUN" ]; then
    echo -e "${YELLOW}🔍 DRY RUN MODE - No actual indexing${NC}"
fi

# Check Qdrant connection
echo -e "${YELLOW}🔌 Checking Qdrant connection...${NC}"
QDRANT_STATUS=$(curl -s --max-time 5 "${QDRANT_URL}/collections/${COLLECTION_NAME}" \
    -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null | jq -r '.status // "error"')

if [ "$QDRANT_STATUS" != "ok" ]; then
    echo -e "${RED}❌ Cannot connect to Qdrant${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Connected to Qdrant${NC}"

# Check Supabase catalog tables (graceful degradation)
SUPABASE_CATALOG_AVAILABLE=false
if [ -n "$SUPABASE_KEY" ]; then
    echo -e "${YELLOW}🔌 Checking Supabase document catalog...${NC}"
    CATALOG_CHECK=$(curl -s --max-time 5 -X GET "${SUPABASE_URL}/rest/v1/document_catalog?limit=1" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" 2>/dev/null)

    if echo "$CATALOG_CHECK" | jq -e 'type == "array"' > /dev/null 2>&1; then
        SUPABASE_CATALOG_AVAILABLE=true
        echo -e "${GREEN}✅ Supabase document catalog available${NC}"
    else
        echo -e "${YELLOW}⚠️  Supabase document catalog not available (tables not created yet)${NC}"
        echo -e "${YELLOW}   → Run migration: .claude/skills/memory-sync/migrations/001_document_catalog.sql${NC}"
        echo -e "${YELLOW}   → Indexing will continue with Qdrant only${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Supabase key not configured - Qdrant-only mode${NC}"
fi

# Python helper for document extraction
EXTRACTOR_SCRIPT=$(cat << 'PYTHON_EOF'
import sys
import json

def extract_pdf(filepath):
    """Extract text from PDF using pdfplumber"""
    try:
        import pdfplumber
        text_parts = []
        with pdfplumber.open(filepath) as pdf:
            for i, page in enumerate(pdf.pages):
                page_text = page.extract_text() or ""
                if page_text.strip():
                    text_parts.append(f"[Page {i+1}]\n{page_text}")
        return "\n\n".join(text_parts)
    except Exception as e:
        return f"ERROR: {str(e)}"

def extract_docx(filepath):
    """Extract text from DOCX"""
    try:
        from docx import Document
        doc = Document(filepath)
        paragraphs = [p.text for p in doc.paragraphs if p.text.strip()]
        return "\n\n".join(paragraphs)
    except Exception as e:
        return f"ERROR: {str(e)}"

def extract_xlsx(filepath):
    """Extract text from Excel spreadsheet"""
    try:
        import pandas as pd
        xl = pd.ExcelFile(filepath)
        text_parts = []
        for sheet_name in xl.sheet_names:
            df = pd.read_excel(xl, sheet_name=sheet_name)
            text_parts.append(f"[Sheet: {sheet_name}]")
            text_parts.append(df.to_markdown(index=False))
        return "\n\n".join(text_parts)
    except Exception as e:
        return f"ERROR: {str(e)}"

def extract_csv(filepath):
    """Extract text from CSV"""
    try:
        import pandas as pd
        df = pd.read_csv(filepath)
        return df.to_markdown(index=False)
    except Exception as e:
        return f"ERROR: {str(e)}"

def extract_vtt(filepath):
    """Extract text from VTT/SRT subtitles"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        import re
        content = re.sub(r'^WEBVTT.*?\n\n', '', content, flags=re.DOTALL)
        content = re.sub(r'\d{2}:\d{2}:\d{2}[.,]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[.,]\d{3}', '', content)
        content = re.sub(r'^\d+$', '', content, flags=re.MULTILINE)
        content = re.sub(r'\n{3,}', '\n\n', content)
        return content.strip()
    except Exception as e:
        return f"ERROR: {str(e)}"

def main():
    if len(sys.argv) < 3:
        print("Usage: python extractor.py <type> <filepath>")
        sys.exit(1)

    doc_type = sys.argv[1].lower()
    filepath = sys.argv[2]

    extractors = {
        'pdf': extract_pdf,
        'docx': extract_docx,
        'xlsx': extract_xlsx,
        'xls': extract_xlsx,
        'csv': extract_csv,
        'vtt': extract_vtt,
        'srt': extract_vtt,
    }

    if doc_type in extractors:
        result = extractors[doc_type](filepath)
    else:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            result = f.read()

    print(result)

if __name__ == "__main__":
    main()
PYTHON_EOF
)

EXTRACTOR_PATH="/tmp/doc_extractor.py"
echo "$EXTRACTOR_SCRIPT" > "$EXTRACTOR_PATH"

# Function to check if directory should be skipped
should_skip_dir() {
    local dir="$1"
    for skip in "${SKIP_DIRS[@]}"; do
        if [[ "$dir" == *"/$skip/"* ]] || [[ "$dir" == *"/$skip" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to generate deterministic point ID
generate_point_id() {
    local filepath="$1"
    local chunk_num="$2"
    echo -n "${filepath}:chunk${chunk_num}" | md5 | cut -c1-16
}

# Function to chunk text and return array with context
chunk_text_with_context() {
    local text="$1"
    local max_size="$MAX_CHUNK_SIZE"
    local overlap="$CHUNK_OVERLAP"

    python3 << CHUNK_EOF
import sys
import json

text = '''$text'''
max_size = $max_size
overlap = $overlap

def summarize_chunk(chunk_text, max_len=100):
    """Create brief summary of chunk for breadcrumbs"""
    summary = chunk_text[:max_len].replace('\n', ' ').strip()
    if len(chunk_text) > max_len:
        summary += "..."
    return summary

chunks = []
start = 0
positions = []

while start < len(text):
    end = min(start + max_size, len(text))

    if end < len(text):
        for sep in ['. ', '.\n', '\n\n', '\n', ' ']:
            last_sep = text[start:end].rfind(sep)
            if last_sep > max_size // 2:
                end = start + last_sep + len(sep)
                break

    chunk = text[start:end].strip()
    if chunk:
        chunks.append(chunk)
        positions.append((start, end))

    start = end - overlap
    if start >= len(text) - overlap:
        break

# Build result with context
result = []
for i, chunk in enumerate(chunks):
    entry = {
        "text": chunk,
        "index": i,
        "total": len(chunks),
        "prev_summary": summarize_chunk(chunks[i-1]) if i > 0 else None,
        "next_summary": summarize_chunk(chunks[i+1]) if i < len(chunks)-1 else None
    }
    result.append(entry)

print(json.dumps(result))
CHUNK_EOF
}

# Function to generate AI tags and description
generate_ai_metadata() {
    local text="$1"
    local filename="$2"
    local filetype="$3"

    # Take first 3000 chars for analysis
    local sample="${text:0:3000}"
    local escaped_sample=$(echo -n "$sample" | jq -Rs '.')

    local prompt="Analyze this document excerpt and provide:
1. A 1-2 sentence description of what this document is about
2. 3-7 relevant tags (lowercase, hyphenated)
3. The document type category (e.g., technical, business, legal, meeting-notes, research, training, etc.)

Document filename: $filename
File type: $filetype

Content excerpt:
$sample

Respond in this exact JSON format:
{
  \"description\": \"Brief description here\",
  \"tags\": [\"tag1\", \"tag2\", \"tag3\"],
  \"category\": \"category-name\"
}"

    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"contents\": [{\"parts\":[{\"text\": $(echo -n "$prompt" | jq -Rs '.')}]}],
            \"generationConfig\": {
                \"temperature\": 0.2,
                \"maxOutputTokens\": 256
            }
        }" 2>/dev/null)

    # Extract JSON from response
    local ai_text=$(echo "$response" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)

    if [ -n "$ai_text" ]; then
        # Try to extract JSON from the response
        echo "$ai_text" | grep -o '{[^}]*}' | head -1
    else
        # Fallback
        echo '{"description":"Document content","tags":["untagged"],"category":"general"}'
    fi
}

# Function to get embedding
get_embedding() {
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

    echo "$response" | jq -r '.embedding.values // empty' 2>/dev/null
}

# Function to upsert to Qdrant
upsert_to_qdrant() {
    local point_id="$1"
    local vector="$2"
    local payload="$3"

    local point_data=$(jq -n \
        --arg id "$point_id" \
        --argjson vector "$vector" \
        --argjson payload "$payload" \
        '{
            points: [{
                id: $id,
                vector: $vector,
                payload: $payload
            }]
        }')

    curl -s --max-time 30 -X PUT "${QDRANT_URL}/collections/${COLLECTION_NAME}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "$point_data" 2>/dev/null
}

# Function to upsert document catalog to Supabase
upsert_document_catalog() {
    # Skip if Supabase catalog not available
    if [ "$SUPABASE_CATALOG_AVAILABLE" != "true" ]; then
        return 0
    fi

    local doc_id="$1"
    local filepath="$2"
    local filename="$3"
    local filetype="$4"
    local description="$5"
    local tags="$6"
    local category="$7"
    local total_chunks="$8"
    local word_count="$9"

    local catalog_entry=$(jq -n \
        --arg doc_id "$doc_id" \
        --arg filepath "$filepath" \
        --arg filename "$filename" \
        --arg filetype "$filetype" \
        --arg description "$description" \
        --argjson tags "$tags" \
        --arg category "$category" \
        --argjson total_chunks "$total_chunks" \
        --argjson word_count "$word_count" \
        --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            doc_id: $doc_id,
            filepath: $filepath,
            filename: $filename,
            filetype: $filetype,
            description: $description,
            tags: $tags,
            category: $category,
            total_chunks: $total_chunks,
            word_count: $word_count,
            indexed_at: $indexed_at
        }')

    curl -s --max-time 30 -X POST "${SUPABASE_URL}/rest/v1/document_catalog" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "$catalog_entry" 2>/dev/null
}

# Function to upsert chunk index to Supabase
upsert_chunk_index() {
    # Skip if Supabase catalog not available
    if [ "$SUPABASE_CATALOG_AVAILABLE" != "true" ]; then
        return 0
    fi

    local chunk_id="$1"
    local doc_id="$2"
    local chunk_index="$3"
    local total_chunks="$4"
    local prev_summary="$5"
    local next_summary="$6"
    local first_100_chars="$7"

    local chunk_entry=$(jq -n \
        --arg chunk_id "$chunk_id" \
        --arg doc_id "$doc_id" \
        --argjson chunk_index "$chunk_index" \
        --argjson total_chunks "$total_chunks" \
        --arg prev_summary "$prev_summary" \
        --arg next_summary "$next_summary" \
        --arg preview "$first_100_chars" \
        '{
            chunk_id: $chunk_id,
            doc_id: $doc_id,
            chunk_index: $chunk_index,
            total_chunks: $total_chunks,
            prev_chunk_summary: $prev_summary,
            next_chunk_summary: $next_summary,
            preview: $preview
        }')

    curl -s --max-time 30 -X POST "${SUPABASE_URL}/rest/v1/document_chunks" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "$chunk_entry" 2>/dev/null
}

# Stats
TOTAL_FILES=0
INDEXED_FILES=0
SKIPPED_FILES=0
TOTAL_CHUNKS=0
ERRORS=0

echo -e "\n${BLUE}📂 Scanning for documents...${NC}"

for ext in "${DOC_EXTENSIONS[@]}"; do
    while IFS= read -r -d '' filepath; do
        if should_skip_dir "$filepath"; then
            continue
        fi

        filesize=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath" 2>/dev/null || echo "0")
        if [ "$filesize" -gt "$MAX_FILE_SIZE" ]; then
            echo -e "${YELLOW}  ⚠️  Skipped (too large: ${filesize} bytes): $(basename "$filepath")${NC}"
            ((SKIPPED_FILES++))
            continue
        fi

        ((TOTAL_FILES++))

        rel_path="${filepath#$SCAN_DIR/}"
        filename=$(basename "$filepath")
        echo -e "${BLUE}📝 Processing: $rel_path${NC}"

        if [ -n "$DRY_RUN" ]; then
            echo -e "${YELLOW}   [DRY RUN] Would extract, tag, and index${NC}"
            continue
        fi

        # Extract text
        file_ext="${filepath##*.}"
        file_ext_lower=$(echo "$file_ext" | tr '[:upper:]' '[:lower:]')
        extracted_text=$(python3 "$EXTRACTOR_PATH" "$file_ext_lower" "$filepath" 2>/dev/null)

        if [[ "$extracted_text" == ERROR:* ]]; then
            echo -e "${RED}   ❌ Extraction failed: ${extracted_text#ERROR: }${NC}"
            ((ERRORS++))
            continue
        fi

        if [ -z "$extracted_text" ] || [ ${#extracted_text} -lt 50 ]; then
            echo -e "${YELLOW}   ⚠️  Skipped (empty or too short)${NC}"
            ((SKIPPED_FILES++))
            continue
        fi

        # Generate AI metadata (tags, description, category)
        echo -e "${YELLOW}   🤖 Generating AI tags and description...${NC}"
        ai_metadata=$(generate_ai_metadata "$extracted_text" "$filename" "$file_ext_lower")

        description=$(echo "$ai_metadata" | jq -r '.description // "Document content"' 2>/dev/null || echo "Document content")
        tags=$(echo "$ai_metadata" | jq -c '.tags // ["untagged"]' 2>/dev/null || echo '["untagged"]')
        category=$(echo "$ai_metadata" | jq -r '.category // "general"' 2>/dev/null || echo "general")

        echo -e "${GREEN}   📋 Category: $category${NC}"
        echo -e "${GREEN}   🏷️  Tags: $tags${NC}"

        # Generate document ID
        doc_id=$(echo -n "$filepath" | md5 | cut -c1-16)
        word_count=$(echo "$extracted_text" | wc -w | tr -d ' ')

        # Chunk with context
        chunks_with_context=$(chunk_text_with_context "$extracted_text" 2>/dev/null)
        if [ -z "$chunks_with_context" ] || [ "$chunks_with_context" = "[]" ]; then
            echo -e "${YELLOW}   ⚠️  No chunks generated${NC}"
            ((SKIPPED_FILES++))
            continue
        fi

        num_chunks=$(echo "$chunks_with_context" | jq 'length')
        echo -e "${YELLOW}   📄 Chunked into $num_chunks parts (with context breadcrumbs)${NC}"

        # Upsert document to Supabase catalog
        upsert_document_catalog "$doc_id" "$rel_path" "$filename" "$file_ext_lower" "$description" "$tags" "$category" "$num_chunks" "$word_count"

        # Process each chunk
        for ((i=0; i<num_chunks; i++)); do
            chunk_data=$(echo "$chunks_with_context" | jq ".[$i]")
            chunk_text=$(echo "$chunk_data" | jq -r '.text')
            prev_summary=$(echo "$chunk_data" | jq -r '.prev_summary // ""')
            next_summary=$(echo "$chunk_data" | jq -r '.next_summary // ""')
            first_100="${chunk_text:0:100}"

            # Generate embedding
            embedding=$(get_embedding "$chunk_text")

            if [ -z "$embedding" ] || [ "$embedding" = "null" ]; then
                echo -e "${RED}   ❌ Embedding failed for chunk $((i+1))${NC}"
                ((ERRORS++))
                continue
            fi

            # Generate point ID
            point_id=$(generate_point_id "$filepath" "$i")

            # Create rich payload with context
            payload=$(jq -n \
                --arg doc_id "$doc_id" \
                --arg filepath "$rel_path" \
                --arg filename "$filename" \
                --arg filetype "$file_ext_lower" \
                --arg text "$chunk_text" \
                --argjson chunk_index "$i" \
                --argjson total_chunks "$num_chunks" \
                --arg prev_summary "$prev_summary" \
                --arg next_summary "$next_summary" \
                --arg description "$description" \
                --argjson tags "$tags" \
                --arg doc_category "$category" \
                --arg indexed_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                --arg source "document_indexer" \
                --arg category "business_document" \
                '{
                    doc_id: $doc_id,
                    filepath: $filepath,
                    filename: $filename,
                    filetype: $filetype,
                    text: $text,
                    chunk_index: $chunk_index,
                    total_chunks: $total_chunks,
                    prev_chunk_summary: $prev_summary,
                    next_chunk_summary: $next_summary,
                    doc_description: $description,
                    tags: $tags,
                    doc_category: $doc_category,
                    indexed_at: $indexed_at,
                    source: $source,
                    category: $category
                }')

            # Upsert to Qdrant
            result=$(upsert_to_qdrant "$point_id" "$embedding" "$payload")

            if echo "$result" | jq -e '.status == "ok"' > /dev/null 2>&1; then
                echo -e "${GREEN}   ✅ Indexed chunk $((i+1))/$num_chunks${NC}"
                ((TOTAL_CHUNKS++))

                # Upsert chunk index to Supabase (lightweight metadata)
                upsert_chunk_index "$point_id" "$doc_id" "$i" "$num_chunks" "$prev_summary" "$next_summary" "$first_100"
            else
                echo -e "${RED}   ❌ Failed to index chunk $((i+1))${NC}"
                ((ERRORS++))
            fi

            sleep 0.3  # Rate limit
        done

        ((INDEXED_FILES++))

    done < <(find "$SCAN_DIR" -name "*.$ext" -type f -print0 2>/dev/null)
done

# Summary
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Smart Document Indexing Complete${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "   Total files found: $TOTAL_FILES"
echo -e "   Files indexed: $INDEXED_FILES"
echo -e "   Files skipped: $SKIPPED_FILES"
echo -e "   Chunks indexed: $TOTAL_CHUNKS"
echo -e "   🔍 Qdrant: ${QDRANT_URL}/collections/${COLLECTION_NAME}"
if [ "$SUPABASE_CATALOG_AVAILABLE" = "true" ]; then
    echo -e "   📋 Document catalog: ${SUPABASE_URL}/rest/v1/document_catalog"
    echo -e "   📝 Chunk index: ${SUPABASE_URL}/rest/v1/document_chunks"
else
    echo -e "   ${YELLOW}⚠️  Supabase catalog: Not available (run migration to enable)${NC}"
fi
if [ $ERRORS -gt 0 ]; then
    echo -e "   ${RED}Errors: $ERRORS${NC}"
fi

rm -f "$EXTRACTOR_PATH"
