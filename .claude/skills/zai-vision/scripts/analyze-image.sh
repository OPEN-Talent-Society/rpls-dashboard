#!/bin/bash
# Analyze local image using Z.AI GLM-4.5V via Anthropic-compatible endpoint
# Usage: analyze-image.sh /path/to/image.png "prompt"

set -e

IMAGE_PATH="$1"
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

if [ ! -f "$IMAGE_PATH" ]; then
    echo "Error: Image file not found: $IMAGE_PATH"
    exit 1
fi

# Determine media type
EXT="${IMAGE_PATH##*.}"
EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
case "$EXT_LOWER" in
    png) MEDIA_TYPE="image/png" ;;
    jpg|jpeg) MEDIA_TYPE="image/jpeg" ;;
    gif) MEDIA_TYPE="image/gif" ;;
    webp) MEDIA_TYPE="image/webp" ;;
    *) MEDIA_TYPE="image/png" ;;
esac

# Convert image to base64
BASE64_DATA=$(base64 -i "$IMAGE_PATH" | tr -d '\n')

# Call Z.AI API via Anthropic-compatible endpoint
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
                {\"type\": \"image\", \"source\": {\"type\": \"base64\", \"media_type\": \"${MEDIA_TYPE}\", \"data\": \"${BASE64_DATA}\"}},
                {\"type\": \"text\", \"text\": \"${PROMPT}\"}
            ]
        }]
    }")

# Extract and print the response text
echo "$RESPONSE" | jq -r '.content[0].text // .error.message // "Error: No response"'
