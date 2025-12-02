#!/bin/bash
# Analyze image from URL using Z.AI GLM-4.5V via Anthropic-compatible endpoint
# Usage: analyze-url.sh "https://example.com/image.jpg" "prompt"
# Note: Uses URL format directly (not base64) for better accuracy

set -e

IMAGE_URL="$1"
PROMPT="${2:-Describe this image in detail}"
MAX_TOKENS="${3:-1024}"

# Load API key from .env if not set
if [ -z "$Z_AI_API_KEY" ]; then
    if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
        source "/Users/adamkovacs/Documents/codebuild/.env"
    fi
fi

if [ -z "$Z_AI_API_KEY" ]; then
    echo "Error: Z_AI_API_KEY not set"
    exit 1
fi

if [ -z "$IMAGE_URL" ]; then
    echo "Error: Image URL required"
    exit 1
fi

# Call Z.AI API with URL format (works better than base64)
RESPONSE=$(curl -s -X POST "https://api.z.ai/api/anthropic/v1/messages" \
    -H "x-api-key: ${Z_AI_API_KEY}" \
    -H "anthropic-version: 2023-06-01" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"glm-4.5v\",
        \"max_tokens\": ${MAX_TOKENS},
        \"messages\": [{
            \"role\": \"user\",
            \"content\": [
                {\"type\": \"image\", \"source\": {\"type\": \"url\", \"url\": \"${IMAGE_URL}\"}},
                {\"type\": \"text\", \"text\": \"${PROMPT}\"}
            ]
        }]
    }")

# Extract and print response
echo "$RESPONSE" | jq -r '.content[0].text // .error.message // "Error: No response"'
