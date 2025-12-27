#!/bin/bash
set -e

echo "🚀 GitHub Self-Hosted Runner Deployment Script"
echo "================================================"

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
    echo "   Required scopes: repo, workflow"
    exit 1
fi

if [ -z "$GITHUB_ORG_NAME" ] || [ "$GITHUB_ORG_NAME" == "YOUR_GITHUB_ORG_NAME" ]; then
    echo "❌ Error: GITHUB_ORG_NAME not configured in .env"
    echo "   Set to your GitHub organization name (e.g., AI-Enablement-Academy)"
    exit 1
fi

echo "✅ Environment configuration validated"

# Create cache directories
echo "📁 Creating cache directories..."
mkdir -p cache/bun cache/node_modules runner-data

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running"
    echo "   Please start Docker and try again"
    exit 1
fi

echo "✅ Docker is running"

# Pull latest images
echo "📥 Pulling latest runner image..."
docker compose pull

# Stop existing runner if running
if docker compose ps | grep -q "github-runner"; then
    echo "🛑 Stopping existing runner..."
    docker compose down
fi

# Start runner
echo "🚀 Starting GitHub runner..."
docker compose up -d

# Wait for runner to start
echo "⏳ Waiting for runner to connect..."
sleep 10

# Check status
if docker compose ps | grep -q "Up"; then
    echo "✅ Runner is running!"
    echo ""
    echo "📊 Status:"
    docker compose ps
    echo ""
    echo "📋 Logs (Ctrl+C to exit):"
    docker compose logs -f github-runner
else
    echo "❌ Runner failed to start"
    echo "📋 Logs:"
    docker compose logs
    exit 1
fi
