#!/bin/bash
# Test email sending via Brevo API
# Usage: ./test-email.sh [recipient@email.com] ["Subject Line"]

set -e

# Load credentials
CREDS_FILE="/Users/adamkovacs/Documents/codebuild/.credentials/brevo/api.env"
if [ -f "$CREDS_FILE" ]; then
    source "$CREDS_FILE"
else
    echo "Error: Credentials file not found at $CREDS_FILE"
    echo "Please create the file with BREVO_API_KEY variable"
    exit 1
fi

EMAIL_TO="${1:-adam@aienablement.academy}"
SUBJECT="${2:-Test Email from Brevo API}"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "Sending test email to $EMAIL_TO..."

RESPONSE=$(curl -s --request POST \
  --url https://api.brevo.com/v3/smtp/email \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data "{
    \"sender\": {\"name\": \"AI Enablement Academy\", \"email\": \"noreply@aienablement.academy\"},
    \"to\": [{\"email\": \"$EMAIL_TO\"}],
    \"subject\": \"$SUBJECT\",
    \"htmlContent\": \"<html><body><h1>Test Email</h1><p>This is a test email sent via Brevo API.</p><p>Sent at: $TIMESTAMP</p></body></html>\"
  }")

# Check for success
if echo "$RESPONSE" | grep -q "messageId"; then
    MESSAGE_ID=$(echo "$RESPONSE" | jq -r '.messageId')
    echo "Success! Message ID: $MESSAGE_ID"
else
    echo "Error sending email:"
    echo "$RESPONSE" | jq .
    exit 1
fi
