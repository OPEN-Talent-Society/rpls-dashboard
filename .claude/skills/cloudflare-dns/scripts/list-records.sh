#!/bin/bash
# List all DNS records in Cloudflare zone
# Usage: ./list-records.sh

set -e

# Load credentials
CREDS_FILE="/Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env"
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
else
    echo "Error: Credentials file not found at $CREDS_FILE"
    exit 1
fi

echo "DNS Records for aienablement.academy"
echo "====================================="
echo ""

curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" | \
  jq -r '.result[] | "\(.id)\t\(.name)\t\(.type)\t\(.content)\t\(if .proxied then "PROXIED" else "DIRECT" end)"' | \
  column -t -s $'\t'
