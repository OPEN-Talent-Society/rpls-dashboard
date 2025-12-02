#!/bin/bash
# Stripe Webhook Monitor Hook
# Starts Stripe CLI webhook forwarding when dev server starts

# Check if Stripe CLI is available
if ! command -v stripe &> /dev/null && ! pnpm dlx stripe --version &> /dev/null; then
    echo "[stripe-webhook-monitor] Stripe CLI not found, skipping webhook forwarding"
    exit 0
fi

# Check if already running
if pgrep -f "stripe listen" > /dev/null; then
    echo "[stripe-webhook-monitor] Stripe webhook forwarding already running"
    exit 0
fi

# Get the webhook endpoint from environment or default
WEBHOOK_ENDPOINT="${STRIPE_WEBHOOK_ENDPOINT:-http://localhost:3000/api/webhooks/stripe}"

echo "[stripe-webhook-monitor] Starting Stripe webhook forwarding to $WEBHOOK_ENDPOINT"

# Start in background and capture the webhook secret
pnpm dlx stripe listen --forward-to "$WEBHOOK_ENDPOINT" --log-level info &

echo "[stripe-webhook-monitor] Stripe webhook forwarding started"
