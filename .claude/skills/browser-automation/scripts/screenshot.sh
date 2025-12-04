#!/bin/bash
# Quick screenshot helper - no MCP needed
set -e

URL="${1:-https://example.com}"
OUTPUT="${2:-screenshot.png}"
FULL_PAGE="${3:-false}"

echo "Taking screenshot of $URL..."

if [ "$FULL_PAGE" = "true" ] || [ "$FULL_PAGE" = "--full-page" ]; then
  pnpm dlx playwright screenshot --full-page "$URL" "$OUTPUT"
else
  pnpm dlx playwright screenshot "$URL" "$OUTPUT"
fi

echo "Screenshot saved to $OUTPUT"
