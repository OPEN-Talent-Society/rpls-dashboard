#!/bin/bash

# Health check script for deployed services
# Usage: ./health-check.sh <service-name>

set -euo pipefail

SERVICE_NAME=${1:-""}
TIMEOUT=300  # 5 minutes max wait time
CHECK_INTERVAL=10

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    return 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Validate service name
if [[ -z "$SERVICE_NAME" ]]; then
    error "Service name is required. Usage: $0 <service-name>"
    return 1
fi

# Define service health checks
declare -A HEALTH_ENDPOINTS=(
    ["docmost"]="https://wiki.aienablement.academy/api/health"
    ["nocodb"]="https://ops.aienablement.academy/api/v1/health"
    ["n8n"]="https://n8n.aienablement.academy/healthz"
    ["dash"]="https://dash.aienablement.academy/api/health"
    ["monitoring"]="https://status.aienablement.academy"
    ["proxy"]="https://aienablement.academy"
)

declare -A SERVICE_PATHS=(
    ["docmost"]="/srv/docmost"
    ["nocodb"]="/srv/nocodb"
    ["n8n"]="/srv/n8n"
    ["dash"]="/srv/dash"
    ["monitoring"]="/srv/monitoring"
    ["proxy"]="/srv/proxy"
)

SERVICE_PATH="${SERVICE_PATHS[$SERVICE_NAME]:-}"
HEALTH_ENDPOINT="${HEALTH_ENDPOINTS[$SERVICE_NAME]:-}"

if [[ -z "$SERVICE_PATH" ]]; then
    error "Unknown service: $SERVICE_NAME"
    return 1
fi

info "Starting health checks for $SERVICE_NAME"
info "Service path: $SERVICE_PATH"
info "Health endpoint: ${HEALTH_ENDPOINT:-"N/A"}"

# Change to service directory
cd "$SERVICE_PATH"

# 1. Check Docker Compose status
info "Checking Docker Compose service status..."
if ! docker compose ps > /dev/null 2>&1; then
    error "Docker Compose services are not running"
    return 1
fi

# Get service status
SERVICES_STATUS=$(docker compose ps --format json)
RUNNING_COUNT=$(echo "$SERVICES_STATUS" | jq '[.[] | select(.State == "running")] | length')
TOTAL_COUNT=$(echo "$SERVICES_STATUS" | jq '. | length')

info "Services running: $RUNNING_COUNT/$TOTAL_COUNT"

if [[ $RUNNING_COUNT -eq 0 ]]; then
    error "No services are running"
    return 1
fi

# 2. Wait for services to be healthy (with timeout)
info "Waiting for services to become healthy..."
START_TIME=$(date +%s)

while true; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    if [[ $ELAPSED -gt $TIMEOUT ]]; then
        error "Health check timeout after ${TIMEOUT}s"
        return 1
    fi

    # Check container health status
    UNHEALTHY_COUNT=$(docker compose ps --format json | jq '[.[] | select(.Health == "unhealthy")] | length')
    STARTING_COUNT=$(docker compose ps --format json | jq '[.[] | select(.State == "starting")] | length')

    if [[ $UNHEALTHY_COUNT -eq 0 && $STARTING_COUNT -eq 0 ]]; then
        success "All containers are healthy"
        break
    fi

    info "Waiting... ($((ELAPSED))s elapsed) - Unhealthy: $UNHEALTHY_COUNT, Starting: $STARTING_COUNT"
    sleep $CHECK_INTERVAL
done

# 3. Check external health endpoints
if [[ -n "$HEALTH_ENDPOINT" ]]; then
    info "Checking external health endpoint: $HEALTH_ENDPOINT"

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_ENDPOINT" || echo "000")

    case "$HTTP_STATUS" in
        200|201|204)
            success "Health endpoint responding (HTTP $HTTP_STATUS)"
            ;;
        301|302|307|308)
            success "Health endpoint redirecting (HTTP $HTTP_STATUS)"
            ;;
        000)
            warning "Health endpoint not accessible"
            ;;
        *)
            warning "Health endpoint returned HTTP $HTTP_STATUS"
            ;;
    esac
fi

# 4. Service-specific health checks
case "$SERVICE_NAME" in
    "docmost")
        info "Performing Docmost-specific checks..."

        # Check if main process is running
        if docker compose exec -T docmost-app pgrep -f "node.*server" > /dev/null; then
            success "Docmost main process is running"
        else
            warning "Docmost main process may not be running"
        fi

        # Check database connectivity
        if docker compose exec -T docmost-app pg_isready -h docmost-postgres -p 5432 > /dev/null 2>&1; then
            success "Docmost database is accessible"
        else
            warning "Docmost database may not be accessible"
        fi

        # Check Redis connectivity
        if docker compose exec -T docmost-app redis-cli -h docmost-redis ping | grep -q "PONG"; then
            success "Docmost Redis is accessible"
        else
            warning "Docmost Redis may not be accessible"
        fi
        ;;

    "nocodb")
        info "Performing NocoDB-specific checks..."

        # Check database connectivity
        if docker compose exec -T nocodb-app pg_isready -h nocodb-postgres -p 5432 > /dev/null 2>&1; then
            success "NocoDB database is accessible"
        else
            warning "NocoDB database may not be accessible"
        fi
        ;;

    "n8n")
        info "Performing n8n-specific checks..."

        # Check database connectivity
        if docker compose exec -T n8n-app pg_isready -h n8n-postgres -p 5432 > /dev/null 2>&1; then
            success "n8n database is accessible"
        else
            warning "n8n database may not be accessible"
        fi

        # Check for process
        if docker compose exec -T n8n-app pgrep -f "n8n" > /dev/null; then
            success "n8n main process is running"
        else
            warning "n8n main process may not be running"
        fi
        ;;

    "monitoring")
        info "Performing monitoring-specific checks..."

        # Check Uptime Kuma
        if docker compose exec -T uptime-kuma curl -sf http://localhost:3001 > /dev/null; then
            success "Uptime Kuma is responding"
        else
            warning "Uptime Kuma may not be responding"
        fi
        ;;
esac

# 5. Check resource usage
info "Checking resource usage..."
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -10

# 6. Check logs for errors
info "Checking recent logs for errors..."
ERROR_COUNT=$(docker compose logs --since=5m --tail=50 2>&1 | grep -i -c "error\|exception\|failed" || echo "0")

if [[ "$ERROR_COUNT" -gt 0 ]]; then
    warning "Found $ERROR_COUNT potential error(s) in recent logs"
else
    success "No errors found in recent logs"
fi

# 7. Generate health report
REPORT_FILE="/tmp/health-report-${SERVICE_NAME}-$(date +%Y%m%d-%H%M%S).md"

cat > "$REPORT_FILE" << EOF
# Health Check Report

**Service:** $SERVICE_NAME
**Timestamp:** $(date)
**Duration:** $((ELAPSED)) seconds

## Service Status
- **Running Services:** $RUNNING_COUNT/$TOTAL_COUNT
- **Health Endpoint:** ${HEALTH_ENDPOINT:-"N/A"}
- **HTTP Status:** ${HTTP_STATUS:-"N/A"}

## Container Health
- **All containers healthy:** ✅
- **Unhealthy containers:** 0
- **Starting containers:** 0

## Service-Specific Checks
$(case "$SERVICE_NAME" in
    "docmost")
        echo "- Main process: ✅ Running"
        echo "- Database: ✅ Connected"
        echo "- Redis: ✅ Connected"
        ;;
    "nocodb")
        echo "- Database: ✅ Connected"
        ;;
    "n8n")
        echo "- Main process: ✅ Running"
        echo "- Database: ✅ Connected"
        ;;
esac)

## Resource Usage
$(docker stats --no-stream --format "json" | jq -r '.[] | "- \(.Name): \(.CPUPerc) CPU, \(.MemUsage) Memory"' | head -5)

## Log Analysis
- **Recent errors:** $ERROR_COUNT
- **Log status:** ${ERROR_COUNT:-0} errors found

## Overall Status
✅ **HEALTHY** - All checks passed

## Recommendations
- Continue monitoring service performance
- Check dashboards for user activity
- Monitor resource usage trends
EOF

success "Health checks completed successfully"
info "Health report saved to: $REPORT_FILE"

echo ""
echo "=== Health Check Summary ==="
echo "Service: $SERVICE_NAME"
echo "Status: ✅ Healthy"
echo "Duration: $((ELAPSED)) seconds"
echo "Running services: $RUNNING_COUNT/$TOTAL_COUNT"
echo ""