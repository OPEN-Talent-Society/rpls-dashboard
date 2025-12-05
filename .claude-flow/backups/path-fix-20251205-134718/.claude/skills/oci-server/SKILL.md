---
name: "OCI Server Operations"
description: "Connect to and manage OCI Docker host server. Use when deploying containers, managing services, editing Caddyfile, or troubleshooting OCI infrastructure at 163.192.41.116."
---

# OCI Server Operations

## What This Skill Does

Direct SSH and CLI operations for the OCI Docker host:
1. SSH connection to server
2. Docker container management
3. Caddy reverse proxy configuration
4. Service deployment and monitoring

## Quick Reference

### Server Details
| Property | Value |
|----------|-------|
| **IP Address** | 163.192.41.116 |
| **User** | ubuntu |
| **SSH Key** | ~/Downloads/ssh-key-2025-10-17.key |
| **Specs** | Ampere A1 (4 OCPUs / 24 GB RAM), Ubuntu 22.04 |
| **Tenancy** | hello7142 (us-sanjose-1) |
| **Reserved IP** | 192.18.138.10 (unused) |

### SSH Connection
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116
```

---

## CRITICAL: Common Mistakes to Avoid

### Wrong IP Address
- **WRONG**: 192.18.138.10 (this is a reserved, unused IP)
- **CORRECT**: 163.192.41.116 (this is the actual server)

### Wrong Caddyfile Location
- **WRONG**: /srv/proxy/Caddyfile
- **CORRECT**: /home/ubuntu/reverse-proxy/Caddyfile

### Wrong Container Name
- **WRONG**: caddy-proxy
- **CORRECT**: edge-proxy

---

## Common Operations

### SSH Connection
```bash
# Direct connection
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116

# With command execution
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "docker ps"
```

### Docker Operations
```bash
# List all containers
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "docker ps -a"

# Check specific container logs
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "docker logs --tail 50 <container-name>"

# Restart container
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "docker restart <container-name>"

# Check Docker Compose stacks
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "cd /srv/<stack> && docker compose ps"
```

### Caddy Operations

#### View Caddyfile
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "cat /home/ubuntu/reverse-proxy/Caddyfile"
```

#### Add New Subdomain Block
```bash
# SSH into server first
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116

# Edit Caddyfile
sudo nano /home/ubuntu/reverse-proxy/Caddyfile

# Add block like:
# newsubdomain.aienablement.academy {
#   reverse_proxy container-name:port
# }

# Reload Caddy
sudo docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile
```

#### Reload Caddy Config
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "sudo docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile"
```

#### Check Caddy Logs
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "docker logs --tail 100 edge-proxy"
```

### File Operations
```bash
# View file
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "cat /path/to/file"

# Edit file remotely (creates local copy first)
scp -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116:/path/to/file ./local-copy
# Edit locally, then upload
scp -i ~/Downloads/ssh-key-2025-10-17.key ./local-copy ubuntu@163.192.41.116:/path/to/file

# Append to file
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "echo 'NEW_VAR=value' | sudo tee -a /path/to/.env"
```

---

## Service Stack Locations

| Service | Directory | Container |
|---------|-----------|-----------|
| Docmost | /srv/wiki | docmost-app |
| NocoDB | /srv/ops | nocodb-app |
| Cortex (SiYuan) | /srv/cortex | cortex-siyuan |
| Formbricks | /srv/forms | formbricks-app |
| Cal.com | /srv/calcom | calcom-app |
| Uptime Kuma | /srv/monitoring | uptime-kuma |
| Dozzle | /srv/monitoring | dozzle |
| n8n | /srv/n8n | n8n-app |
| Dashboard | /srv/dash | dash-app |
| Caddy Proxy | /home/ubuntu/reverse-proxy | edge-proxy |

---

## Helper Scripts

### Check All Services
Create: `scripts/check-services.sh`
```bash
#!/bin/bash
SSH_CMD="ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116"

echo "=== Docker Containers ==="
$SSH_CMD "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
echo "=== Disk Usage ==="
$SSH_CMD "df -h / | tail -1"

echo ""
echo "=== Memory Usage ==="
$SSH_CMD "free -h | grep Mem"
```

### Deploy New Service
Create: `scripts/deploy-service.sh`
```bash
#!/bin/bash
SERVICE_NAME=$1
SSH_CMD="ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116"

if [ -z "$SERVICE_NAME" ]; then
    echo "Usage: ./deploy-service.sh <service-name>"
    exit 1
fi

echo "Deploying $SERVICE_NAME..."
$SSH_CMD "cd /srv/$SERVICE_NAME && docker compose pull && docker compose up -d"
```

### Quick SSH Function
Add to `~/.bashrc` or `~/.zshrc`:
```bash
oci-ssh() {
    ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 "$@"
}

# Usage:
# oci-ssh                    # Interactive shell
# oci-ssh "docker ps"        # Run command
# oci-ssh "cat /srv/wiki/.env"  # View file
```

---

## New Subdomain Workflow

When adding a new subdomain for a service:

### Step 1: Create DNS Record (Cloudflare)
```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

# Create with proxy DISABLED for ACME verification
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "newsubdomain",
    "content": "163.192.41.116",
    "ttl": 1,
    "proxied": false
  }'
```

### Step 2: Add Caddyfile Block
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116

# Edit Caddyfile
sudo nano /home/ubuntu/reverse-proxy/Caddyfile

# Add:
# newsubdomain.aienablement.academy {
#   reverse_proxy container-name:port
# }
```

### Step 3: Reload Caddy
```bash
sudo docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile
```

### Step 4: Wait for Certificate
```bash
# Check Caddy logs for certificate issuance
docker logs --tail 50 edge-proxy | grep -i cert
```

### Step 5: Enable Cloudflare Proxy
```bash
# Get record ID first
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=newsubdomain.aienablement.academy" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[0].id'

# Enable proxy
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/{record_id}" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"proxied": true}'
```

---

## Troubleshooting

### Issue: SSH Connection Timeout
**Symptoms**: Connection hangs or times out
**Cause**: Wrong IP or firewall blocking
**Solution**:
1. Verify IP is 163.192.41.116 (NOT 192.18.138.10)
2. Check OCI Security List allows SSH from your IP
3. Verify SSH key permissions: `chmod 600 ~/Downloads/ssh-key-2025-10-17.key`

### Issue: Permission Denied (publickey)
**Symptoms**: SSH rejects connection
**Cause**: Wrong key or user
**Solution**:
1. Use user `ubuntu` (not root)
2. Use key `~/Downloads/ssh-key-2025-10-17.key`
3. Check key permissions: `chmod 600`

### Issue: Caddy Not Reloading
**Symptoms**: Config changes not taking effect
**Cause**: Container name or path wrong
**Solution**:
1. Container is `edge-proxy` (not `caddy-proxy`)
2. Config is `/etc/caddy/Caddyfile` inside container
3. Run: `docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile`

### Issue: 525 SSL Handshake Failed
**Symptoms**: Cloudflare returns 525 error
**Cause**: Cloudflare proxy enabled before origin cert issued
**Solution**: See Cloudflare DNS skill for SSL workflow

---

## OCI CLI Reference

### Local CLI Path
```bash
/Users/adamkovacs/bin/oci
```

### Common Commands
```bash
# List instances
/Users/adamkovacs/bin/oci compute instance list --compartment-id <ocid>

# List public IPs
/Users/adamkovacs/bin/oci network public-ip list --compartment-id <ocid>

# Update security rules
/Users/adamkovacs/bin/oci network security-list update --security-list-id <ocid> --ingress-security-rules file://rules.json
```

---

## Related Documentation

- Cloudflare DNS Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/cloudflare-dns/SKILL.md`
- Brevo Email Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/brevo-email/SKILL.md`
- Infrastructure Context: `/Users/adamkovacs/Documents/codebuild/.claude/memory/infrastructure-context.json`
