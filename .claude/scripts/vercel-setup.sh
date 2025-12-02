#!/bin/bash
# Vercel Integration Setup Script
# Configures Vercel for development and production

set -e

echo "=== Vercel Integration Setup ==="
echo ""

# Check for Vercel CLI
if ! command -v vercel &> /dev/null; then
    echo "Installing Vercel CLI..."
    pnpm add -g vercel
fi

# Check CLI version
echo "Vercel CLI version: $(vercel --version)"
echo ""

# Login to Vercel
echo "=== Authentication ==="
if vercel whoami &> /dev/null; then
    echo "[✓] Already logged in as: $(vercel whoami)"
else
    echo "Logging in to Vercel..."
    vercel login
fi

echo ""

# Link project
echo "=== Project Setup ==="
if [ -f ".vercel/project.json" ]; then
    PROJECT_ID=$(cat .vercel/project.json | jq -r '.projectId')
    echo "[✓] Project already linked: $PROJECT_ID"
else
    echo "Linking project to Vercel..."
    vercel link
fi

echo ""

# Check environment variables
echo "=== Environment Check ==="

# Check for VERCEL_TOKEN
if [ -z "$VERCEL_TOKEN" ]; then
    echo "[!] VERCEL_TOKEN not set in environment"
    echo "    Add to .env.local: VERCEL_TOKEN=<your-token>"
    echo "    Get token from: https://vercel.com/account/tokens"
else
    echo "[✓] VERCEL_TOKEN is set"
fi

# Pull environment variables
echo ""
echo "=== Pull Environment Variables ==="
if vercel env pull .env.local --yes 2>/dev/null; then
    echo "[✓] Environment variables pulled to .env.local"
else
    echo "[!] Could not pull environment variables"
    echo "    You may need to configure them in the Vercel dashboard"
fi

echo ""

# Check for required env vars
echo "=== Required Variables ==="

check_env() {
    if grep -q "^$1=" .env.local 2>/dev/null; then
        echo "[✓] $1"
    else
        echo "[!] $1 - not found"
    fi
}

check_env "DATABASE_URL"
check_env "NEXTAUTH_SECRET"
check_env "PAYLOAD_SECRET"
check_env "BREVO_API_KEY"
check_env "NEXT_PUBLIC_APP_URL"

echo ""

# Show project configuration
echo "=== Project Configuration ==="
if [ -f ".vercel/project.json" ]; then
    cat .vercel/project.json | jq '.'
fi

echo ""

# Test deployment (optional)
echo "=== Deployment Test ==="
read -p "Would you like to create a preview deployment? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Creating preview deployment..."
    vercel

    echo ""
    echo "✅ Preview deployment created!"
    echo ""
    echo "To deploy to production, run:"
    echo "  vercel --prod"
else
    echo "Skipping deployment test."
    echo ""
    echo "To deploy manually:"
    echo "  vercel          # Preview deployment"
    echo "  vercel --prod   # Production deployment"
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "1. Configure custom domain: vercel domains add <domain>"
echo "2. Set up environment variables in Vercel dashboard"
echo "3. Deploy to production: vercel --prod"
echo ""
echo "Useful commands:"
echo "  vercel ls              - List deployments"
echo "  vercel logs <url>      - View logs"
echo "  vercel env ls          - List env vars"
echo "  vercel domains ls      - List domains"
