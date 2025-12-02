#!/bin/bash
# Create new subdomain in Cloudflare (proxy disabled for ACME)
# Usage: ./create-subdomain.sh <subdomain> [ip]

set -e

# Load credentials
CREDS_FILE="/Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env"
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
else
    echo "Error: Credentials file not found at $CREDS_FILE"
    exit 1
fi

SUBDOMAIN=$1
IP="${2:-163.192.41.116}"

if [ -z "$SUBDOMAIN" ]; then
    echo "Usage: ./create-subdomain.sh <subdomain> [ip]"
    echo ""
    echo "Examples:"
    echo "  ./create-subdomain.sh myapp"
    echo "  ./create-subdomain.sh myapp 192.168.1.100"
    exit 1
fi

echo "Creating DNS record for $SUBDOMAIN.aienablement.academy..."

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"A\",
    \"name\": \"$SUBDOMAIN\",
    \"content\": \"$IP\",
    \"ttl\": 1,
    \"proxied\": false
  }")

# Check for success
if echo "$RESPONSE" | grep -q '"success":true'; then
    RECORD_ID=$(echo "$RESPONSE" | jq -r '.result.id')
    echo ""
    echo "✓ Created: $SUBDOMAIN.aienablement.academy → $IP"
    echo "✓ Record ID: $RECORD_ID"
    echo "✓ Proxy: DISABLED (for ACME certificate)"
    echo ""
    echo "NEXT STEPS:"
    echo "1. SSH to OCI: ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116"
    echo "2. Edit Caddyfile: sudo nano /home/ubuntu/reverse-proxy/Caddyfile"
    echo "3. Add block:"
    echo "   $SUBDOMAIN.aienablement.academy {"
    echo "     reverse_proxy container-name:port"
    echo "   }"
    echo "4. Reload Caddy: sudo docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile"
    echo "5. Wait for cert, then enable proxy:"
    echo "   ./enable-proxy.sh $RECORD_ID"
else
    echo "Error creating DNS record:"
    echo "$RESPONSE" | jq .
    exit 1
fi
