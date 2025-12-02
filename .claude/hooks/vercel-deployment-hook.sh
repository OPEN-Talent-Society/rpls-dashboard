#!/bin/bash
# Vercel Deployment Hook
# Automatically deploys to Vercel when triggered

# Configuration
DEPLOY_TARGET="${VERCEL_DEPLOY_TARGET:-preview}"  # preview or production
AUTO_VERIFY="${VERCEL_AUTO_VERIFY:-true}"

echo "[vercel-hook] Deployment hook triggered"
echo "[vercel-hook] Target: $DEPLOY_TARGET"

# Check if Vercel CLI is available
if ! command -v vercel &> /dev/null; then
    echo "[vercel-hook] Vercel CLI not found, attempting install..."
    pnpm add -g vercel 2>/dev/null || {
        echo "[vercel-hook] Failed to install Vercel CLI"
        exit 1
    }
fi

# Check if project is linked
if [ ! -f ".vercel/project.json" ]; then
    echo "[vercel-hook] Project not linked to Vercel, skipping deployment"
    exit 0
fi

# Build deployment command
DEPLOY_CMD="vercel"
if [ "$DEPLOY_TARGET" == "production" ]; then
    DEPLOY_CMD="vercel --prod"
fi

# Execute deployment
echo "[vercel-hook] Starting deployment..."
DEPLOY_OUTPUT=$($DEPLOY_CMD 2>&1)
DEPLOY_URL=$(echo "$DEPLOY_OUTPUT" | grep -E "https://" | tail -1)

if [ -z "$DEPLOY_URL" ]; then
    echo "[vercel-hook] Deployment failed"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo "[vercel-hook] Deployed to: $DEPLOY_URL"

# Verify deployment if enabled
if [ "$AUTO_VERIFY" == "true" ]; then
    echo "[vercel-hook] Verifying deployment..."
    sleep 10  # Wait for deployment to be ready

    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$DEPLOY_URL/api/health" 2>/dev/null || echo "000")

    if [ "$HTTP_STATUS" == "200" ]; then
        echo "[vercel-hook] ✅ Health check passed"
    else
        echo "[vercel-hook] ⚠️ Health check returned HTTP $HTTP_STATUS"
    fi
fi

echo "[vercel-hook] Deployment complete"

# Export URL for other hooks/scripts
export VERCEL_DEPLOYMENT_URL="$DEPLOY_URL"
