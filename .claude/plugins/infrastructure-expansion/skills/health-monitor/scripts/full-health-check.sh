#!/bin/bash

# Comprehensive health monitoring across all infrastructure services
# Usage: ./full-health-check.sh [--output-format json|markdown] [--email-report]

set -euo pipefail

OUTPUT_FORMAT=${1:-"markdown"}
EMAIL_REPORT=${2:-""}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
REPORT_FILE="/tmp/health-report-${TIMESTAMP}.md"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Service definitions
declare -A SERVICES=(
    ["docmost"]="https://wiki.aienablement.academy/api/health"
    ["nocodb"]="https://ops.aienablement.academy/api/v1/health"
    ["n8n"]="https://n8n.aienablement.academy/healthz"
    ["dash"]="https://dash.aienablement.academy"
    ["status"]="https://status.aienablement.academy"
    ["uptime"]="https://uptime.aienablement.academy"
    ["monitor"]="https://monitor.aienablement.academy"
    ["metrics"]="https://metrics.aienablement.academy"
)

declare -A SERVICE_PATHS=(
    ["docmost"]="/srv/docmost"
    ["nocodb"]="/srv/nocodb"
    ["n8n"]="/srv/n8n"
    ["dash"]="/srv/dash"
    ["monitoring"]="/srv/monitoring"
    ["proxy"]="/srv/proxy"
)

# Health check results storage
declare -A HEALTH_RESULTS
declare -A RESPONSE_TIMES
declare -A HTTP_STATUS_CODES

# Utility functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [HEALTH] $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
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

# HTTP health check function
check_http_endpoint() {
    local service_name="$1"
    local url="$2"
    local timeout=10

    local start_time=$(date +%s.%N)
    local http_status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$timeout" "$url" 2>/dev/null || echo "000")
    local end_time=$(date +%s.%N)
    local response_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

    RESPONSE_TIMES[$service_name]="${response_time}s"
    HTTP_STATUS_CODES[$service_name]="$http_status"

    case "$http_status" in
        200|201|204)
            HEALTH_RESULTS[$service_name]="healthy"
            success "$service_name: HTTP $http_status (${response_time}s)"
            return 0
            ;;
        301|302|307|308)
            # Follow redirects
            local final_url=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time "$timeout" "$url" 2>/dev/null || echo "")
            if [[ -n "$final_url" ]]; then
                check_http_endpoint "$service_name" "$final_url"
                return $?
            else
                HEALTH_RESULTS[$service_name]="warning"
                warning "$service_name: HTTP $http_status (redirect failed, ${response_time}s)"
                return 1
            fi
            ;;
        000)
            HEALTH_RESULTS[$service_name]="critical"
            error "$service_name: Connection failed (${response_time}s)"
            return 2
            ;;
        *)
            HEALTH_RESULTS[$service_name]="warning"
            warning "$service_name: HTTP $http_status (${response_time}s)"
            return 1
            ;;
    esac
}

# Container health check
check_container_health() {
    local service_name="$1"
    local service_path="${SERVICE_PATHS[$service_name]:-}"

    if [[ -z "$service_path" ]] || [[ ! -d "$service_path" ]]; then
        warning "$service_name: Service path not found"
        return 1
    fi

    cd "$service_path"

    # Check if containers are running
    local running_containers=$(docker compose ps --format json | jq '[.[] | select(.State == "running")] | length' 2>/dev/null || echo "0")
    local total_containers=$(docker compose ps --format json | jq '. | length' 2>/dev/null || echo "0")

    if [[ "$running_containers" -eq 0 ]]; then
        error "$service_name: No containers running (0/$total_containers)"
        return 2
    elif [[ "$running_containers" -lt "$total_containers" ]]; then
        warning "$service_name: Some containers not running ($running_containers/$total_containers)"
        return 1
    else
        success "$service_name: All containers running ($running_containers/$total_containers)"
        return 0
    fi
}

# System resource check
check_system_resources() {
    info "Checking system resources..."

    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//' 2>/dev/null || echo "unknown")

    # Memory usage
    local memory_info=$(free -h | awk 'NR==2{printf "%.1f%%", $3*100/$2}' 2>/dev/null || echo "unknown")

    # Disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//' 2>/dev/null || echo "unknown")

    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs 2>/dev/null || echo "unknown")

    info "System Resources:"
    info "  CPU Usage: ${cpu_usage}%"
    info "  Memory Usage: ${memory_usage}"
    info "  Disk Usage: ${disk_usage}%"
    info "  Load Average: ${load_avg}"

    # Check thresholds
    local resource_issues=0

    if [[ "${disk_usage%.*}" -gt 90 ]]; then
        error "Critical: Disk usage is ${disk_usage}% (>90%)"
        ((resource_issues++))
    elif [[ "${disk_usage%.*}" -gt 80 ]]; then
        warning "Warning: Disk usage is ${disk_usage}% (>80%)"
        ((resource_issues++))
    fi

    return $resource_issues
}

# DNS resolution check
check_dns_resolution() {
    info "Checking DNS resolution..."

    local domains=("wiki.aienablement.academy" "ops.aienablement.academy" "n8n.aienablement.academy")
    local dns_issues=0

    for domain in "${domains[@]}"; do
        if nslookup "$domain" > /dev/null 2>&1; then
            success "DNS: $domain resolves correctly"
        else
            error "DNS: $domain resolution failed"
            ((dns_issues++))
        fi
    done

    return $dns_issues
}

# SSL certificate check
check_ssl_certificates() {
    info "Checking SSL certificates..."

    local ssl_issues=0
    local domains=("wiki.aienablement.academy" "ops.aienablement.academy" "n8n.aienablement.academy" "dash.aienablement.academy")

    for domain in "${domains[@]}"; do
        local expiry_date=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2 2>/dev/null || echo "unknown")

        if [[ "$expiry_date" != "unknown" ]]; then
            local expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
            local current_timestamp=$(date +%s)
            local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

            if [[ $days_until_expiry -lt 7 ]]; then
                error "SSL: $domain expires in $days_until_expiry days (CRITICAL)"
                ((ssl_issues++))
            elif [[ $days_until_expiry -lt 30 ]]; then
                warning "SSL: $domain expires in $days_until_expiry days (WARNING)"
                ((ssl_issues++))
            else
                success "SSL: $domain is valid for $days_until_expiry days"
            fi
        else
            error "SSL: Could not retrieve certificate for $domain"
            ((ssl_issues++))
        fi
    done

    return $ssl_issues
}

# Database connectivity check
check_database_connectivity() {
    info "Checking database connectivity..."

    local db_issues=0

    # Check Docmost database
    if docker compose -f /srv/docmost/docker-compose.yml exec -T docmost-postgres pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        success "Database: Docmost PostgreSQL is ready"
    else
        error "Database: Docmost PostgreSQL is not ready"
        ((db_issues++))
    fi

    # Check NocoDB database
    if docker compose -f /srv/nocodb/docker-compose.yml exec -T nocodb-postgres pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        success "Database: NocoDB PostgreSQL is ready"
    else
        error "Database: NocoDB PostgreSQL is not ready"
        ((db_issues++))
    fi

    # Check n8n database
    if docker compose -f /srv/n8n/docker-compose.yml exec -T n8n-postgres pg_isready -h localhost -p 5432 > /dev/null 2>&1; then
        success "Database: n8n PostgreSQL is ready"
    else
        error "Database: n8n PostgreSQL is not ready"
        ((db_issues++))
    fi

    return $db_issues
}

# Generate health report
generate_report() {
    local total_services=${#SERVICES[@]}
    local healthy_services=0
    local warning_services=0
    local critical_services=0

    for service in "${!HEALTH_RESULTS[@]}"; do
        case "${HEALTH_RESULTS[$service]}" in
            "healthy") ((healthy_services++)) ;;
            "warning") ((warning_services++)) ;;
            "critical") ((critical_services++)) ;;
        esac
    done

    cat > "$REPORT_FILE" << EOF
# Infrastructure Health Report

**Generated:** $(date)
**Report ID:** $TIMESTAMP
**Total Services:** $total_services

## Executive Summary

- **Healthy Services:** $healthy_services/$total_services
- **Warning Services:** $warning_services/$total_services
- **Critical Services:** $critical_services/$total_services

**Overall Status:** $([[ $critical_services -eq 0 ]] && echo "✅ HEALTHY" || echo "🔥 CRITICAL ISSUES")

## Service Health Status

| Service | URL | Status | HTTP Status | Response Time |
|---------|-----|--------|-------------|---------------|
EOF

    for service in "${!SERVICES[@]}"; do
        local status="${HEALTH_RESULTS[$service]:-unknown}"
        local status_icon="❓"

        case "$status" in
            "healthy") status_icon="✅" ;;
            "warning") status_icon="⚠️" ;;
            "critical") status_icon="🔥" ;;
        esac

        echo "| $service | ${SERVICES[$service]} | $status_icon $status | ${HTTP_STATUS_CODES[$service]:-N/A} | ${RESPONSE_TIMES[$service]:-N/A} |" >> "$REPORT_FILE"
    done

    cat >> "$REPORT_FILE" << EOF

## Container Health

EOF

    # Add container health information
    for service in "${!SERVICE_PATHS[@]}"; do
        local service_path="${SERVICE_PATHS[$service]}"
        if [[ -d "$service_path" ]]; then
            cd "$service_path"
            echo "### $service" >> "$REPORT_FILE"
            docker compose ps --format "table {{.Name}}\t{{.State}}\t{{.Status}}" >> "$REPORT_FILE" 2>/dev/null || echo "Could not retrieve container status" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
        fi
    done

    cat >> "$REPORT_FILE" << EOF
## System Resources

$(df -h / | awk 'NR==2 {printf "- **Disk Usage:** %s/%s (%s used)\n", $3, $2, $5}')
$(free -h | awk 'NR==2 {printf "- **Memory Usage:** %s/%s (%.1f%% used)\n", $3, $2, $3*100/$2}')
$(top -bn1 | grep "Cpu(s)" | awk '{printf "- **CPU Usage:** %s%%\n", $2}')
- **Load Average:** $(uptime | awk -F'load average:' '{print $2}')

## Recommendations

EOF

    if [[ $critical_services -gt 0 ]]; then
        echo "🔥 **CRITICAL ISSUES REQUIRING IMMEDIATE ATTENTION:**" >> "$REPORT_FILE"
        echo "- $critical_services service(s) are in critical state" >> "$REPORT_FILE"
        echo "- Check service logs and restart failed services" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    if [[ $warning_services -gt 0 ]]; then
        echo "⚠️ **WARNING ISSUES TO INVESTIGATE:**" >> "$REPORT_FILE"
        echo "- $warning_services service(s) showing warning signs" >> "$REPORT_FILE"
        echo "- Monitor performance and investigate potential causes" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    if [[ $critical_services -eq 0 && $warning_services -eq 0 ]]; then
        echo "✅ **All systems are operating normally**" >> "$REPORT_FILE"
        echo "- Continue regular monitoring" >> "$REPORT_FILE"
        echo "- Schedule routine maintenance as needed" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    fi

    cat >> "$REPORT_FILE" << EOF
## Next Steps

1. Review any services showing warning or critical status
2. Check application logs for detailed error information
3. Verify system resources are within acceptable limits
4. Schedule any necessary maintenance or updates

---
*Report generated by Claude Code Health Monitor Skill*
EOF
}

# Main execution
main() {
    info "Starting comprehensive health check..."
    info "Timestamp: $TIMESTAMP"
    info "Output format: $OUTPUT_FORMAT"

    # Initialize health results
    for service in "${!SERVICES[@]}"; do
        HEALTH_RESULTS[$service]="unknown"
    done

    # Run health checks
    info "Running HTTP endpoint checks..."
    for service in "${!SERVICES[@]}"; do
        check_http_endpoint "$service" "${SERVICES[$service]}"
    done

    info "Running container health checks..."
    for service in "${!SERVICE_PATHS[@]}"; do
        check_container_health "$service"
    done

    # Run system checks
    check_system_resources
    check_dns_resolution
    check_ssl_certificates
    check_database_connectivity

    # Generate report
    generate_report

    success "Health check completed!"
    info "Report saved to: $REPORT_FILE"

    # Display summary
    local total_services=${#SERVICES[@]}
    local healthy_services=$(printf '%s\n' "${HEALTH_RESULTS[@]}" | grep -c "healthy" || echo "0")
    local critical_services=$(printf '%s\n' "${HEALTH_RESULTS[@]}" | grep -c "critical" || echo "0")

    echo ""
    echo "=== Health Check Summary ==="
    echo "Total Services: $total_services"
    echo "Healthy: $healthy_services"
    echo "Critical: $critical_services"
    echo "Report: $REPORT_FILE"
    echo ""

    # Send email report if requested
    if [[ -n "$EMAIL_REPORT" ]]; then
        info "Sending email report to: $EMAIL_REPORT"
        # Email sending implementation would go here
        warning "Email functionality not implemented yet"
    fi

    # Return appropriate exit code
    if [[ $critical_services -gt 0 ]]; then
        return 2
    elif [[ $((${total_services} - healthy_services)) -gt 0 ]]; then
        return 1
    else
        return 0
    fi
}

# Run main function
main "$@"