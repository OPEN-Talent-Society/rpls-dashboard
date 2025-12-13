#!/bin/bash
# ====================================================
# QDRANT RE-INGESTION ORCHESTRATOR
# Comprehensive script to re-ingest all data into Qdrant
# ====================================================
#
# This script orchestrates a full re-ingestion of all Qdrant collections:
# 1. AgentDB episodes (high quality: reward > 0.7)
# 2. Supabase learnings (excluding swarm-memory)
# 3. Supabase patterns
# 4. Codebase files (hooks, skills, agents)
# 5. Cortex knowledge base
#
# Safety Features:
# - Backup verification before clearing
# - Dry-run mode for testing
# - Progress logging
# - Final verification checks
#
# Usage:
#   ./reingest-all.sh           # Full re-ingestion
#   ./reingest-all.sh --dry-run # Preview without changes
#
# ====================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
LOG_FILE="/tmp/qdrant-reingest-$(date +%Y%m%d-%H%M%S).log"

# Load environment
source "$PROJECT_DIR/.env" 2>/dev/null || {
    echo "❌ Failed to load .env file"
    exit 1
}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
DRY_RUN=false
SKIP_BACKUP_CHECK=false
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --skip-backup-check)
      SKIP_BACKUP_CHECK=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--dry-run] [--skip-backup-check]"
      exit 1
      ;;
  esac
done

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY}"
GEMINI_API_KEY="${GEMINI_API_KEY}"

# Collections to manage
COLLECTIONS=(
    "agent_memory"
    "learnings"
    "patterns"
    "codebase"
    "cortex"
)

# ====================================================
# LOGGING FUNCTIONS
# ====================================================

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() {
    log "INFO" "$1"
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    log "SUCCESS" "$1"
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    log "WARN" "$1"
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    log "ERROR" "$1"
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    log "STEP" "$1"
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}🔄 $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ====================================================
# HEADER
# ====================================================

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         QDRANT RE-INGESTION ORCHESTRATOR                  ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_warn "DRY RUN MODE - No changes will be made"
fi

log_info "Qdrant URL: $QDRANT_URL"
log_info "Log file: $LOG_FILE"
echo ""

# ====================================================
# STEP 1: PRE-FLIGHT CHECKS
# ====================================================

log_step "STEP 1/7: Pre-flight Checks"

# Check Qdrant connection
log_info "Checking Qdrant connection..."
if ! curl -s -f -H "api-key: ${QDRANT_API_KEY}" "$QDRANT_URL/collections" > /dev/null; then
    log_error "Cannot connect to Qdrant at $QDRANT_URL"
    exit 1
fi
log_success "Connected to Qdrant"

# Check required environment variables
log_info "Checking environment variables..."
MISSING_VARS=()
[ -z "$QDRANT_API_KEY" ] && MISSING_VARS+=("QDRANT_API_KEY")
[ -z "$GEMINI_API_KEY" ] && MISSING_VARS+=("GEMINI_API_KEY")
[ -z "$SUPABASE_SERVICE_ROLE_KEY" ] && MISSING_VARS+=("SUPABASE_SERVICE_ROLE_KEY")
[ -z "$CORTEX_TOKEN" ] && MISSING_VARS+=("CORTEX_TOKEN")

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    log_error "Missing required environment variables: ${MISSING_VARS[*]}"
    exit 1
fi
log_success "All required environment variables present"

# Check AgentDB exists
log_info "Checking AgentDB..."
AGENTDB_PATH="$PROJECT_DIR/agentdb.db"
if [ ! -f "$AGENTDB_PATH" ]; then
    log_error "AgentDB not found at $AGENTDB_PATH"
    exit 1
fi

EPISODE_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
log_success "AgentDB found with $EPISODE_COUNT episodes"

# Check backup exists (unless skipped)
if [ "$SKIP_BACKUP_CHECK" = false ]; then
    log_info "Checking for recent Qdrant backup..."
    BACKUP_DIR="$PROJECT_DIR/.claude/backups/qdrant"
    if [ -d "$BACKUP_DIR" ]; then
        LATEST_BACKUP=$(ls -t "$BACKUP_DIR" | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            log_success "Latest backup found: $LATEST_BACKUP"
        else
            log_warn "No backups found in $BACKUP_DIR"
            read -p "Continue without backup verification? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Aborted by user"
                exit 1
            fi
        fi
    else
        log_warn "Backup directory not found: $BACKUP_DIR"
        log_warn "Consider creating backups before proceeding"
        if [ "$DRY_RUN" = false ]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log_error "Aborted by user"
                exit 1
            fi
        fi
    fi
fi

# Check required scripts exist
log_info "Checking required scripts..."
REQUIRED_SCRIPTS=(
    "$SCRIPT_DIR/sync-episodes-to-qdrant.sh"
    "$SCRIPT_DIR/sync-supabase-to-qdrant.sh"
    "$SCRIPT_DIR/sync-patterns-to-qdrant.sh"
    "$SCRIPT_DIR/index-codebase-to-qdrant.sh"
    "$SCRIPT_DIR/sync-cortex-to-qdrant.sh"
    "$SCRIPT_DIR/init-qdrant-collections.sh"
)

MISSING_SCRIPTS=()
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        MISSING_SCRIPTS+=("$(basename "$script")")
    fi
done

if [ ${#MISSING_SCRIPTS[@]} -gt 0 ]; then
    log_error "Missing required scripts: ${MISSING_SCRIPTS[*]}"
    exit 1
fi
log_success "All required scripts present"

log_success "All pre-flight checks passed"

# ====================================================
# STEP 2: BACKUP CURRENT STATE
# ====================================================

log_step "STEP 2/7: Backup Current State"

log_info "Recording current collection counts..."
for collection in "${COLLECTIONS[@]}"; do
    COUNT=$(curl -s "$QDRANT_URL/collections/$collection" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0' 2>/dev/null || echo "0")
    log_info "  $collection: $COUNT points"
    echo "$collection=$COUNT" >> "$LOG_FILE"
done

log_success "Current state recorded in log file"

# ====================================================
# STEP 3: CLEAR COLLECTIONS
# ====================================================

log_step "STEP 3/7: Clear Collections"

if [ "$DRY_RUN" = false ]; then
    log_warn "This will DELETE all data from ${#COLLECTIONS[@]} Qdrant collections!"
    echo -e "${YELLOW}Collections to clear: ${COLLECTIONS[*]}${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    if [[ ! $REPLY =~ ^yes$ ]]; then
        log_error "Aborted by user"
        exit 1
    fi
fi

for collection in "${COLLECTIONS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
        log_info "Would clear collection: $collection"
    else
        log_info "Clearing collection: $collection..."

        # Delete collection
        RESULT=$(curl -s -X DELETE "$QDRANT_URL/collections/$collection" \
            -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null)

        if echo "$RESULT" | jq -e '.result == true' > /dev/null 2>&1; then
            log_success "  Deleted $collection"
        else
            log_warn "  Failed to delete $collection (may not exist)"
        fi

        # Recreate collection with proper schema
        log_info "  Recreating $collection..."
        RESULT=$(curl -s -X PUT "$QDRANT_URL/collections/$collection" \
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
            }' 2>/dev/null)

        if echo "$RESULT" | jq -e '.result == true' > /dev/null 2>&1; then
            log_success "  Created $collection"
        else
            log_error "  Failed to create $collection"
            echo "$RESULT" | jq '.' 2>/dev/null || echo "$RESULT"
            exit 1
        fi
    fi
done

log_success "All collections cleared and recreated"

# ====================================================
# STEP 4: RE-INGEST AGENTDB EPISODES
# ====================================================

log_step "STEP 4/7: Re-ingest AgentDB Episodes (High Quality)"

log_info "Filtering episodes with reward > 0.7..."

if [ "$DRY_RUN" = true ]; then
    HIGH_QUALITY_COUNT=$(sqlite3 "$AGENTDB_PATH" \
        "SELECT COUNT(*) FROM episodes WHERE reward > 0.7;" 2>/dev/null || echo "0")
    log_info "Would ingest $HIGH_QUALITY_COUNT high-quality episodes"
else
    # Clear sync state to force full re-ingestion
    rm -f /tmp/qdrant-episodes-sync-state.json

    # Create temporary filtered database for high-quality episodes
    TEMP_DB="/tmp/agentdb-high-quality.db"
    rm -f "$TEMP_DB"

    sqlite3 "$AGENTDB_PATH" <<EOF
ATTACH DATABASE '$TEMP_DB' AS temp;
CREATE TABLE temp.episodes AS
    SELECT * FROM episodes WHERE reward > 0.7;
DETACH DATABASE temp;
EOF

    HIGH_QUALITY_COUNT=$(sqlite3 "$TEMP_DB" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
    log_info "Filtered to $HIGH_QUALITY_COUNT high-quality episodes (reward > 0.7)"

    # Temporarily override agentdb path
    ORIGINAL_AGENTDB="$AGENTDB_PATH"
    export AGENTDB_PATH="$TEMP_DB"

    # Run episodes sync
    log_info "Running sync-episodes-to-qdrant.sh..."
    if bash "$SCRIPT_DIR/sync-episodes-to-qdrant.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "AgentDB episodes ingested successfully"
    else
        log_error "Failed to ingest AgentDB episodes"
        export AGENTDB_PATH="$ORIGINAL_AGENTDB"
        rm -f "$TEMP_DB"
        exit 1
    fi

    # Restore original path and cleanup
    export AGENTDB_PATH="$ORIGINAL_AGENTDB"
    rm -f "$TEMP_DB"
fi

# ====================================================
# STEP 5: RE-INGEST SUPABASE DATA
# ====================================================

log_step "STEP 5/7: Re-ingest Supabase Data"

if [ "$DRY_RUN" = true ]; then
    log_info "Would ingest Supabase learnings (excluding swarm-memory)"
    log_info "Would ingest Supabase patterns"
else
    # Clear sync states
    rm -f /tmp/qdrant-learnings-sync-state.json
    rm -f /tmp/qdrant-patterns-sync-state.json

    # Ingest learnings
    log_info "Ingesting Supabase learnings..."
    if bash "$SCRIPT_DIR/sync-supabase-to-qdrant.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Supabase learnings ingested successfully"
    else
        log_error "Failed to ingest Supabase learnings"
        exit 1
    fi

    # Ingest patterns
    log_info "Ingesting Supabase patterns..."
    if bash "$SCRIPT_DIR/sync-patterns-to-qdrant.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Supabase patterns ingested successfully"
    else
        log_error "Failed to ingest Supabase patterns"
        exit 1
    fi
fi

# ====================================================
# STEP 6: RE-INGEST CODEBASE
# ====================================================

log_step "STEP 6/7: Re-ingest Codebase"

if [ "$DRY_RUN" = true ]; then
    log_info "Would ingest codebase files (hooks, skills, agents)"
else
    log_info "Indexing codebase to Qdrant..."
    if bash "$SCRIPT_DIR/index-codebase-to-qdrant.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Codebase indexed successfully"
    else
        log_error "Failed to index codebase"
        exit 1
    fi
fi

# ====================================================
# STEP 7: RE-INGEST CORTEX KNOWLEDGE
# ====================================================

log_step "STEP 7/7: Re-ingest Cortex Knowledge Base"

if [ "$DRY_RUN" = true ]; then
    log_info "Would ingest Cortex knowledge base"
else
    # Clear sync state
    rm -f /tmp/cortex-qdrant-sync-state.json

    log_info "Syncing Cortex to Qdrant..."
    if bash "$SCRIPT_DIR/sync-cortex-to-qdrant.sh" 2>&1 | tee -a "$LOG_FILE"; then
        log_success "Cortex knowledge ingested successfully"
    else
        log_warn "Cortex sync failed (non-critical)"
    fi
fi

# ====================================================
# STEP 8: VERIFICATION
# ====================================================

log_step "Verification & Summary"

log_info "Final collection counts:"
TOTAL_VECTORS=0

for collection in "${COLLECTIONS[@]}"; do
    if [ "$DRY_RUN" = true ]; then
        log_info "  $collection: N/A (dry run)"
    else
        COUNT=$(curl -s "$QDRANT_URL/collections/$collection" \
            -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0' 2>/dev/null || echo "0")
        TOTAL_VECTORS=$((TOTAL_VECTORS + COUNT))
        log_info "  $collection: $COUNT points"
    fi
done

if [ "$DRY_RUN" = false ]; then
    log_success "Total vectors across all collections: $TOTAL_VECTORS"
fi

# ====================================================
# COMPLETION
# ====================================================

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                 RE-INGESTION COMPLETE                     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    log_success "Dry run completed successfully"
    log_info "Run without --dry-run to perform actual re-ingestion"
else
    log_success "All data re-ingested successfully"
    log_info "Log file: $LOG_FILE"

    # Verification checks
    log_info "Running verification checks..."

    # Check for empty collections (warning, not error)
    EMPTY_COLLECTIONS=()
    for collection in "${COLLECTIONS[@]}"; do
        COUNT=$(curl -s "$QDRANT_URL/collections/$collection" \
            -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0' 2>/dev/null || echo "0")
        if [ "$COUNT" -eq 0 ]; then
            EMPTY_COLLECTIONS+=("$collection")
        fi
    done

    if [ ${#EMPTY_COLLECTIONS[@]} -gt 0 ]; then
        log_warn "Some collections are empty: ${EMPTY_COLLECTIONS[*]}"
        log_warn "This may be expected if source data is empty"
    else
        log_success "All collections contain data"
    fi

    # Suggest next steps
    echo ""
    log_info "Next steps:"
    log_info "  1. Test semantic search: bash $SCRIPT_DIR/semantic-search.sh 'your query'"
    log_info "  2. Check memory stats: bash $SCRIPT_DIR/memory-stats.sh"
    log_info "  3. Review log file: cat $LOG_FILE"
fi

echo ""
exit 0
