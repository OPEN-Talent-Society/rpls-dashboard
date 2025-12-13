#!/bin/bash
# Cortex Pollution Cleanup Script
# Identifies and removes polluted documents from Cortex (SiYuan)
# Created: 2025-12-12
#
# Pollution patterns:
# 1. Documents with titles starting with "chunk-" or containing "chunk"
# 2. Documents with titles starting with "supabase" or "Supabase"
# 3. Documents with titles starting with "Episode-", "Pattern-", "Learning-" (verbatim dumps)
# 4. Documents with ".md" extension duplicates (same title exists without .md)
#
# Usage:
#   ./cleanup-cortex-pollution.sh --dry-run              # Report only, no deletion
#   ./cleanup-cortex-pollution.sh --limit 100            # Delete up to 100 docs
#   ./cleanup-cortex-pollution.sh --limit 0              # Delete all pollution (no limit)
#   ./cleanup-cortex-pollution.sh --type chunks          # Only clean specific type
#   ./cleanup-cortex-pollution.sh --help                 # Show help

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/cleanup"
mkdir -p "$LOG_DIR"

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/cortex-cleanup-${TIMESTAMP}.log"

# Initialize counters
TOTAL_POLLUTION=0
TOTAL_DELETED=0
CHUNKS_COUNT=0
SUPABASE_COUNT=0
VERBATIM_COUNT=0
MD_DUPES_COUNT=0
LEGITIMATE_COUNT=0

# Parse command line arguments
DRY_RUN=false
DELETE_LIMIT=100
CLEANUP_TYPE="all"  # all|chunks|supabase|verbatim|md-dupes

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --limit)
            DELETE_LIMIT="$2"
            shift 2
            ;;
        --type)
            CLEANUP_TYPE="$2"
            shift 2
            ;;
        --help)
            cat <<EOF
Cortex Pollution Cleanup Script

Usage:
  $0 [OPTIONS]

Options:
  --dry-run              Report pollution without deleting (default: false)
  --limit N              Maximum documents to delete (default: 100, 0=unlimited)
  --type TYPE            Only clean specific type: chunks|supabase|verbatim|md-dupes|all (default: all)
  --help                 Show this help message

Examples:
  # See what would be deleted
  $0 --dry-run

  # Delete up to 100 pollution docs
  $0 --limit 100

  # Delete only chunk pollution
  $0 --type chunks --limit 50

  # Delete all pollution (use with caution!)
  $0 --limit 0

Output:
  Log file: /tmp/cortex-cleanup-TIMESTAMP.log
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Load environment (extract vars individually to avoid zsh parse errors)
if [ -f "$PROJECT_DIR/.env" ]; then
    CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
    CORTEX_URL=$(grep "^CORTEX_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
    CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
    CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2)
fi

# Validate environment
[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }
[ -z "$CORTEX_URL" ] && CORTEX_URL="https://cortex.aienablement.academy"
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

# Initialize log
{
    echo "═══════════════════════════════════════════════════════════"
    echo "🧹 Cortex Pollution Cleanup - $(date)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration:"
    echo "  Cortex URL: $CORTEX_URL"
    echo "  Cleanup type: $CLEANUP_TYPE"
    echo "  Dry run: $DRY_RUN"
    echo "  Delete limit: $([ "$DELETE_LIMIT" -eq 0 ] && echo 'unlimited' || echo $DELETE_LIMIT)"
    echo ""
} | tee "$LOG_FILE"

# Helper function for Cortex API calls with CF Access auth
cortex_api() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-{}}"

    curl -s --max-time 30 -X "$method" \
        "$CORTEX_URL$endpoint" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "$data"
}

# Function to get all documents from all notebooks
get_all_documents() {
    echo "📚 Scanning all notebooks for documents..." >> "$LOG_FILE"
    echo "📚 Scanning all notebooks for documents..." >&2

    # Get list of notebooks
    local notebooks=$(cortex_api POST "/api/notebook/lsNotebooks" '{}')

    # Get documents from each notebook
    local all_docs='[]'

    echo "$notebooks" | python3 -c "
import sys, json
notebooks = json.load(sys.stdin)
for nb in notebooks.get('data', {}).get('notebooks', []):
    print(nb['id'])
" | while read nb_id; do
        # Use SQL query to get all documents with their content/title
        local docs=$(cortex_api POST "/api/query/sql" \
            "{\"stmt\": \"SELECT id, content, box, ial FROM blocks WHERE type='d' AND box='${nb_id}' LIMIT 10000\"}")

        # Accumulate documents
        echo "$docs"
    done
}

# Function to identify pollution patterns
identify_pollution() {
    local docs="$1"

    echo "" >> "$LOG_FILE"
    echo "🔍 Identifying pollution patterns..." >> "$LOG_FILE"
    echo "🔍 Identifying pollution patterns..." >&2

    # Process documents with Python for pattern matching
    echo "$docs" | python3 -c "
import sys, json, re

# Read all input (multiple JSON responses from notebooks)
all_results = []
for line in sys.stdin:
    try:
        data = json.loads(line)
        if 'data' in data and data['data']:
            all_results.extend(data['data'])
    except:
        continue

# Pattern definitions
patterns = {
    'chunks': [],
    'supabase': [],
    'verbatim': [],
    'md_dupes': [],
    'legitimate': []
}

# First pass: collect all titles and their IDs
title_to_docs = {}  # title -> list of (doc_id, is_md_extension)

for doc in all_results:
    doc_id = doc.get('id', '')
    content = doc.get('content', '')

    # Extract title (first line or first heading)
    title = ''
    lines = content.strip().split('\n')
    for line in lines:
        clean_line = line.strip().lstrip('#').strip()
        if clean_line:
            title = clean_line
            break

    if not title:
        title = doc_id[:8]  # Fallback to ID prefix

    # Track both the title and whether it has .md extension
    is_md = title.endswith('.md')
    base_title = title[:-3] if is_md else title

    if base_title not in title_to_docs:
        title_to_docs[base_title] = []
    title_to_docs[base_title].append({'id': doc_id, 'title': title, 'is_md': is_md})

# Second pass: identify pollution patterns
for doc in all_results:
    doc_id = doc.get('id', '')
    content = doc.get('content', '')

    # Extract title (same logic)
    title = ''
    lines = content.strip().split('\n')
    for line in lines:
        clean_line = line.strip().lstrip('#').strip()
        if clean_line:
            title = clean_line
            break

    if not title:
        title = doc_id[:8]

    # Check pollution patterns
    is_pollution = False

    # Pattern 1: Chunks
    if 'chunk-' in title.lower() or 'chunk' in title.lower():
        patterns['chunks'].append({'id': doc_id, 'title': title})
        is_pollution = True

    # Pattern 2: Supabase dumps
    elif title.lower().startswith('supabase') or 'supabase' in title.lower():
        patterns['supabase'].append({'id': doc_id, 'title': title})
        is_pollution = True

    # Pattern 3: Verbatim dumps (Episode-, Pattern-, Learning-)
    elif (title.startswith('Episode-') or
          title.startswith('Pattern-') or
          title.startswith('Learning-')):
        patterns['verbatim'].append({'id': doc_id, 'title': title})
        is_pollution = True

    # Pattern 4: .md duplicates
    # If this title ends with .md, check if base title exists without .md
    if not is_pollution and title.endswith('.md'):
        base_title = title[:-3]
        if base_title in title_to_docs:
            # Check if there's a non-.md version
            for other_doc in title_to_docs[base_title]:
                if not other_doc['is_md'] and other_doc['id'] != doc_id:
                    patterns['md_dupes'].append({
                        'id': doc_id,
                        'title': title,
                        'duplicate_of': other_doc['id']
                    })
                    is_pollution = True
                    break

    # Track legitimate content
    if not is_pollution:
        patterns['legitimate'].append({'id': doc_id, 'title': title})

# Output results as JSON
print(json.dumps(patterns, indent=2))
"
}

# Function to delete document via Cortex API
delete_document() {
    local doc_id="$1"
    local doc_title="$2"

    echo "  🗑️  Deleting: $doc_title ($doc_id)" >> "$LOG_FILE"

    if [ "$DRY_RUN" = false ]; then
        # Use deleteBlock API endpoint (works for document blocks)
        local result=$(cortex_api POST "/api/block/deleteBlock" "{\"id\":\"$doc_id\"}")

        # Check if deletion was successful
        if echo "$result" | grep -q '"code":0'; then
            return 0
        else
            echo "    ⚠️  Failed: $result" >> "$LOG_FILE"
            return 1
        fi
    else
        echo "    ℹ️  [DRY RUN] Would delete" >> "$LOG_FILE"
        return 0
    fi
}

# Function to delete in batches with rate limiting
delete_batch() {
    local pattern_type="$1"
    local docs_json="$2"
    local batch_size=50
    local delay=0.5

    local count=$(echo "$docs_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")

    if [ "$count" -eq 0 ]; then
        echo "  ✅ No $pattern_type pollution found" | tee -a "$LOG_FILE"
        return 0
    fi

    echo "" | tee -a "$LOG_FILE"
    echo "🗑️  Processing $count $pattern_type documents..." | tee -a "$LOG_FILE"

    local deleted=0
    local batch_num=0

    echo "$docs_json" | python3 -c "
import sys, json
docs = json.load(sys.stdin)
for doc in docs:
    print(f\"{doc['id']}|||{doc.get('title', 'Unknown')}\")
" | while IFS='|||' read -r doc_id doc_title; do
        # Check if we've hit the delete limit
        if [ "$DELETE_LIMIT" -gt 0 ] && [ "$TOTAL_DELETED" -ge "$DELETE_LIMIT" ]; then
            echo "  ⚠️  Reached delete limit of $DELETE_LIMIT" | tee -a "$LOG_FILE"
            break
        fi

        # Delete the document
        if delete_document "$doc_id" "$doc_title"; then
            TOTAL_DELETED=$((TOTAL_DELETED + 1))
            deleted=$((deleted + 1))
        fi

        # Rate limiting: pause every batch_size deletions
        if [ $((deleted % batch_size)) -eq 0 ]; then
            batch_num=$((batch_num + 1))
            echo "  ⏸️  Batch $batch_num complete, pausing ${delay}s..." | tee -a "$LOG_FILE"
            sleep "$delay"
        fi
    done

    echo "  ✅ Processed $deleted $pattern_type documents" | tee -a "$LOG_FILE"
    return 0
}

# Main execution
main() {
    # Get all documents
    ALL_DOCS=$(get_all_documents)

    # Identify pollution patterns
    POLLUTION_REPORT=$(identify_pollution "$ALL_DOCS")

    # Extract counts
    CHUNKS_COUNT=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('chunks', [])))")
    SUPABASE_COUNT=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('supabase', [])))")
    VERBATIM_COUNT=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('verbatim', [])))")
    MD_DUPES_COUNT=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('md_dupes', [])))")
    LEGITIMATE_COUNT=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('legitimate', [])))")

    TOTAL_POLLUTION=$((CHUNKS_COUNT + SUPABASE_COUNT + VERBATIM_COUNT + MD_DUPES_COUNT))

    # Summary report
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "📊 Pollution Report"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Pollution found:"
        echo "  🧩 Chunk pollution:        $CHUNKS_COUNT documents"
        echo "  🗃️  Supabase dumps:         $SUPABASE_COUNT documents"
        echo "  📋 Verbatim dumps:         $VERBATIM_COUNT documents"
        echo "  📄 .md duplicates:         $MD_DUPES_COUNT documents"
        echo ""
        echo "  ⚠️  TOTAL POLLUTION:       $TOTAL_POLLUTION documents"
        echo ""
        echo "Legitimate content:"
        echo "  ✅ Clean documents:        $LEGITIMATE_COUNT documents"
        echo ""
    } | tee -a "$LOG_FILE"

    # If dry run, show sample pollution
    if [ "$DRY_RUN" = true ]; then
        echo "═══════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"
        echo "🔍 Sample Pollution (first 5 of each type)" | tee -a "$LOG_FILE"
        echo "═══════════════════════════════════════════════════════════" | tee -a "$LOG_FILE"

        if [ "$CHUNKS_COUNT" -gt 0 ]; then
            echo "" | tee -a "$LOG_FILE"
            echo "Chunk pollution:" | tee -a "$LOG_FILE"
            echo "$POLLUTION_REPORT" | python3 -c "
import sys,json
chunks = json.load(sys.stdin).get('chunks', [])[:5]
for c in chunks:
    print(f\"  - {c['title']} ({c['id']})\")
" | tee -a "$LOG_FILE"
        fi

        if [ "$SUPABASE_COUNT" -gt 0 ]; then
            echo "" | tee -a "$LOG_FILE"
            echo "Supabase dumps:" | tee -a "$LOG_FILE"
            echo "$POLLUTION_REPORT" | python3 -c "
import sys,json
supabase = json.load(sys.stdin).get('supabase', [])[:5]
for s in supabase:
    print(f\"  - {s['title']} ({s['id']})\")
" | tee -a "$LOG_FILE"
        fi

        if [ "$VERBATIM_COUNT" -gt 0 ]; then
            echo "" | tee -a "$LOG_FILE"
            echo "Verbatim dumps:" | tee -a "$LOG_FILE"
            echo "$POLLUTION_REPORT" | python3 -c "
import sys,json
verbatim = json.load(sys.stdin).get('verbatim', [])[:5]
for v in verbatim:
    print(f\"  - {v['title']} ({v['id']})\")
" | tee -a "$LOG_FILE"
        fi

        if [ "$MD_DUPES_COUNT" -gt 0 ]; then
            echo "" | tee -a "$LOG_FILE"
            echo ".md duplicates:" | tee -a "$LOG_FILE"
            echo "$POLLUTION_REPORT" | python3 -c "
import sys,json
md_dupes = json.load(sys.stdin).get('md_dupes', [])[:5]
for m in md_dupes:
    print(f\"  - {m['title']} ({m['id']}) [duplicate of {m.get('duplicate_of', 'unknown')}]\")
" | tee -a "$LOG_FILE"
        fi

        echo "" | tee -a "$LOG_FILE"
        echo "ℹ️  This was a dry run. No documents were deleted." | tee -a "$LOG_FILE"
        echo "ℹ️  Run without --dry-run to perform cleanup." | tee -a "$LOG_FILE"
    else
        # Perform cleanup based on type
        case "$CLEANUP_TYPE" in
            chunks)
                CHUNKS_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('chunks', [])))")
                delete_batch "chunk" "$CHUNKS_JSON"
                ;;
            supabase)
                SUPABASE_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('supabase', [])))")
                delete_batch "supabase" "$SUPABASE_JSON"
                ;;
            verbatim)
                VERBATIM_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('verbatim', [])))")
                delete_batch "verbatim" "$VERBATIM_JSON"
                ;;
            md-dupes)
                MD_DUPES_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('md_dupes', [])))")
                delete_batch "md-duplicate" "$MD_DUPES_JSON"
                ;;
            all)
                # Delete all pollution types
                CHUNKS_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('chunks', [])))")
                delete_batch "chunk" "$CHUNKS_JSON"

                SUPABASE_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('supabase', [])))")
                delete_batch "supabase" "$SUPABASE_JSON"

                VERBATIM_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('verbatim', [])))")
                delete_batch "verbatim" "$VERBATIM_JSON"

                MD_DUPES_JSON=$(echo "$POLLUTION_REPORT" | python3 -c "import sys,json; print(json.dumps(json.load(sys.stdin).get('md_dupes', [])))")
                delete_batch "md-duplicate" "$MD_DUPES_JSON"
                ;;
        esac
    fi

    # Final summary
    {
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "✅ Cleanup Complete - $(date)"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Summary:"
        echo "  Total pollution found:     $TOTAL_POLLUTION documents"
        echo "  Total deleted:             $TOTAL_DELETED documents"
        echo "  Legitimate content:        $LEGITIMATE_COUNT documents (preserved)"
        echo ""
        echo "Log file: $LOG_FILE"
        echo ""
    } | tee -a "$LOG_FILE"
}

# Run main function
main

exit 0
