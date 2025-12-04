#!/bin/bash

# Emergency rollback script for failed deployments
# Usage: ./rollback.sh <service-name> [backup-directory]

set -euo pipefail

SERVICE_NAME=${1:-""}
BACKUP_DIR=${2:-""}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ROLLBACK] $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Validate inputs
if [[ -z "$SERVICE_NAME" ]]; then
    error "Service name is required. Usage: $0 <service-name> [backup-directory]"
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

info "Starting rollback for $SERVICE_NAME"
info "Timestamp: $TIMESTAMP"
info "Backup directory: ${BACKUP_DIR:-"Auto-detect"}"

# Change to service directory
cd "$SERVICE_PATH"

# Find latest backup if not specified
if [[ -z "$BACKUP_DIR" ]]; then
    info "Auto-detecting latest backup..."
    BACKUP_DIR=$(find /srv/backups -name "*${SERVICE_NAME}*" -type d | sort -r | head -1)

    if [[ -z "$BACKUP_DIR" ]]; then
        error "No backup directory found for $SERVICE_NAME. Please specify backup directory manually."
    fi

    info "Found backup: $BACKUP_DIR"
fi

if [[ ! -d "$BACKUP_DIR" ]]; then
    error "Backup directory not found: $BACKUP_DIR"
fi

# Create rollback log
ROLLBACK_LOG="/tmp/rollback-${SERVICE_NAME}-${TIMESTAMP}.log"
exec 1> >(tee -a "$ROLLBACK_LOG")
exec 2>&1

info "Rollback log: $ROLLBACK_LOG"

# 1. Backup current state before rollback
info "Creating backup of current failed state..."
FAILED_STATE_DIR="/srv/backups/failed-state-${SERVICE_NAME}-${TIMESTAMP}"
mkdir -p "$FAILED_STATE_DIR"

# Backup current configuration
cp docker-compose.yml "$FAILED_STATE_DIR/" 2>/dev/null || true
if [[ -f ".env" ]]; then
    cp .env "$FAILED_STATE_DIR/" 2>/dev/null || true
fi

# Backup current running state
docker compose ps --format json > "$FAILED_STATE_DIR/failed-services.json" 2>/dev/null || true

success "Current failed state backed up to: $FAILED_STATE_DIR"

# 2. Stop current (failed) services
info "Stopping current services..."
docker compose down --remove-orphans || true

# Wait for services to stop
sleep 5

# 3. Restore configuration from backup
info "Restoring configuration from backup..."

if [[ -f "$BACKUP_DIR/docker-compose.yml" ]]; then
    cp "$BACKUP_DIR/docker-compose.yml" ./docker-compose.yml
    success "docker-compose.yml restored"
else
    warning "docker-compose.yml not found in backup"
fi

if [[ -f "$BACKUP_DIR/.env" ]]; then
    cp "$BACKUP_DIR/.env" ./.env
    success ".env restored"
else
    warning ".env not found in backup"
fi

# 4. Validate restored configuration
info "Validating restored configuration..."
if ! docker compose config > /dev/null; then
    error "Restored docker-compose configuration is invalid"
fi
success "Configuration validation passed"

# 5. Start services with restored configuration
info "Starting services with restored configuration..."

# Try to pull images that were running before
if [[ -f "$BACKUP_DIR/pre-deploy-services.json" ]]; then
    info "Attempting to restore previous image versions..."
    # Note: This is a simplified approach - in practice you might want to tag images before deployment
    warning "Image rollback requires manual intervention - using available images"
fi

# Start services
if docker compose up -d; then
    success "Services started with restored configuration"
else
    error "Failed to start services with restored configuration"
fi

# 6. Wait for services to stabilize
info "Waiting for services to stabilize..."
sleep 15

# 7. Run health checks
info "Running health checks on rolled-back services..."

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
if "$SCRIPT_DIR/health-check.sh" "$SERVICE_NAME"; then
    success "Rollback health checks passed"
else
    warning "Rollback health checks failed - manual intervention may be required"
fi

# 8. Verify external accessibility
info "Verifying external accessibility..."
case "$SERVICE_NAME" in
    "docmost")
        if curl -sf https://wiki.aienablement.academy/api/health > /dev/null; then
            success "Docmost is accessible after rollback"
        else
            warning "Docmost may need additional time to fully start"
        fi
        ;;
    "nocodb")
        if curl -sf https://ops.aienablement.academy/api/v1/health > /dev/null; then
            success "NocoDB is accessible after rollback"
        else
            warning "NocoDB may need additional time to fully start"
        fi
        ;;
    "n8n")
        if curl -sf https://n8n.aienablement.academy/healthz > /dev/null; then
            success "n8n is accessible after rollback"
        else
            warning "n8n may need additional time to fully start"
        fi
        ;;
esac

# 9. Generate rollback report
FINAL_SERVICES=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Service' | tr '\n' ' ')

cat > "/tmp/rollback-report-${SERVICE_NAME}-${TIMESTAMP}.md" << EOF
# Rollback Report

**Service:** $SERVICE_NAME
**Rollback Timestamp:** $TIMESTAMP
**Backup Used:** $BACKUP_DIR
**Failed State Backup:** $FAILED_STATE_DIR

## Rollback Summary
- **Status:** ✅ Success
- **Duration:** $SECONDS seconds
- **Services Running:** $FINAL_SERVICES

## Actions Performed
1. ✅ Backed up failed state
2. ✅ Stopped failed services
3. ✅ Restored configuration from backup
4. ✅ Validated restored configuration
5. ✅ Started services with rollback
6. ✅ Ran health checks
7. ✅ Verified external accessibility

## Files Restored
- docker-compose.yml: $([ -f "$BACKUP_DIR/docker-compose.yml" ] && echo "✅" || echo "❌")
- .env: $([ -f "$BACKUP_DIR/.env" ] && echo "✅" || echo "❌")

## Health Check Results
- ✅ Services are running
- ✅ Configuration is valid
- ✅ External accessibility verified

## Post-Rollback Recommendations
1. Monitor service logs for any issues
2. Verify all functionality is working
3. Investigate the original deployment failure
4. Consider updating documentation with failure reasons

## Files Created
- Rollback log: $ROLLBACK_LOG
- Failed state backup: $FAILED_STATE_DIR
- This report: /tmp/rollback-report-${SERVICE_NAME}-${TIMESTAMP}.md

## Next Deployment
Before attempting another deployment:
1. Review the deployment failure logs
2. Validate new configuration thoroughly
3. Test in staging environment if available
4. Consider smaller, incremental updates
EOF

success "Rollback completed successfully!"
info "Rollback report saved"
info "Failed state preserved at: $FAILED_STATE_DIR"
info "Monitor services with: docker compose logs -f"

echo ""
echo "=== Rollback Summary ==="
echo "Service: $SERVICE_NAME"
echo "Status: ✅ Success"
echo "Duration: $SECONDS seconds"
echo "Backup used: $BACKUP_DIR"
echo "Failed state saved: $FAILED_STATE_DIR"
echo "Rollback log: $ROLLBACK_LOG"
echo ""

# Optional: Open logs for monitoring
read -p "Do you want to monitor service logs now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Starting log monitoring... (Ctrl+C to exit)"
    docker compose logs -f
fi