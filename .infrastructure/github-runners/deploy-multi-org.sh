#!/bin/bash
set -e

echo "🚀 Multi-Organization GitHub Runner Deployment"
echo "=============================================="
echo ""
echo "This will deploy 4 self-hosted runners:"
echo "  1. AI-Enablement-Academy (org)"
echo "  2. OPEN-Talent-Society (org)"
echo "  3. The-Talent-Foundation (org)"
echo "  4. adambkovacs (personal)"
echo ""

# Check if .env exists
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "📝 Please copy .env.example to .env and configure it:"
    echo "   cp .env.example .env"
    echo "   nano .env"
    exit 1
fi

# Source .env
source .env

# Validate required variables
if [ -z "$GITHUB_PAT" ] || [ "$GITHUB_PAT" == "ghp_your_personal_access_token_here" ]; then
    echo "❌ Error: GITHUB_PAT not configured in .env"
    echo "📝 Generate a PAT at: https://github.com/settings/tokens/new"
    echo "   Required scopes: repo, workflow, admin:org"
    exit 1
fi

echo "✅ Environment configuration validated"

# Create cache and data directories for each runner
echo "📁 Creating cache and data directories..."
mkdir -p cache/bun cache/node_modules
mkdir -p runner-data/aea runner-data/ots runner-data/ttf runner-data/personal

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "   Please start Docker and try again"
    exit 1
fi

echo "✅ Docker is running"

# Pull latest images
echo "📥 Pulling latest runner image..."
docker compose -f docker-compose.multi-org.yml pull

# Stop existing runners if running
if docker compose -f docker-compose.multi-org.yml ps | grep -q "Up"; then
    echo "🛑 Stopping existing runners..."
    docker compose -f docker-compose.multi-org.yml down
fi

# Start all runners
echo "🚀 Starting all GitHub runners..."
docker compose -f docker-compose.multi-org.yml up -d

# Wait for runners to start
echo "⏳ Waiting for runners to connect..."
sleep 15

# Check status
echo ""
echo "📊 Runner Status:"
echo "================"
docker compose -f docker-compose.multi-org.yml ps

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Verify runners at:"
echo "  - AI-Enablement-Academy: https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners"
echo "  - OPEN-Talent-Society: https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners"
echo "  - The-Talent-Foundation: https://github.com/organizations/The-Talent-Foundation/settings/actions/runners"
echo "  - Personal: https://github.com/adambkovacs?tab=repositories (runner settings)"
echo ""
echo "📈 View logs:"
echo "  docker compose -f docker-compose.multi-org.yml logs -f"
echo ""
echo "🔄 Restart a specific runner:"
echo "  docker compose -f docker-compose.multi-org.yml restart runner-aea"
echo "  docker compose -f docker-compose.multi-org.yml restart runner-ots"
echo "  docker compose -f docker-compose.multi-org.yml restart runner-ttf"
echo "  docker compose -f docker-compose.multi-org.yml restart runner-personal"
