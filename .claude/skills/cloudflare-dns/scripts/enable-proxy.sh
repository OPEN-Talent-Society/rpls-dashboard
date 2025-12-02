#!/bin/bash
# Enable Cloudflare proxy for a DNS record (after cert issued)
# Usage: ./enable-proxy.sh <record_id>

set -e

# Load credentials
CREDS_FILE="/Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env"
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
else
    echo "Error: Credentials file not found at $CREDS_FILE"
    exit 1
fi

RECORD_ID=$1

if [ -z "$RECORD_ID" ]; then
    echo "Usage: ./enable-proxy.sh <record_id>"
    echo ""
    echo "Get record ID by running: ./list-records.sh"
    exit 1
fi

echo "Enabling Cloudflare proxy for record $RECORD_ID..."

RESPONSE=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"proxied": true}')

if echo "$RESPONSE" | grep -q '"success":true'; then
    NAME=$(echo "$RESPONSE" | jq -r '.result.name')
    echo "✓ Proxy enabled for $NAME"
else
    echo "Error enabling proxy:"
    echo "$RESPONSE" | jq .
    exit 1
fi
