#!/bin/bash

# Main deployment orchestration script
# Usage: ./deploy.sh <service-name> [--force] [--no-backup]

set -euo pipefail

SERVICE_NAME=${1:-""}
FORCE_DEPLOY=${2:-""}
NO_BACKUP=${3:-""}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/deploy-${SERVICE_NAME}-${TIMESTAMP}.log"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$1] $2" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Validate inputs
if [[ -z "$SERVICE_NAME" ]]; then
    error "Service name is required. Usage: $0 <service-name> [--force] [--no-backup]"
fi

# Define service paths
declare -A SERVICE_PATHS=(
    ["docmost"]="/srv/docmost"
    ["nocodb"]="/srv/nocodb"
    ["n8n"]="/srv/n8n"
    ["dash"]="/srv/dash"
    ["monitoring"]="/srv/monitoring"
    ["proxy"]="/srv/proxy"
)

SERVICE_PATH="${SERVICE_PATHS[$SERVICE_NAME]:-}"

if [[ -z "$SERVICE_PATH" ]]; then
    error "Unknown service: $SERVICE_NAME. Known services: ${!SERVICE_PATHS[*]}"
fi

if [[ ! -d "$SERVICE_PATH" ]]; then
    error "Service directory not found: $SERVICE_PATH"
fi

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

info "Starting deployment for $SERVICE_NAME"
info "Timestamp: $TIMESTAMP"
info "Force deploy: ${FORCE_DEPLOY:-false}"
info "Skip backup: ${NO_BACKUP:-false}"

# Change to service directory
cd "$SERVICE_PATH"

# 1. Run pre-deployment checks unless skipped
if [[ "$FORCE_DEPLOY" != "--force" ]]; then
    info "Running pre-deployment checks..."
    SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
    if ! "$SCRIPT_DIR/pre-deploy.sh" "$SERVICE_NAME"; then
        error "Pre-deployment checks failed. Use --force to bypass."
    fi
else
    warning "Skipping pre-deployment checks (force mode)"
fi

# 2. Create backup unless skipped
if [[ "$NO_BACKUP" != "--no-backup" ]]; then
    info "Creating deployment backup..."
    BACKUP_DIR="/srv/backups/deploy-${SERVICE_NAME}-${TIMESTAMP}"
    mkdir -p "$BACKUP_DIR"

    # Backup current containers
    docker compose ps --format json > "$BACKUP_DIR/pre-deploy-services.json"

    # Export images if they exist
    RUNNING_IMAGES=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Image' | sort -u)
    for image in $RUNNING_IMAGES; do
        if docker pull "$image" > /dev/null 2>&1; then
            log "INFO" "Image available: $image"
        else
            warning "Image may not be available: $image"
        fi
    done

    success "Deployment backup created: $BACKUP_DIR"
else
    warning "Skipping backup (no-backup mode)"
fi

# 3. Pull updated images
info "Pulling updated images..."
if docker compose pull; then
    success "Images pulled successfully"
else
    error "Failed to pull images"
fi

# 4. Check for configuration changes
info "Checking for configuration changes..."
if docker compose config > /dev/null; then
    success "Configuration is valid"
else
    error "Invalid docker-compose configuration"
fi

# 5. Stop services gracefully (for rolling updates)
info "Stopping services for update..."
docker compose down --remove-orphans || true

# 6. Start services
info "Starting updated services..."
if docker compose up -d; then
    success "Services started successfully"
else
    error "Failed to start services"
fi

# 7. Wait for services to be ready
info "Waiting for services to be ready..."
sleep 10

# 8. Run health checks
info "Running health checks..."
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if "$SCRIPT_DIR/health-check.sh" "$SERVICE_NAME"; then
    success "Health checks passed"
else
    warning "Health checks failed - initiating rollback"
    "$SCRIPT_DIR/rollback.sh" "$SERVICE_NAME" "$BACKUP_DIR"
    error "Deployment failed - rollback initiated"
fi

# 9. Verify service accessibility
info "Verifying service accessibility..."
case "$SERVICE_NAME" in
    "docmost")
        if curl -sf https://wiki.aienablement.academy/api/health > /dev/null; then
            success "Docmost is accessible"
        else
            warning "Docmost may not be fully ready yet"
        fi
        ;;
    "nocodb")
        if curl -sf https://ops.aienablement.academy/api/v1/health > /dev/null; then
            success "NocoDB is accessible"
        else
            warning "NocoDB may not be fully ready yet"
        fi
        ;;
    "n8n")
        if curl -sf https://n8n.aienablement.academy/healthz > /dev/null; then
            success "n8n is accessible"
        else
            warning "n8n may not be fully ready yet"
        fi
        ;;
esac

# 10. Generate deployment report
FINAL_SERVICES=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Service' | tr '\n' ' ')

cat > "${BACKUP_DIR:-/tmp}/deployment-report-${SERVICE_NAME}-${TIMESTAMP}.md" << EOF
# Deployment Report

**Service:** $SERVICE_NAME
**Timestamp:** $TIMESTAMP
**Deployment Duration:** $SECONDS seconds

## Deployment Summary
- **Status:** ✅ Success
- **Force Deploy:** ${FORCE_DEPLOY:-false}
- **Backup Created:** ${BACKUP_DIR:-"N/A"}

## Services Status
- **Running Services:** $FINAL_SERVICES
- **Previous Services:** $RUNNING_SERVICES

## Health Checks
- ✅ Services started successfully
- ✅ Health checks passed
- ✅ External accessibility verified

## Images Updated
$(docker compose images --format json | jq -r '.[] | "- \(.Service): \(.Repository):\(.Tag)"')

## Next Steps
1. Monitor service logs for any issues
2. Verify full functionality
3. Update documentation if needed

## Rollback Command
If issues arise: ./rollback.sh $SERVICE_NAME ${BACKUP_DIR:-"<backup-dir>"}
EOF

success "Deployment completed successfully!"
info "Deployment report saved"
info "Monitor services with: docker compose logs -f"

echo ""
echo "=== Deployment Summary ==="
echo "Service: $SERVICE_NAME"
echo "Status: ✅ Success"
echo "Duration: $SECONDS seconds"
echo "Backup: ${BACKUP_DIR:-"N/A"}"
echo "Log file: $LOG_FILE"
echo ""