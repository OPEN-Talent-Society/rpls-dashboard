#!/bin/bash
# Check all services on OCI Docker host
# Usage: ./check-services.sh

set -e

SSH_KEY="$HOME/Downloads/ssh-key-2025-10-17.key"
SSH_HOST="ubuntu@163.192.41.116"
SSH_CMD="ssh -i $SSH_KEY $SSH_HOST"

echo "OCI Docker Host Status Report"
echo "=============================="
echo "Host: 163.192.41.116"
echo "Time: $(date)"
echo ""

echo "=== Docker Containers ==="
$SSH_CMD "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" 2>/dev/null || echo "Error connecting to host"

echo ""
echo "=== System Resources ==="
echo "Disk:"
$SSH_CMD "df -h / | tail -1 | awk '{print \"  Used: \" \$3 \" / \" \$2 \" (\" \$5 \")\"}'" 2>/dev/null

echo "Memory:"
$SSH_CMD "free -h | grep Mem | awk '{print \"  Used: \" \$3 \" / \" \$2}'" 2>/dev/null

echo "Load:"
$SSH_CMD "uptime | sed 's/.*load average: /  Load: /'" 2>/dev/null

echo ""
echo "=== Caddy Proxy Status ==="
$SSH_CMD "docker logs --tail 5 edge-proxy 2>&1 | grep -v '^\$'" 2>/dev/null || echo "  Could not fetch Caddy logs"
