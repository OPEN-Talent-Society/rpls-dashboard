#!/bin/bash
# Uptime Kuma Monitor Setup Script
# Automatically configures all monitors from JSON configuration

set -euo pipefail

# Configuration
UPTIME_KUMA_URL="${UPTIME_KUMA_URL:-https://uptime.aienablement.academy}"
SERVICES_JSON="${1:-/tmp/uptime-kuma-services.json}"
API_KEY="${UPTIME_KUMA_API_KEY:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check dependencies
check_dependencies() {
    local missing=()

    for cmd in jq curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log_info "Install with: brew install ${missing[*]}"
        exit 1
    fi
}

# Validate configuration
validate_config() {
    if [ ! -f "$SERVICES_JSON" ]; then
        log_error "Services configuration not found: $SERVICES_JSON"
        exit 1
    fi

    if [ -z "$API_KEY" ]; then
        log_warning "UPTIME_KUMA_API_KEY not set, will use manual configuration"
        log_info "Set with: export UPTIME_KUMA_API_KEY=your_api_key"
    fi

    # Validate JSON format
    if ! jq empty "$SERVICES_JSON" 2>/dev/null; then
        log_error "Invalid JSON in $SERVICES_JSON"
        exit 1
    fi
}

# Create monitor via API
create_monitor() {
    local name=$1
    local url=$2
    local type=${3:-https}
    local interval=${4:-300}

    log_info "Creating monitor: $name ($url)"

    if [ -z "$API_KEY" ]; then
        log_warning "API key not set, skipping API creation for $name"
        echo "$name|$url|$type|$interval" >> /tmp/uptime-kuma-pending.txt
        return 0
    fi

    local payload=$(cat <<EOF
{
    "type": "$type",
    "name": "$name",
    "url": "$url",
    "interval": $interval,
    "retryInterval": 30,
    "maxretries": 3,
    "timeout": 30,
    "active": true,
    "ignoreTls": false,
    "upsideDown": false,
    "accepted_statuscodes": ["200-299"]
}
EOF
    )

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$payload" \
        "$UPTIME_KUMA_URL/api/monitor" 2>&1)

    if echo "$response" | jq -e '.ok' &>/dev/null; then
        log_success "Created monitor: $name"
        return 0
    else
        log_error "Failed to create monitor: $name"
        log_error "Response: $response"
        return 1
    fi
}

# Configure monitors from JSON
configure_monitors() {
    local total=0
    local success=0
    local failed=0

    log_info "Reading services from $SERVICES_JSON"

    # Clear pending file
    > /tmp/uptime-kuma-pending.txt

    # Process aienablement.academy services
    log_info "Configuring aienablement.academy monitors..."
    while IFS= read -r service; do
        ((total++))
        if create_monitor "$service" "https://$service" "https" 300; then
            ((success++))
        else
            ((failed++))
        fi
    done < <(jq -r '.aienablement_academy[]' "$SERVICES_JSON")

    # Process harbor.fyi services
    log_info "Configuring harbor.fyi monitors..."
    while IFS= read -r service; do
        ((total++))
        if create_monitor "$service" "https://$service" "https" 300; then
            ((success++))
        else
            ((failed++))
        fi
    done < <(jq -r '.harbor_fyi[]' "$SERVICES_JSON")

    # Summary
    echo ""
    log_info "=== Monitor Configuration Summary ==="
    log_info "Total monitors: $total"
    log_success "Successfully configured: $success"
    [ $failed -gt 0 ] && log_error "Failed: $failed"

    # Show pending manual configuration
    if [ -s /tmp/uptime-kuma-pending.txt ]; then
        echo ""
        log_warning "The following monitors need manual configuration:"
        log_warning "(API key not set or API calls failed)"
        echo ""
        cat /tmp/uptime-kuma-pending.txt | while IFS='|' read -r name url type interval; do
            echo "  - Name: $name"
            echo "    URL: $url"
            echo "    Type: $type"
            echo "    Interval: ${interval}s"
            echo ""
        done
        log_info "Access Uptime Kuma at: $UPTIME_KUMA_URL"
    fi
}

# Add notification channels
configure_notifications() {
    log_info "Configuring notification channels..."

    if [ -z "$API_KEY" ]; then
        log_warning "API key not set, skipping notification configuration"
        log_info "Configure manually at: $UPTIME_KUMA_URL/settings/notifications"
        return 0
    fi

    # Email notification (Brevo)
    if [ -n "${BREVO_API_KEY:-}" ]; then
        log_info "Configuring email notifications via Brevo..."
        local email_payload=$(cat <<EOF
{
    "type": "smtp",
    "name": "Brevo Email Alerts",
    "host": "smtp-relay.brevo.com",
    "port": 587,
    "secure": false,
    "username": "${BREVO_SMTP_USER:-}",
    "password": "${BREVO_API_KEY}",
    "from": "alerts@aienablement.academy",
    "to": "ops@aienablement.academy"
}
EOF
        )

        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d "$email_payload" \
            "$UPTIME_KUMA_URL/api/notification" > /dev/null

        log_success "Email notifications configured"
    fi

    # Slack notification
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        log_info "Configuring Slack notifications..."
        local slack_payload=$(cat <<EOF
{
    "type": "slack",
    "name": "Slack Alerts",
    "webhookURL": "${SLACK_WEBHOOK_URL}",
    "channel": "#infrastructure-alerts"
}
EOF
        )

        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $API_KEY" \
            -d "$slack_payload" \
            "$UPTIME_KUMA_URL/api/notification" > /dev/null

        log_success "Slack notifications configured"
    fi
}

# Create status pages
create_status_pages() {
    log_info "Creating status pages..."

    if [ -z "$API_KEY" ]; then
        log_warning "API key not set, skipping status page creation"
        log_info "Create manually at: $UPTIME_KUMA_URL/status-page"
        return 0
    fi

    # Public status page for aienablement.academy
    log_info "Creating public status page for aienablement.academy..."
    local status_payload=$(cat <<EOF
{
    "slug": "aienablement",
    "title": "AI Enablement Academy Status",
    "description": "Status of all AI Enablement Academy services",
    "theme": "auto",
    "published": true,
    "showTags": true,
    "domainNameList": []
}
EOF
    )

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "$status_payload" \
        "$UPTIME_KUMA_URL/api/status-page" > /dev/null

    log_success "Status page created: $UPTIME_KUMA_URL/status/aienablement"
}

# Verify monitors are working
verify_monitors() {
    log_info "Verifying monitor configuration..."

    if [ -z "$API_KEY" ]; then
        log_warning "API key not set, skipping verification"
        return 0
    fi

    local monitors=$(curl -s -H "Authorization: Bearer $API_KEY" \
        "$UPTIME_KUMA_URL/api/monitor" | jq -r '.monitors[].name' 2>/dev/null || echo "")

    if [ -z "$monitors" ]; then
        log_warning "Could not retrieve monitor list"
        return 0
    fi

    local count=$(echo "$monitors" | wc -l)
    log_info "Active monitors: $count"

    echo "$monitors" | while read -r monitor; do
        echo "  - $monitor"
    done
}

# Main execution
main() {
    log_info "Uptime Kuma Monitor Setup"
    log_info "=========================="
    echo ""

    check_dependencies
    validate_config

    configure_monitors
    echo ""

    configure_notifications
    echo ""

    create_status_pages
    echo ""

    verify_monitors
    echo ""

    log_success "Monitor setup complete!"
    log_info "Access Uptime Kuma at: $UPTIME_KUMA_URL"
}

# Run main function
main "$@"
