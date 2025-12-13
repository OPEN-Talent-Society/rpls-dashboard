#!/bin/bash
# Dozzle Deployment Script
# Deploys Dozzle for Docker log aggregation

set -euo pipefail

# Configuration
DOZZLE_PORT="${DOZZLE_PORT:-8080}"
DOZZLE_DATA_DIR="${DOZZLE_DATA_DIR:-/opt/dozzle/data}"
DOZZLE_PASSWORD="${DOZZLE_PASSWORD:-}"
DOZZLE_USERNAME="${DOZZLE_USERNAME:-admin}"
REMOTE_HOSTS="${DOZZLE_REMOTE_HOSTS:-}"

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
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    log_info "Docker version: $(docker --version)"
}

# Create data directory
create_data_dir() {
    log_info "Creating data directory: $DOZZLE_DATA_DIR"

    mkdir -p "$DOZZLE_DATA_DIR"
    chmod 755 "$DOZZLE_DATA_DIR"

    log_success "Data directory created"
}

# Generate password if not set
generate_password() {
    if [ -z "$DOZZLE_PASSWORD" ]; then
        log_warning "DOZZLE_PASSWORD not set, generating random password..."
        DOZZLE_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        log_success "Generated password: $DOZZLE_PASSWORD"
        log_warning "Save this password! Add to .env: DOZZLE_PASSWORD=$DOZZLE_PASSWORD"
        echo "DOZZLE_PASSWORD=$DOZZLE_PASSWORD" >> /tmp/dozzle-password.txt
    fi
}

# Create Docker Compose file
create_compose_file() {
    log_info "Creating Docker Compose configuration..."

    local compose_file="$DOZZLE_DATA_DIR/docker-compose.yml"

    # Build remote hosts string
    local remote_hosts_config=""
    if [ -n "$REMOTE_HOSTS" ]; then
        remote_hosts_config="DOZZLE_REMOTE_HOST: |"
        IFS=',' read -ra HOSTS <<< "$REMOTE_HOSTS"
        for host in "${HOSTS[@]}"; do
            remote_hosts_config="$remote_hosts_config\n        $host"
        done
    fi

    cat > "$compose_file" <<EOF
version: '3.8'

services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "$DOZZLE_PORT:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - $DOZZLE_DATA_DIR:/data
    environment:
      DOZZLE_LEVEL: info
      DOZZLE_TAILSIZE: 300
      DOZZLE_FILTER: "status=running"
      DOZZLE_AUTH_PROVIDER: simple
      DOZZLE_AUTH_USERNAME: $DOZZLE_USERNAME
      DOZZLE_AUTH_PASSWORD: $DOZZLE_PASSWORD
      DOZZLE_ENABLE_ACTIONS: true
      DOZZLE_NO_ANALYTICS: true
$([ -n "$remote_hosts_config" ] && echo "      $remote_hosts_config" || echo "")
    networks:
      - monitoring
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
      - "monitoring=true"

networks:
  monitoring:
    name: monitoring
    driver: bridge
EOF

    log_success "Docker Compose file created: $compose_file"
}

# Create reverse proxy config (Caddy)
create_reverse_proxy_config() {
    log_info "Creating reverse proxy configuration..."

    local caddy_config="/opt/caddy/config/Caddyfile.d/dozzle.caddy"

    mkdir -p "$(dirname "$caddy_config")"

    cat > "$caddy_config" <<EOF
# Dozzle Log Viewer
logs.aienablement.academy {
    reverse_proxy dozzle:8080

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
    }

    # Rate limiting
    rate_limit {
        zone dozzle {
            key {remote_host}
            events 30
            window 1m
        }
    }

    # Logging
    log {
        output file /var/log/caddy/dozzle-access.log
        format json
    }
}
EOF

    log_success "Reverse proxy config created: $caddy_config"
    log_info "Reload Caddy to apply: docker exec caddy caddy reload --config /etc/caddy/Caddyfile"
}

# Deploy Dozzle
deploy_dozzle() {
    log_info "Deploying Dozzle..."

    cd "$DOZZLE_DATA_DIR"

    # Stop existing container
    if docker ps -a | grep -q dozzle; then
        log_info "Stopping existing Dozzle container..."
        docker compose down
    fi

    # Pull latest image
    log_info "Pulling latest Dozzle image..."
    docker compose pull

    # Start container
    log_info "Starting Dozzle container..."
    docker compose up -d

    log_success "Dozzle deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying Dozzle deployment..."

    # Wait for container to start
    sleep 5

    # Check if container is running
    if ! docker ps | grep -q dozzle; then
        log_error "Dozzle container is not running"
        log_info "Check logs with: docker logs dozzle"
        return 1
    fi

    log_success "Dozzle container is running"

    # Check if API is responding
    local max_attempts=10
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$DOZZLE_PORT/healthcheck" | grep -q "200"; then
            log_success "Dozzle API is responding"
            break
        fi

        log_info "Waiting for Dozzle API (attempt $attempt/$max_attempts)..."
        sleep 3
        ((attempt++))
    done

    if [ $attempt -gt $max_attempts ]; then
        log_warning "Dozzle API not responding, but container is running"
        log_info "Check logs with: docker logs dozzle"
    fi

    # Show container stats
    log_info "Container stats:"
    docker stats --no-stream dozzle | tail -n 1
}

# Show access information
show_access_info() {
    echo ""
    log_info "=== Dozzle Access Information ==="
    log_info "Local URL: http://localhost:$DOZZLE_PORT"
    log_info "Username: $DOZZLE_USERNAME"

    if [ -f /tmp/dozzle-password.txt ]; then
        log_warning "Password saved to: /tmp/dozzle-password.txt"
        log_warning "Add to .env and delete the temp file!"
    fi

    echo ""
    log_info "After configuring reverse proxy:"
    log_info "Public URL: https://logs.aienablement.academy"
    echo ""
    log_info "View logs with: docker logs -f dozzle"
}

# Configure Cloudflare DNS (if cloudflare-dns skill available)
configure_dns() {
    if [ -f /Users/adamkovacs/Documents/codebuild/.claude/skills/cloudflare-dns/scripts/add-record.sh ]; then
        log_info "Configuring Cloudflare DNS record..."

        /Users/adamkovacs/Documents/codebuild/.claude/skills/cloudflare-dns/scripts/add-record.sh \
            "logs" \
            "A" \
            "$(curl -s ifconfig.me)" \
            "true" || log_warning "DNS configuration failed (manual setup required)"
    else
        log_info "Manual DNS setup required:"
        log_info "Add A record: logs.aienablement.academy -> $(curl -s ifconfig.me 2>/dev/null || echo 'YOUR_IP')"
    fi
}

# Setup log rotation
setup_log_rotation() {
    log_info "Setting up log rotation..."

    # Configure Docker log rotation
    local daemon_json="/etc/docker/daemon.json"

    if [ -f "$daemon_json" ]; then
        log_info "Docker daemon.json exists, check log rotation settings"
    else
        log_warning "Docker daemon.json not found, creating with log rotation..."

        cat > "$daemon_json" <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

        log_info "Restart Docker daemon to apply: systemctl restart docker"
    fi
}

# Main execution
main() {
    log_info "Dozzle Deployment Script"
    log_info "========================="
    echo ""

    check_dependencies
    echo ""

    create_data_dir
    echo ""

    generate_password
    echo ""

    create_compose_file
    echo ""

    deploy_dozzle
    echo ""

    verify_deployment
    echo ""

    setup_log_rotation
    echo ""

    create_reverse_proxy_config
    echo ""

    configure_dns
    echo ""

    show_access_info
    echo ""

    log_success "Dozzle deployment complete!"
}

# Run main function
main "$@"
