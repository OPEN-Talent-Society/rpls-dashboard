#!/bin/bash
set -e

echo "🚀 Deploy GitHub Runners to Proxmox Homelab"
echo "==========================================="
echo ""

# Configuration
PROXMOX_VM="debian-docker-vm.tailscale.net"
REMOTE_DIR="/opt/github-runners"
LOCAL_DIR="/Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners"

echo "📡 Target: $PROXMOX_VM"
echo "📂 Remote directory: $REMOTE_DIR"
echo ""

# Check if we can reach the VM
echo "🔍 Checking connection to Proxmox VM..."
if ! ssh -o ConnectTimeout=5 root@$PROXMOX_VM "echo 'Connection OK'" > /dev/null 2>&1; then
    echo "❌ Cannot connect to $PROXMOX_VM"
    echo "   Make sure:"
    echo "   1. Tailscale is running on your Mac"
    echo "   2. The Debian Docker VM is online"
    echo "   3. You have SSH access (ssh root@$PROXMOX_VM)"
    exit 1
fi
echo "✅ Connected to Proxmox VM"

# Create remote directory
echo "📁 Creating remote directory..."
ssh root@$PROXMOX_VM "mkdir -p $REMOTE_DIR"

# Copy files
echo "📤 Copying files to Proxmox VM..."
scp -r $LOCAL_DIR/* root@$PROXMOX_VM:$REMOTE_DIR/

echo "✅ Files copied successfully"

# Deploy on remote
echo ""
echo "🚀 Deploying runners on Proxmox VM..."
ssh root@$PROXMOX_VM "cd $REMOTE_DIR && ./deploy-multi-org.sh"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📊 Next steps:"
echo "  1. Verify runners at https://github.com/organizations/<ORG>/settings/actions/runners"
echo "  2. Set up Nginx subdomain: gitrunners.harbor.fyi"
echo "  3. Add to Uptime Kuma monitoring"
echo ""
echo "📋 Management commands (run on Proxmox VM):"
echo "  ssh root@$PROXMOX_VM"
echo "  cd $REMOTE_DIR"
echo "  docker compose -f docker-compose.multi-org.yml ps    # Status"
echo "  docker compose -f docker-compose.multi-org.yml logs  # Logs"
