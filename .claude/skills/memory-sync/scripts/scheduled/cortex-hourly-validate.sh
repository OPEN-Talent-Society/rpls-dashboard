#!/bin/bash
# Cortex Hourly Validation Script
# Container: OCI (Cortex/SiYuan)
# Purpose: Check for orphan documents, validate custom-category attributes, generate health report
# Schedule: Hourly at :15 minutes past the hour
# Cron: 15 * * * * /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/scheduled/cortex-hourly-validate.sh >> /Users/adamkovacs/.claude_code/logs/cortex-hourly-validate.log 2>&1

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_DIR="$PROJECT_DIR/.claude/logs/maintenance"
REPORT_DIR="$PROJECT_DIR/.claude/logs/health-reports"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

LOG_FILE="$LOG_DIR/cortex-hourly-validate-$(date +%Y%m%d-%H%M%S).log"
REPORT_FILE="$REPORT_DIR/cortex-health-$(date +%Y%m%d-%H).json"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "═══════════════════════════════════════════════════════════"
echo "🔍 Cortex Hourly Validation - $(date)"
echo "═══════════════════════════════════════════════════════════"

# Load environment (extract vars individually to avoid zsh parse errors)
if [ -f "$PROJECT_DIR/.env" ]; then
    CORTEX_URL=$(grep "^CORTEX_URL=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CORTEX_TOKEN=$(grep "^CORTEX_TOKEN=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CF_ACCESS_CLIENT_ID=$(grep "^CF_ACCESS_CLIENT_ID=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
    CF_ACCESS_CLIENT_SECRET=$(grep "^CF_ACCESS_CLIENT_SECRET=" "$PROJECT_DIR/.env" | cut -d'=' -f2-)
fi

[ -z "$CORTEX_TOKEN" ] && { echo "❌ CORTEX_TOKEN not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_ID" ] && { echo "❌ CF_ACCESS_CLIENT_ID not set"; exit 1; }
[ -z "$CF_ACCESS_CLIENT_SECRET" ] && { echo "❌ CF_ACCESS_CLIENT_SECRET not set"; exit 1; }

CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"

# Statistics
TOTAL_NOTEBOOKS=0
TOTAL_DOCUMENTS=0
ORPHAN_DOCUMENTS=0
MISSING_CATEGORIES=0
DOCUMENTS_WITH_CATEGORIES=0

# Helper for Cortex API calls (with CF Access)
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

# ============================================
# HEALTH CHECK
# ============================================
health_check() {
    echo ""
    echo "🏥 Health Check..."

    local version=$(cortex_api POST "/api/system/version" '{}' | jq -r '.data.ver // "unknown"')

    if [ "$version" != "unknown" ] && [ -n "$version" ]; then
        echo "  ✅ Cortex is healthy (version: $version)"
        return 0
    else
        echo "  ❌ Health check failed"
        return 1
    fi
}

# ============================================
# CHECK FOR ORPHAN DOCUMENTS (NO REFS)
# ============================================
check_orphan_documents() {
    echo ""
    echo "🔍 Checking for orphan documents (no references)..."

    # Use SiYuan's built-in orphan detection
    local orphans=$(cortex_api POST "/api/search/searchUnRef" '{}')
    local count=$(echo "$orphans" | jq '.data.blocks | length' 2>/dev/null || echo "0")

    ORPHAN_DOCUMENTS=$count

    if [ "$count" -gt 0 ]; then
        echo "  ⚠️  Found $count orphan documents"
        echo "  📝 Sample orphan IDs:"
        echo "$orphans" | jq -r '.data.blocks[]?.id' | head -5 | while read id; do
            echo "      - $id"
        done

        if [ "$count" -gt 100 ]; then
            echo "  ⚠️  HIGH: $count orphans - consider cleanup"
        fi
    else
        echo "  ✅ No orphan documents found"
    fi
}

# ============================================
# VALIDATE CUSTOM-CATEGORY ATTRIBUTES
# ============================================
validate_custom_categories() {
    echo ""
    echo "📋 Validating custom-category attributes..."

    # Get all notebooks
    local notebooks=$(cortex_api POST "/api/notebook/lsNotebooks" '{}')
    TOTAL_NOTEBOOKS=$(echo "$notebooks" | jq '.data.notebooks | length')

    echo "  📚 Checking $TOTAL_NOTEBOOKS notebooks..."

    # Check each notebook for documents with/without custom-category
    for nb_entry in $(echo "$notebooks" | jq -r '.data.notebooks[] | @base64'); do
        local nb_data=$(echo "$nb_entry" | base64 -d 2>/dev/null || echo "$nb_entry" | base64 -D)
        local nb_id=$(echo "$nb_data" | jq -r '.id')
        local nb_name=$(echo "$nb_data" | jq -r '.name')

        # Query documents in this notebook
        local docs=$(cortex_api POST "/api/query/sql" \
            "{\"stmt\": \"SELECT id, ial FROM blocks WHERE type='d' AND box='${nb_id}' LIMIT 1000\"}")

        local total_docs=$(echo "$docs" | jq '.data | length' 2>/dev/null || echo "0")
        TOTAL_DOCUMENTS=$((TOTAL_DOCUMENTS + total_docs))

        # Count documents with custom-category attribute
        local with_category=$(echo "$docs" | python3 -c "
import sys, json, re
data = json.load(sys.stdin)
count = 0
for doc in data.get('data', []):
    ial = doc.get('ial', '')
    if re.search(r'custom-category=', ial):
        count += 1
print(count)
" 2>/dev/null)

        local without_category=$((total_docs - with_category))

        DOCUMENTS_WITH_CATEGORIES=$((DOCUMENTS_WITH_CATEGORIES + with_category))
        MISSING_CATEGORIES=$((MISSING_CATEGORIES + without_category))

        if [ "$without_category" -gt 0 ]; then
            echo "    📁 $nb_name: $total_docs docs, $without_category missing custom-category"
        else
            echo "    ✅ $nb_name: all $total_docs docs have custom-category"
        fi
    done

    echo ""
    echo "  📊 Total: $TOTAL_DOCUMENTS documents"
    echo "  ✅ With category: $DOCUMENTS_WITH_CATEGORIES"
    echo "  ⚠️  Missing category: $MISSING_CATEGORIES"

    if [ "$MISSING_CATEGORIES" -gt 0 ]; then
        echo "  💡 Run semantic-crosslink-cortex.sh to add categories"
    fi
}

# ============================================
# GENERATE HEALTH REPORT
# ============================================
generate_health_report() {
    echo ""
    echo "📊 Generating health report..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local status="healthy"

    # Determine overall status
    if [ "$ORPHAN_DOCUMENTS" -gt 100 ] || [ "$MISSING_CATEGORIES" -gt 50 ]; then
        status="warning"
    fi

    if [ "$ORPHAN_DOCUMENTS" -gt 500 ]; then
        status="critical"
    fi

    # Generate JSON report
    cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$timestamp",
  "status": "$status",
  "metrics": {
    "total_notebooks": $TOTAL_NOTEBOOKS,
    "total_documents": $TOTAL_DOCUMENTS,
    "orphan_documents": $ORPHAN_DOCUMENTS,
    "missing_categories": $MISSING_CATEGORIES,
    "documents_with_categories": $DOCUMENTS_WITH_CATEGORIES,
    "category_coverage_percent": $(python3 -c "print(round($DOCUMENTS_WITH_CATEGORIES * 100 / max($TOTAL_DOCUMENTS, 1), 2))")
  },
  "recommendations": [
$([ "$ORPHAN_DOCUMENTS" -gt 100 ] && echo '    "High orphan count - consider running cleanup",' || echo '')
$([ "$MISSING_CATEGORIES" -gt 50 ] && echo '    "Many documents missing categories - run semantic-crosslink-cortex.sh"' || echo '')
  ]
}
EOF

    echo "  ✅ Report saved: $REPORT_FILE"
    cat "$REPORT_FILE"
}

# ============================================
# MAIN
# ============================================
main() {
    echo ""

    # Run health check first
    if ! health_check; then
        echo "❌ Cortex unhealthy - aborting validation"
        exit 1
    fi

    # Run validation tasks
    check_orphan_documents
    validate_custom_categories
    generate_health_report

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "✅ Cortex Hourly Validation Complete - $(date)"
    echo "═══════════════════════════════════════════════════════════"
}

# Run main
main
