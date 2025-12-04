#!/bin/bash
# Test Qdrant security configuration
# Usage: ./test-security.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo -e "${RED}❌ .env file not found${NC}"
    echo "Run ./generate-keys.sh first"
    exit 1
fi

# Check required variables
if [ -z "$QDRANT_API_KEY" ] || [ -z "$QDRANT_READ_ONLY_API_KEY" ]; then
    echo -e "${RED}❌ API keys not set in .env${NC}"
    exit 1
fi

if [ -z "$QDRANT_URL" ]; then
    QDRANT_URL="https://qdrant.harbor.fyi"
fi

echo "🔐 Qdrant Security Test Suite"
echo "================================"
echo "Testing against: ${QDRANT_URL}"
echo ""

# Test 1: No API key should fail
echo "Test 1: Authentication required (no API key)"
echo "-------------------------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${QDRANT_URL}/collections)
if [ "$HTTP_CODE" == "401" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Returns 401 Unauthorized"
else
    echo -e "${RED}❌ FAIL${NC} - Expected 401, got ${HTTP_CODE}"
fi
echo ""

# Test 2: Valid admin API key should work
echo "Test 2: Admin API key (read access)"
echo "-----------------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "api-key: ${QDRANT_API_KEY}" \
    ${QDRANT_URL}/collections)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Admin key works for read operations"
else
    echo -e "${RED}❌ FAIL${NC} - Expected 200, got ${HTTP_CODE}"
fi
echo ""

# Test 3: Read-only API key should work for reads
echo "Test 3: Read-only API key (read access)"
echo "---------------------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
    ${QDRANT_URL}/collections)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Read-only key works for read operations"
else
    echo -e "${RED}❌ FAIL${NC} - Expected 200, got ${HTTP_CODE}"
fi
echo ""

# Test 4: Read-only key should fail for writes
echo "Test 4: Read-only API key (write access should fail)"
echo "----------------------------------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X PUT \
    -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
    -H "Content-Type: application/json" \
    ${QDRANT_URL}/collections/test_security_temp \
    -d '{"vectors": {"size": 128, "distance": "Cosine"}}')
if [ "$HTTP_CODE" == "403" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Read-only key blocked for write operations"
elif [ "$HTTP_CODE" == "401" ]; then
    echo -e "${YELLOW}⚠️  WARN${NC} - Got 401 instead of 403 (may be expected)"
else
    echo -e "${RED}❌ FAIL${NC} - Expected 403, got ${HTTP_CODE}"
fi
echo ""

# Test 5: SSL/TLS verification
echo "Test 5: SSL/TLS configuration"
echo "-----------------------------"
if [[ "$QDRANT_URL" == https://* ]]; then
    SSL_VERIFY=$(curl -s -o /dev/null -w "%{ssl_verify_result}" ${QDRANT_URL}/collections)
    if [ "$SSL_VERIFY" == "0" ]; then
        echo -e "${GREEN}✅ PASS${NC} - SSL certificate is valid"
    else
        echo -e "${YELLOW}⚠️  WARN${NC} - SSL verification failed (code: ${SSL_VERIFY})"
    fi
else
    echo -e "${YELLOW}⚠️  SKIP${NC} - Not using HTTPS"
fi
echo ""

# Test 6: CORS headers
echo "Test 6: CORS headers"
echo "-------------------"
CORS_HEADER=$(curl -s -I \
    -H "api-key: ${QDRANT_API_KEY}" \
    -H "Origin: https://example.com" \
    ${QDRANT_URL}/collections | grep -i "Access-Control-Allow-Origin")
if [ ! -z "$CORS_HEADER" ]; then
    echo -e "${GREEN}✅ PASS${NC} - CORS headers present"
    echo "   $CORS_HEADER"
else
    echo -e "${YELLOW}⚠️  WARN${NC} - CORS headers not found"
fi
echo ""

# Test 7: Health check endpoint
echo "Test 7: Health check endpoint"
echo "-----------------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" ${QDRANT_URL}/healthz)
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Health check accessible"
else
    echo -e "${RED}❌ FAIL${NC} - Health check failed (code: ${HTTP_CODE})"
fi
echo ""

# Test 8: Invalid API key should fail
echo "Test 8: Invalid API key"
echo "----------------------"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "api-key: invalid-key-12345" \
    ${QDRANT_URL}/collections)
if [ "$HTTP_CODE" == "401" ] || [ "$HTTP_CODE" == "403" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Invalid key rejected (${HTTP_CODE})"
else
    echo -e "${RED}❌ FAIL${NC} - Expected 401/403, got ${HTTP_CODE}"
fi
echo ""

# Test 9: Cloudflare Access (if configured)
if [ ! -z "$CF_ACCESS_CLIENT_ID" ] && [ ! -z "$CF_ACCESS_CLIENT_SECRET" ]; then
    echo "Test 9: Cloudflare Access headers"
    echo "---------------------------------"
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        ${QDRANT_URL}/collections)
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Cloudflare Access headers work"
    else
        echo -e "${RED}❌ FAIL${NC} - Expected 200, got ${HTTP_CODE}"
    fi
    echo ""
else
    echo "Test 9: Cloudflare Access headers"
    echo "---------------------------------"
    echo -e "${YELLOW}⚠️  SKIP${NC} - Cloudflare Access not configured"
    echo ""
fi

# Test 10: Docker container status
echo "Test 10: Docker container health"
echo "--------------------------------"
CONTAINER_STATUS=$(docker inspect -f '{{.State.Status}}' qdrant 2>/dev/null || echo "not found")
if [ "$CONTAINER_STATUS" == "running" ]; then
    echo -e "${GREEN}✅ PASS${NC} - Qdrant container is running"

    # Check health status
    HEALTH_STATUS=$(docker inspect -f '{{.State.Health.Status}}' qdrant 2>/dev/null || echo "unknown")
    if [ "$HEALTH_STATUS" == "healthy" ]; then
        echo -e "${GREEN}✅ PASS${NC} - Container health check is healthy"
    elif [ "$HEALTH_STATUS" == "unknown" ]; then
        echo -e "${YELLOW}⚠️  WARN${NC} - Health check not configured"
    else
        echo -e "${RED}❌ FAIL${NC} - Container health: ${HEALTH_STATUS}"
    fi
else
    echo -e "${RED}❌ FAIL${NC} - Container status: ${CONTAINER_STATUS}"
fi
echo ""

# Summary
echo "================================"
echo "🏁 Test Summary"
echo "================================"
echo "Review results above for any failures or warnings."
echo ""
echo "Next steps:"
echo "1. Fix any failed tests"
echo "2. Review warnings for potential issues"
echo "3. Update sync scripts with API keys"
echo "4. Test all integrations"
echo ""
echo "Security checklist: .claude/docs/QDRANT-SECURITY.md"
