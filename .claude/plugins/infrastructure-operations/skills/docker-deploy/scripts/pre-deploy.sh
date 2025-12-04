#!/bin/bash

# Pre-deployment validation and backup script
# Usage: ./pre-deploy.sh <service-name>

set -euo pipefail

SERVICE_NAME=${1:-""}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="/tmp/deploy-${SERVICE_NAME}-${TIMESTAMP}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Validate service name
if [[ -z "$SERVICE_NAME" ]]; then
    error "Service name is required. Usage: $0 <service-name>"
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

log "INFO" "Starting pre-deployment checks for $SERVICE_NAME"
log "INFO" "Service path: $SERVICE_PATH"
log "INFO" "Timestamp: $TIMESTAMP"

# Check if running as root (required for docker operations)
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (use sudo)"
fi

# 1. Check Docker daemon status
log "INFO" "Checking Docker daemon status..."
if ! docker info > /dev/null 2>&1; then
    error "Docker daemon is not running"
fi
success "Docker daemon is running"

# 2. Check current service status
log "INFO" "Checking current service status..."
cd "$SERVICE_PATH"

if ! docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Service' > /dev/null 2>&1; then
    warning "Some services may not be running. Checking individual services..."
fi

# Get running services before deployment
RUNNING_SERVICES=$(docker compose ps --format json | jq -r '.[] | select(.State == "running") | .Service' | tr '\n' ' ')
log "INFO" "Currently running services: $RUNNING_SERVICES"

# 3. Validate docker-compose.yml
log "INFO" "Validating docker-compose configuration..."
if ! docker compose config > /dev/null; then
    error "Invalid docker-compose configuration"
fi
success "docker-compose.yml is valid"

# 4. Check disk space
log "INFO" "Checking disk space..."
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 85 ]]; then
    error "Disk usage is critically high: ${DISK_USAGE}%"
elif [[ $DISK_USAGE -gt 75 ]]; then
    warning "Disk usage is high: ${DISK_USAGE}%"
fi
success "Disk usage is acceptable: ${DISK_USAGE}%"

# 5. Backup current configuration
log "INFO" "Creating backup of current configuration..."
BACKUP_DIR="/srv/backups/pre-deploy-${SERVICE_NAME}-${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

# Backup docker-compose.yml and .env files
cp docker-compose.yml "$BACKUP_DIR/"
if [[ -f ".env" ]]; then
    cp .env "$BACKUP_DIR/"
fi

# Backup running configuration
docker compose ps --format json > "$BACKUP_DIR/running-services.json"

log "INFO" "Configuration backed up to: $BACKUP_DIR"

# 6. Check image updates availability
log "INFO" "Checking for image updates..."
docker compose pull --dry-run 2>/dev/null || true

# 7. Validate service dependencies
log "INFO" "Checking service dependencies..."
case "$SERVICE_NAME" in
    "docmost")
        # Check if proxy is running
        if ! docker compose -f /srv/proxy/docker-compose.yml ps | grep -q "Up"; then
            warning "Proxy service may not be running - this may affect access"
        fi
        ;;
    "nocodb")
        # Similar dependency checks
        log "INFO" "NocoDB depends on proxy for external access"
        ;;
    "n8n")
        log "INFO" "n8n depends on proxy for external access"
        ;;
esac

# 8. Generate pre-deployment report
cat > "$BACKUP_DIR/pre-deploy-report.md" << EOF
# Pre-deployment Report

**Service:** $SERVICE_NAME
**Timestamp:** $TIMESTAMP
**Path:** $SERVICE_PATH

## System Status
- **Docker:** Running
- **Disk Usage:** ${DISK_USAGE}%
- **Running Services:** $RUNNING_SERVICES

## Backups Created
- docker-compose.yml
- .env (if exists)
- running-services.json

## Validation Results
- ✅ Docker daemon running
- ✅ docker-compose.yml valid
- ✅ Disk space acceptable
- ✅ Configuration backed up

## Next Steps
Ready to proceed with deployment using: ./deploy.sh $SERVICE_NAME
EOF

success "Pre-deployment checks completed successfully"
log "INFO" "Pre-deployment report saved to: $BACKUP_DIR/pre-deployment-report.md"
log "INFO" "Ready to proceed with deployment"
log "INFO" "Use: ./deploy.sh $SERVICE_NAME"

echo ""
echo "=== Pre-deployment Summary ==="
echo "Service: $SERVICE_NAME"
echo "Status: ✅ Ready for deployment"
echo "Backup location: $BACKUP_DIR"
echo "Log file: $LOG_FILE"
echo ""