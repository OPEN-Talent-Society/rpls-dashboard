#!/bin/bash
set -e

echo "🚀 Multi-Organization GitHub Runner Deployment"
echo "=============================================="
echo ""
echo "This will deploy 4 optimized self-hosted runners with:"
echo "  - Node.js 20 LTS"
echo "  - Bun"
echo "  - Playwright (with browsers)"
echo "  - Lighthouse CI"
echo "  - pnpm"
echo ""
echo "Organizations:"
echo "  1. AI-Enablement-Academy (org)"
echo "  2. OPEN-Talent-Society (org)"
echo "  3. The-Talent-Foundation (org)"
echo "  4. adambkovacs (personal)"
echo ""

# Parse arguments
BUILD_ONLY=false
SKIP_BUILD=false
for arg in "$@"; do
    case $arg in
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
    esac
done

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "📝 Please copy .env.example to .env and configure it:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi

# Source .env - handle macOS zsh compatibility
set -a
while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "$key" ]] && continue
    # Remove quotes from value
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    export "$key=$value"
done < .env
set +a

# Validate required variables
if [ -z "$GITHUB_PAT" ] || [ "$GITHUB_PAT" == "ghp_your_personal_access_token_here" ]; then
    echo "❌ Error: GITHUB_PAT not configured in .env"
    echo "📝 Generate a PAT at: https://github.com/settings/tokens/new"
    echo "   Required scopes: repo, workflow, admin:org"
    exit 1
fi

echo "✅ Environment configuration validated"

# Create cache and data directories
echo "📁 Creating cache and data directories..."
mkdir -p cache/bun cache/npm cache/pnpm cache/playwright
mkdir -p runner-data/aea runner-data/ots runner-data/ttf runner-data/personal

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "   Please start Docker and try again"
    exit 1
fi

echo "✅ Docker is running"

# Build custom image (unless skipped)
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "🔨 Building optimized runner image..."
    echo "   (This may take 5-10 minutes on first build)"
    echo ""

    docker compose -f docker-compose.multi-org.yml build --progress=plain

    echo ""
    echo "✅ Image built successfully"

    # Show image info
    echo ""
    echo "📦 Image details:"
    docker images github-runner-optimized:latest --format "   Size: {{.Size}} | Created: {{.CreatedSince}}"
fi

if [ "$BUILD_ONLY" = true ]; then
    echo ""
    echo "✅ Build complete (--build-only mode)"
    exit 0
fi

# Stop existing runners if running
if docker compose -f docker-compose.multi-org.yml ps 2>/dev/null | grep -q "Up"; then
    echo ""
    echo "🛑 Stopping existing runners..."
    docker compose -f docker-compose.multi-org.yml down
fi

# Start all runners
echo ""
echo "🚀 Starting all GitHub runners..."
docker compose -f docker-compose.multi-org.yml up -d

# Wait for runners to connect
echo "⏳ Waiting for runners to connect (30s)..."
sleep 30

# Check status
echo ""
echo "📊 Runner Status:"
echo "================"
docker compose -f docker-compose.multi-org.yml ps

# Verify tools in one runner
echo ""
echo "🔧 Verifying pre-installed tools (runner-aea):"
docker exec github-runner-aea sh -c '
echo "   Node.js: $(node --version)"
echo "   npm:     $(npm --version)"
echo "   pnpm:    $(pnpm --version)"
echo "   Bun:     $(bun --version)"
echo "   LHCI:    $(lhci --version)"
' 2>/dev/null || echo "   (Waiting for runner to fully start...)"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Verify runners at:"
echo "  - AI-Enablement-Academy: https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners"
echo "  - OPEN-Talent-Society: https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners"
echo "  - The-Talent-Foundation: https://github.com/organizations/The-Talent-Foundation/settings/actions/runners"
echo "  - Personal: https://github.com/settings/actions/runners"
echo ""
echo "🏷️  New runner labels available in workflows:"
echo "   runs-on: [self-hosted, node20, playwright, lighthouse]"
echo ""
echo "📈 View logs:"
echo "   docker compose -f docker-compose.multi-org.yml logs -f"
echo ""
echo "🔄 Restart a specific runner:"
echo "   docker compose -f docker-compose.multi-org.yml restart runner-aea"
echo ""
echo "🔨 Rebuild image (after Dockerfile changes):"
echo "   ./deploy-multi-org.sh  # Full rebuild + deploy"
echo "   ./deploy-multi-org.sh --skip-build  # Skip rebuild"
echo "   ./deploy-multi-org.sh --build-only  # Build only, no deploy"
