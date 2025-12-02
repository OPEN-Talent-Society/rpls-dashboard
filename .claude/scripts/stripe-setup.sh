#!/bin/bash
# Stripe Integration Setup Script
# Configures Stripe for development and production

set -e

echo "=== Stripe Integration Setup ==="
echo ""

# Check for Stripe CLI
if ! command -v stripe &> /dev/null; then
    echo "Installing Stripe CLI..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install stripe/stripe-cli/stripe
    else
        echo "Please install Stripe CLI: https://stripe.com/docs/stripe-cli"
        exit 1
    fi
fi

# Login to Stripe
echo "Logging in to Stripe..."
stripe login

# Get account info
echo ""
echo "=== Account Info ==="
stripe config --list

# Check for required environment variables
echo ""
echo "=== Environment Check ==="

if [ -z "$STRIPE_SECRET_KEY" ]; then
    echo "[!] STRIPE_SECRET_KEY not set"
    echo "    Add to .env.local: STRIPE_SECRET_KEY=sk_test_xxx"
else
    echo "[✓] STRIPE_SECRET_KEY is set"
fi

if [ -z "$STRIPE_PUBLISHABLE_KEY" ]; then
    echo "[!] STRIPE_PUBLISHABLE_KEY not set"
    echo "    Add to .env.local: STRIPE_PUBLISHABLE_KEY=pk_test_xxx"
else
    echo "[✓] STRIPE_PUBLISHABLE_KEY is set"
fi

if [ -z "$STRIPE_WEBHOOK_SECRET" ]; then
    echo "[!] STRIPE_WEBHOOK_SECRET not set"
    echo "    Run: stripe listen to get the webhook secret"
else
    echo "[✓] STRIPE_WEBHOOK_SECRET is set"
fi

# Test webhook endpoint
echo ""
echo "=== Webhook Test ==="
echo "Starting webhook listener..."
echo "Use Ctrl+C to stop when done testing"
echo ""

stripe listen --forward-to localhost:3000/api/webhooks/stripe
