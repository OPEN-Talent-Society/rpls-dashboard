#!/bin/bash
# Build the optimized GitHub runner image
# This script builds the custom Docker image with Node 20, Bun, Playwright, etc.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="github-runner-optimized"
IMAGE_TAG="${1:-latest}"

echo "========================================"
echo "Building Optimized GitHub Runner Image"
echo "========================================"
echo ""
echo "Image: ${IMAGE_NAME}:${IMAGE_TAG}"
echo "Context: ${SCRIPT_DIR}"
echo ""

cd "${SCRIPT_DIR}"

# Build the image
echo "Building Docker image..."
docker build \
    --tag "${IMAGE_NAME}:${IMAGE_TAG}" \
    --file Dockerfile \
    --progress=plain \
    .

# Show image size
echo ""
echo "Build complete!"
echo ""
docker images "${IMAGE_NAME}:${IMAGE_TAG}" --format "Image: {{.Repository}}:{{.Tag}} | Size: {{.Size}}"

echo ""
echo "========================================"
echo "Pre-installed tools:"
echo "========================================"
docker run --rm "${IMAGE_NAME}:${IMAGE_TAG}" sh -c '
echo "Node.js: $(node --version)"
echo "npm:     $(npm --version)"
echo "pnpm:    $(pnpm --version)"
echo "Bun:     $(bun --version)"
echo "LHCI:    $(lhci --version)"
echo "Playwright: $(npx playwright --version)"
'

echo ""
echo "Ready to deploy with: ./deploy-multi-org.sh"
