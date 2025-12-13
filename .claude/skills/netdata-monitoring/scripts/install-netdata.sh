#!/bin/bash
# Netdata Installation and Configuration Script
# Installs Netdata on target hosts and configures streaming to parent

set -euo pipefail

# Configuration
PARENT_HOST="${NETDATA_PARENT_HOST:-monitor.aienablement.academy}"
PARENT_API_KEY="${NETDATA_PARENT_API_KEY:-}"
INSTALL_METHOD="${1:-auto}"  # auto, docker, or native

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

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        log_error "Cannot detect OS"
        exit 1
    fi

    log_info "Detected OS: $OS $VERSION"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ] && [ "$INSTALL_METHOD" != "docker" ]; then
        log_error "Please run as root for native installation"
        log_info "Or use: $0 docker"
        exit 1
    fi
}

# Install Netdata via official kickstart script
install_native() {
    log_info "Installing Netdata (native)..."

    # Download and run kickstart script
    bash <(curl -Ss https://my-netdata.io/kickstart.sh) \
        --non-interactive \
        --stable-channel \
        --disable-telemetry

    log_success "Netdata installed successfully"
}

# Install Netdata via Docker
install_docker() {
    log_info "Installing Netdata (Docker)..."

    # Create volumes
    docker volume create netdata_config
    docker volume create netdata_lib
    docker volume create netdata_cache

    # Run Netdata container
    docker run -d \
        --name=netdata \
        --pid=host \
        --network=host \
        --restart=unless-stopped \
        --cap-add=SYS_PTRACE \
        --cap-add=SYS_ADMIN \
        --security-opt apparmor=unconfined \
        -v netdata_config:/etc/netdata \
        -v netdata_lib:/var/lib/netdata \
        -v netdata_cache:/var/cache/netdata \
        -v /etc/passwd:/host/etc/passwd:ro \
        -v /etc/group:/host/etc/group:ro \
        -v /etc/localtime:/etc/localtime:ro \
        -v /proc:/host/proc:ro \
        -v /sys:/host/sys:ro \
        -v /etc/os-release:/host/etc/os-release:ro \
        -v /var/log:/host/var/log:ro \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        netdata/netdata:stable

    log_success "Netdata Docker container started"
}

# Configure streaming to parent
configure_streaming() {
    log_info "Configuring streaming to parent: $PARENT_HOST"

    if [ -z "$PARENT_API_KEY" ]; then
        log_warning "NETDATA_PARENT_API_KEY not set"
        log_info "Generate one with: uuidgen"
        log_info "Skipping streaming configuration"
        return 0
    fi

    local stream_conf="/etc/netdata/stream.conf"

    if [ "$INSTALL_METHOD" = "docker" ]; then
        # Create config in Docker volume
        docker exec netdata sh -c "cat > $stream_conf" <<EOF
[stream]
    enabled = yes
    destination = $PARENT_HOST:19999
    api key = $PARENT_API_KEY
    timeout seconds = 60
    buffer size bytes = 1048576
    reconnect delay seconds = 5
    initial clock resync iterations = 60
EOF
    else
        # Create config on host
        cat > "$stream_conf" <<EOF
[stream]
    enabled = yes
    destination = $PARENT_HOST:19999
    api key = $PARENT_API_KEY
    timeout seconds = 60
    buffer size bytes = 1048576
    reconnect delay seconds = 5
    initial clock resync iterations = 60
EOF
    fi

    log_success "Streaming configured to $PARENT_HOST"
}

# Configure alerts
configure_alerts() {
    log_info "Configuring alert notifications..."

    local notify_conf="/etc/netdata/health_alarm_notify.conf"

    # Configure email alerts via Brevo
    if [ -n "${BREVO_API_KEY:-}" ]; then
        log_info "Configuring email alerts via Brevo..."

        if [ "$INSTALL_METHOD" = "docker" ]; then
            docker exec netdata sh -c "cat >> $notify_conf" <<EOF

# Email configuration (Brevo)
SEND_EMAIL="YES"
DEFAULT_RECIPIENT_EMAIL="ops@aienablement.academy"
EMAIL_SENDER="alerts@aienablement.academy"
SENDMAIL="/usr/sbin/sendmail"
SMTP_SERVER="smtp-relay.brevo.com:587"
SMTP_USERNAME="${BREVO_SMTP_USER:-}"
SMTP_PASSWORD="${BREVO_API_KEY}"
EOF
        else
            cat >> "$notify_conf" <<EOF

# Email configuration (Brevo)
SEND_EMAIL="YES"
DEFAULT_RECIPIENT_EMAIL="ops@aienablement.academy"
EMAIL_SENDER="alerts@aienablement.academy"
SENDMAIL="/usr/sbin/sendmail"
SMTP_SERVER="smtp-relay.brevo.com:587"
SMTP_USERNAME="${BREVO_SMTP_USER:-}"
SMTP_PASSWORD="${BREVO_API_KEY}"
EOF
        fi

        log_success "Email alerts configured"
    fi

    # Configure Slack alerts
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        log_info "Configuring Slack alerts..."

        if [ "$INSTALL_METHOD" = "docker" ]; then
            docker exec netdata sh -c "cat >> $notify_conf" <<EOF

# Slack configuration
SEND_SLACK="YES"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL}"
DEFAULT_RECIPIENT_SLACK="#infrastructure-alerts"
EOF
        else
            cat >> "$notify_conf" <<EOF

# Slack configuration
SEND_SLACK="YES"
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL}"
DEFAULT_RECIPIENT_SLACK="#infrastructure-alerts"
EOF
        fi

        log_success "Slack alerts configured"
    fi
}

# Configure performance settings
configure_performance() {
    log_info "Configuring performance settings..."

    local netdata_conf="/etc/netdata/netdata.conf"
    local memory_mode="${NETDATA_MEMORY_MODE:-ram}"
    local history="${NETDATA_HISTORY:-3600}"  # 1 hour default
    local update_every="${NETDATA_UPDATE_EVERY:-1}"

    if [ "$INSTALL_METHOD" = "docker" ]; then
        docker exec netdata sh -c "cat > $netdata_conf" <<EOF
[global]
    update every = $update_every
    memory mode = $memory_mode
    history = $history

[web]
    bind to = *
    allow connections from = *
    allow dashboard from = *
    enable gzip compression = yes

[plugins]
    cgroups = yes
    tc = no
    idlejitter = no
    apps = yes
    proc = yes
    diskspace = yes

[plugin:proc:diskspace]
    update every = 10
    check for new mount points every = 60

[plugin:apps]
    update every = 5
EOF
    else
        cat > "$netdata_conf" <<EOF
[global]
    update every = $update_every
    memory mode = $memory_mode
    history = $history

[web]
    bind to = *
    allow connections from = *
    allow dashboard from = *
    enable gzip compression = yes

[plugins]
    cgroups = yes
    tc = no
    idlejitter = no
    apps = yes
    proc = yes
    diskspace = yes

[plugin:proc:diskspace]
    update every = 10
    check for new mount points every = 60

[plugin:apps]
    update every = 5
EOF
    fi

    log_success "Performance settings configured"
}

# Restart Netdata
restart_netdata() {
    log_info "Restarting Netdata..."

    if [ "$INSTALL_METHOD" = "docker" ]; then
        docker restart netdata
    else
        systemctl restart netdata
    fi

    sleep 5

    if [ "$INSTALL_METHOD" = "docker" ]; then
        if docker ps | grep -q netdata; then
            log_success "Netdata is running (Docker)"
        else
            log_error "Netdata failed to start"
            return 1
        fi
    else
        if systemctl is-active --quiet netdata; then
            log_success "Netdata is running (systemd)"
        else
            log_error "Netdata failed to start"
            return 1
        fi
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying Netdata installation..."

    # Check if Netdata is responding
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s http://localhost:19999/api/v1/info > /dev/null 2>&1; then
            log_success "Netdata is responding on port 19999"
            break
        fi

        log_info "Waiting for Netdata to start (attempt $attempt/$max_attempts)..."
        sleep 3
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_error "Netdata is not responding after $max_attempts attempts"
        return 1
    fi

    # Show version
    local version=$(curl -s http://localhost:19999/api/v1/info | jq -r '.version' 2>/dev/null || echo "unknown")
    log_info "Netdata version: $version"

    # Show hostname
    local hostname=$(curl -s http://localhost:19999/api/v1/info | jq -r '.hostname' 2>/dev/null || echo "unknown")
    log_info "Monitoring hostname: $hostname"
}

# Main execution
main() {
    log_info "Netdata Installation Script"
    log_info "============================"
    echo ""

    detect_os

    if [ "$INSTALL_METHOD" = "auto" ]; then
        # Auto-detect best method
        if command -v docker &> /dev/null; then
            INSTALL_METHOD="docker"
            log_info "Docker detected, using Docker installation"
        else
            INSTALL_METHOD="native"
            log_info "Using native installation"
            check_root
        fi
    fi

    # Install Netdata
    if [ "$INSTALL_METHOD" = "docker" ]; then
        install_docker
    else
        install_native
    fi

    echo ""
    configure_performance
    echo ""
    configure_streaming
    echo ""
    configure_alerts
    echo ""
    restart_netdata
    echo ""
    verify_installation
    echo ""

    log_success "Netdata installation complete!"
    log_info "Dashboard: http://localhost:19999"
    log_info "Parent: $PARENT_HOST"
}

# Run main function
main "$@"
