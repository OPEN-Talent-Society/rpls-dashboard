#!/bin/bash

# Health Check Script for Test Skill
# Tests basic connectivity to common services

echo "=== Infrastructure Health Check ==="
echo "Time: $(date)"
echo

# Test basic network connectivity
echo "1. Network Connectivity Tests:"
ping -c 1 8.8.8.8 > /dev/null 2>&1 && echo "   ✅ Internet connectivity" || echo "   ❌ Internet connectivity failed"

# Test DNS resolution
echo "2. DNS Resolution Tests:"
nslookup wiki.aienablement.academy > /dev/null 2>&1 && echo "   ✅ wiki.aienablement.academy resolves" || echo "   ❌ wiki.aienablement.academy DNS failed"
nslookup ops.aienablement.academy > /dev/null 2>&1 && echo "   ✅ ops.aienablement.academy resolves" || echo "   ❌ ops.aienablement.academy DNS failed"

# Test HTTPS connectivity
echo "3. HTTPS Connectivity Tests:"
curl -s -o /dev/null -w "%{http_code}" https://wiki.aienablement.academy/api/health | grep -q "200" && echo "   ✅ Docmost health endpoint responding" || echo "   ❌ Docmost health endpoint failed"
curl -s -o /dev/null -w "%{http_code}" https://ops.aienablement.academy/api/v1/health | grep -q "200" && echo "   ✅ NocoDB health endpoint responding" || echo "   ❌ NocoDB health endpoint failed"

echo
echo "=== Health Check Complete ==="