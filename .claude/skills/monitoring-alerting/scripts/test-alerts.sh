#!/bin/bash
# Test Alert Notifications
# Sends test alerts to all configured channels

set -euo pipefail

# Configuration
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
BREVO_API_KEY="${BREVO_API_KEY:-}"
ALERT_EMAIL="${ALERT_EMAIL:-ops@aienablement.academy}"

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

# Test email via Brevo
test_email() {
    log_info "Testing email notifications..."

    if [ -z "$BREVO_API_KEY" ]; then
        log_warning "BREVO_API_KEY not set, skipping email test"
        return 0
    fi

    local payload=$(cat <<EOF
{
  "sender": {
    "email": "alerts@aienablement.academy",
    "name": "AI Enablement Academy Alerts"
  },
  "to": [
    {
      "email": "$ALERT_EMAIL",
      "name": "Operations Team"
    }
  ],
  "subject": "[TEST] Alert System Test",
  "htmlContent": "<html><body><h1>Test Alert</h1><p>This is a test alert from the monitoring system.</p><p><strong>Severity:</strong> INFO</p><p><strong>Time:</strong> $(date)</p><p>If you received this, email notifications are working correctly.</p></body></html>"
}
EOF
    )

    local response=$(curl -s -X POST \
        "https://api.brevo.com/v3/smtp/email" \
        -H "api-key: $BREVO_API_KEY" \
        -H "Content-Type: application/json" \
        -d "$payload")

    if echo "$response" | jq -e '.messageId' &>/dev/null; then
        log_success "Email test sent successfully"
        local message_id=$(echo "$response" | jq -r '.messageId')
        log_info "Message ID: $message_id"
        return 0
    else
        log_error "Email test failed"
        log_error "Response: $response"
        return 1
    fi
}

# Test Slack notification
test_slack() {
    log_info "Testing Slack notifications..."

    if [ -z "$SLACK_WEBHOOK_URL" ]; then
        log_warning "SLACK_WEBHOOK_URL not set, skipping Slack test"
        return 0
    fi

    local payload=$(cat <<EOF
{
  "text": ":white_check_mark: *Alert System Test*",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "Alert System Test"
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Severity:*\nINFO"
        },
        {
          "type": "mrkdwn",
          "text": "*Time:*\n$(date)"
        }
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "This is a test alert from the monitoring system. If you received this, Slack notifications are working correctly."
      }
    }
  ]
}
EOF
    )

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$SLACK_WEBHOOK_URL")

    if [ "$response" = "ok" ]; then
        log_success "Slack test sent successfully"
        return 0
    else
        log_error "Slack test failed"
        log_error "Response: $response"
        return 1
    fi
}

# Test Uptime Kuma notification
test_uptime_kuma() {
    log_info "Testing Uptime Kuma integration..."

    local uptime_kuma_url="${UPTIME_KUMA_URL:-https://uptime.aienablement.academy}"

    # Check if Uptime Kuma is accessible
    if curl -s -o /dev/null -w "%{http_code}" "$uptime_kuma_url" | grep -q "200"; then
        log_success "Uptime Kuma is accessible at $uptime_kuma_url"
        return 0
    else
        log_warning "Uptime Kuma not accessible at $uptime_kuma_url"
        return 1
    fi
}

# Test Netdata notification
test_netdata() {
    log_info "Testing Netdata integration..."

    local netdata_url="${NETDATA_URL:-https://monitor.aienablement.academy}"

    # Check if Netdata is accessible
    if curl -s "$netdata_url/api/v1/info" | jq -e '.version' &>/dev/null; then
        local version=$(curl -s "$netdata_url/api/v1/info" | jq -r '.version')
        log_success "Netdata is accessible at $netdata_url (version $version)"
        return 0
    else
        log_warning "Netdata not accessible at $netdata_url"
        return 1
    fi
}

# Test Dozzle integration
test_dozzle() {
    log_info "Testing Dozzle integration..."

    local dozzle_url="${DOZZLE_URL:-https://logs.aienablement.academy}"

    # Check if Dozzle is accessible
    if curl -s -o /dev/null -w "%{http_code}" "$dozzle_url/healthcheck" | grep -q "200"; then
        log_success "Dozzle is accessible at $dozzle_url"
        return 0
    else
        log_warning "Dozzle not accessible at $dozzle_url"
        return 1
    fi
}

# Test critical alert flow
test_critical_alert() {
    log_info "Testing CRITICAL alert flow..."

    local alert_message="[TEST CRITICAL] Service Down Simulation"
    local service_name="test-service"

    # Send to all channels
    local success=true

    # Email
    if [ -n "$BREVO_API_KEY" ]; then
        local email_payload=$(cat <<EOF
{
  "sender": {"email": "alerts@aienablement.academy", "name": "AI Enablement Academy Alerts"},
  "to": [{"email": "$ALERT_EMAIL", "name": "Operations Team"}],
  "subject": "[CRITICAL] $alert_message",
  "htmlContent": "<html><body><h1>CRITICAL Alert</h1><p><strong>Service:</strong> $service_name</p><p><strong>Status:</strong> DOWN</p><p><strong>Time:</strong> $(date)</p><p>This is a test of the critical alert flow.</p></body></html>"
}
EOF
        )

        curl -s -X POST \
            "https://api.brevo.com/v3/smtp/email" \
            -H "api-key: $BREVO_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$email_payload" > /dev/null || success=false
    fi

    # Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        local slack_payload=$(cat <<EOF
{
  "text": ":rotating_light: *CRITICAL ALERT* - $alert_message",
  "blocks": [
    {
      "type": "header",
      "text": {"type": "plain_text", "text": "CRITICAL ALERT"}
    },
    {
      "type": "section",
      "fields": [
        {"type": "mrkdwn", "text": "*Service:*\n$service_name"},
        {"type": "mrkdwn", "text": "*Status:*\nDOWN"},
        {"type": "mrkdwn", "text": "*Time:*\n$(date)"}
      ]
    },
    {
      "type": "section",
      "text": {"type": "mrkdwn", "text": "This is a test of the critical alert flow."}
    }
  ]
}
EOF
        )

        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$slack_payload" \
            "$SLACK_WEBHOOK_URL" > /dev/null || success=false
    fi

    if $success; then
        log_success "CRITICAL alert test completed"
        return 0
    else
        log_error "CRITICAL alert test failed"
        return 1
    fi
}

# Test warning alert flow
test_warning_alert() {
    log_info "Testing WARNING alert flow..."

    local alert_message="[TEST WARNING] High CPU Usage Simulation"

    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        local payload=$(cat <<EOF
{
  "text": ":warning: *WARNING* - $alert_message",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": ":warning: *WARNING Alert*\n\n*Message:* $alert_message\n*Time:* $(date)\n\nThis is a test of the warning alert flow."
      }
    }
  ]
}
EOF
        )

        curl -s -X POST \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$SLACK_WEBHOOK_URL" > /dev/null

        log_success "WARNING alert test completed"
        return 0
    else
        log_warning "SLACK_WEBHOOK_URL not set, skipping WARNING test"
        return 0
    fi
}

# Generate test report
generate_report() {
    echo ""
    log_info "=== Alert System Test Report ==="
    echo ""
    log_info "Notification Channels:"
    [ -n "$BREVO_API_KEY" ] && echo "  - Email (Brevo): Configured" || echo "  - Email (Brevo): Not configured"
    [ -n "$SLACK_WEBHOOK_URL" ] && echo "  - Slack: Configured" || echo "  - Slack: Not configured"
    echo ""
    log_info "Monitoring Systems:"
    echo "  - Uptime Kuma: ${UPTIME_KUMA_URL:-https://uptime.aienablement.academy}"
    echo "  - Netdata: ${NETDATA_URL:-https://monitor.aienablement.academy}"
    echo "  - Dozzle: ${DOZZLE_URL:-https://logs.aienablement.academy}"
    echo ""
    log_info "Test alerts sent. Check your configured channels."
}

# Main execution
main() {
    log_info "Alert System Test Script"
    log_info "========================="
    echo ""

    # Track results
    local tests_passed=0
    local tests_failed=0

    # Test notification channels
    test_email && ((tests_passed++)) || ((tests_failed++))
    echo ""
    test_slack && ((tests_passed++)) || ((tests_failed++))
    echo ""

    # Test monitoring integrations
    test_uptime_kuma && ((tests_passed++)) || ((tests_failed++))
    echo ""
    test_netdata && ((tests_passed++)) || ((tests_failed++))
    echo ""
    test_dozzle && ((tests_passed++)) || ((tests_failed++))
    echo ""

    # Test alert flows
    test_critical_alert && ((tests_passed++)) || ((tests_failed++))
    echo ""
    test_warning_alert && ((tests_passed++)) || ((tests_failed++))
    echo ""

    # Generate report
    generate_report
    echo ""

    # Summary
    log_info "=== Test Summary ==="
    log_success "Tests passed: $tests_passed"
    [ $tests_failed -gt 0 ] && log_error "Tests failed: $tests_failed" || log_info "Tests failed: 0"
    echo ""

    if [ $tests_failed -eq 0 ]; then
        log_success "All tests passed!"
        return 0
    else
        log_warning "Some tests failed. Review configuration."
        return 1
    fi
}

# Run main function
main "$@"
