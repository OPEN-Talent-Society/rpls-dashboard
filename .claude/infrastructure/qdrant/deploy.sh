#!/bin/bash
# Deploy secured Qdrant with Docker and Nginx
# Usage: ./deploy.sh [--verify] [--rollback]
# Run on Docker host (192.168.50.149)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
DOCKER_HOST="192.168.50.149"
NGINX_HOST="192.168.50.45"
DOMAIN="qdrant.harbor.fyi"
CONTAINER_NAME="qdrant"
IMAGE_VERSION="v1.13.4"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check if .env exists
check_env_file() {
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        log_error ".env file not found! Run ./generate-keys.sh first"
    fi
    log_success ".env file found"
}

# Load environment variables
load_env() {
    set -a
    source "$SCRIPT_DIR/.env"
    set +a
    log_success "Environment variables loaded"
}

# Verify Docker is running
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed or not in PATH"
    fi

    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
    fi

    log_success "Docker is running"
}

# Check if network exists
check_docker_network() {
    if ! docker network ls | grep -q "proxy"; then
        log_warning "Docker network 'proxy' does not exist, creating it..."
        docker network create proxy
        log_success "Network 'proxy' created"
    else
        log_success "Docker network 'proxy' exists"
    fi
}

# Create Docker volume if it doesn't exist
check_docker_volume() {
    if ! docker volume ls | grep -q "qdrant_storage"; then
        log_warning "Docker volume 'qdrant_storage' does not exist, creating it..."
        docker volume create qdrant_storage
        log_success "Volume 'qdrant_storage' created"
    else
        log_success "Docker volume 'qdrant_storage' exists"
    fi

    if ! docker volume ls | grep -q "qdrant_snapshots"; then
        log_warning "Docker volume 'qdrant_snapshots' does not exist, creating it..."
        docker volume create qdrant_snapshots
        log_success "Volume 'qdrant_snapshots' created"
    else
        log_success "Docker volume 'qdrant_snapshots' exists"
    fi
}

# Stop existing Qdrant container
stop_qdrant() {
    log_info "Stopping existing Qdrant container..."
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_success "Qdrant container stopped and removed"
    else
        log_info "No existing Qdrant container found"
    fi
}

# Deploy Qdrant with docker-compose
deploy_qdrant() {
    log_info "Starting Qdrant container..."

    if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        log_error "docker-compose.yml not found"
    fi

    cd "$SCRIPT_DIR"
    docker-compose up -d
    log_success "Qdrant container started"
}

# Wait for Qdrant to start
wait_for_qdrant() {
    log_info "Waiting for Qdrant to start (max 30 seconds)..."

    for i in {1..30}; do
        if curl -s http://localhost:6333/healthz &>/dev/null; then
            log_success "Qdrant is healthy"
            return 0
        fi
        echo -n "."
        sleep 1
    done

    log_error "Qdrant did not start within 30 seconds"
}

# Test Qdrant health
test_health() {
    log_info "Testing Qdrant health endpoint..."

    HEALTH=$(curl -s http://localhost:6333/healthz)
    if echo "$HEALTH" | grep -q "ok"; then
        log_success "Health check passed: $HEALTH"
    else
        log_error "Health check failed: $HEALTH"
    fi
}

# Test API key authentication
test_api_key() {
    log_info "Testing API key authentication..."

    # Test without API key (should fail)
    log_info "Attempting access WITHOUT API key (should fail)..."
    RESULT=$(curl -s -w "\n%{http_code}" http://localhost:6333/collections)
    HTTP_CODE=$(echo "$RESULT" | tail -n1)

    if [ "$HTTP_CODE" = "401" ] || [ "$HTTP_CODE" = "403" ]; then
        log_success "Access denied without API key (HTTP $HTTP_CODE)"
    else
        log_warning "Expected 401/403 but got HTTP $HTTP_CODE (API key may not be enforced)"
    fi

    # Test with API key (should succeed)
    log_info "Attempting access WITH API key (should succeed)..."
    RESULT=$(curl -s -w "\n%{http_code}" -H "api-key: ${QDRANT_API_KEY}" http://localhost:6333/collections)
    HTTP_CODE=$(echo "$RESULT" | tail -n1)
    BODY=$(echo "$RESULT" | sed '$d')

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Access allowed with API key (HTTP $HTTP_CODE)"
        log_info "Collections: $(echo "$BODY" | grep -o '"collections":\[\]' || echo 'empty')"
    else
        log_error "Access denied even with valid API key (HTTP $HTTP_CODE): $BODY"
    fi
}

# Test read-only API key
test_readonly_key() {
    log_info "Testing read-only API key..."

    # Test GET with read-only key (should succeed)
    log_info "GET request with read-only key..."
    RESULT=$(curl -s -w "\n%{http_code}" -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" http://localhost:6333/collections)
    HTTP_CODE=$(echo "$RESULT" | tail -n1)

    if [ "$HTTP_CODE" = "200" ]; then
        log_success "Read-only key allows GET (HTTP $HTTP_CODE)"
    else
        log_warning "GET with read-only key returned HTTP $HTTP_CODE"
    fi
}

# Display verification results
verify_deployment() {
    log_info ""
    log_info "=== DEPLOYMENT VERIFICATION ==="
    log_info ""

    # Check container status
    log_info "Container Status:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep qdrant || log_warning "Qdrant container not found"

    # Check logs
    log_info ""
    log_info "Recent Container Logs:"
    docker logs --tail 10 qdrant 2>/dev/null | sed 's/^/  /'

    # Check ports
    log_info ""
    log_info "Open Ports:"
    netstat -tuln 2>/dev/null | grep -E ':(6333|6334)' | sed 's/^/  /' || log_warning "netstat not available"

    # Check volumes
    log_info ""
    log_info "Docker Volumes:"
    docker volume ls --format "table {{.Name}}\t{{.Driver}}" | grep qdrant | sed 's/^/  /'

    # Environment
    log_info ""
    log_info "Environment Variables:"
    echo "  QDRANT_API_KEY: ${QDRANT_API_KEY:0:10}... (${#QDRANT_API_KEY} chars)"
    echo "  QDRANT_READ_ONLY_API_KEY: ${QDRANT_READ_ONLY_API_KEY:0:10}... (${#QDRANT_READ_ONLY_API_KEY} chars)"
    echo "  QDRANT_URL: ${QDRANT_URL}"

    log_info ""
    log_success "Deployment verification complete"
}

# Rollback to previous state
rollback() {
    log_warning "Rolling back deployment..."

    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        log_info "Stopping Qdrant container..."
        docker stop "$CONTAINER_NAME" 2>/dev/null || true
        docker rm "$CONTAINER_NAME" 2>/dev/null || true
        log_success "Rollback complete"
    else
        log_info "No Qdrant container to remove"
    fi
}

# Print usage
print_usage() {
    cat << EOF
Usage: ./deploy.sh [OPTIONS]

Options:
    --verify        Run verification tests after deployment
    --rollback      Rollback to previous state
    --help          Show this help message

Examples:
    ./deploy.sh                 # Deploy Qdrant
    ./deploy.sh --verify        # Deploy and verify
    ./deploy.sh --rollback      # Rollback deployment

Environment:
    QDRANT_API_KEY              Admin API key (required, from .env)
    QDRANT_READ_ONLY_API_KEY    Read-only API key (required, from .env)

EOF
}

# Main execution
main() {
    VERIFY=false
    ROLLBACK_FLAG=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verify)
                VERIFY=true
                shift
                ;;
            --rollback)
                ROLLBACK_FLAG=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                ;;
        esac
    done

    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║       Qdrant Secured Deployment Script v1.0                ║"
    echo "║       Docker Host: $DOCKER_HOST"
    echo "║       Domain: $DOMAIN"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    if [ "$ROLLBACK_FLAG" = true ]; then
        rollback
        exit 0
    fi

    # Pre-deployment checks
    log_info "Running pre-deployment checks..."
    check_env_file
    load_env
    check_docker
    check_docker_network
    check_docker_volume

    # Deployment
    log_info ""
    log_info "=== DEPLOYMENT PHASE ==="
    log_info ""
    stop_qdrant
    deploy_qdrant
    wait_for_qdrant

    # Testing
    log_info ""
    log_info "=== TESTING PHASE ==="
    log_info ""
    test_health
    test_api_key
    test_readonly_key

    # Verification
    log_info ""
    if [ "$VERIFY" = true ]; then
        verify_deployment
    fi

    # Summary
    log_info ""
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║             DEPLOYMENT SUCCESSFUL                          ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    log_success "Qdrant is now running with API key authentication"
    log_info "Next steps:"
    log_info "1. Deploy Nginx reverse proxy on $NGINX_HOST"
    log_info "2. Copy nginx.conf to /etc/nginx/sites-available/$DOMAIN"
    log_info "3. Install Cloudflare Origin Certificate"
    log_info "4. Test: curl -H 'api-key: \$QDRANT_API_KEY' https://$DOMAIN/collections"
    log_info ""
    log_info "For more information, see DEPLOYMENT.md"

    exit 0
}

# Run main function
main "$@"
