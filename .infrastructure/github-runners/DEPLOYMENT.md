# GitHub Runners Deployment - Harbor Homelab

Multi-organization GitHub runners deployed on Proxmox Debian Docker VM.

## Infrastructure

**Location:** Proxmox Debian Docker VM (Harbor Homelab)
**Domain:** `gitrunners.harbor.fyi`
**Services:** 4 GitHub runners (AI-Enablement-Academy, OPEN-Talent-Society, The-Talent-Foundation, adambkovacs)

## Architecture

```
Harbor Homelab (Proxmox)
├── Debian Docker VM
│   └── GitHub Runners Stack
│       ├── runner-aea (AI-Enablement-Academy)
│       ├── runner-ots (OPEN-Talent-Society)
│       ├── runner-ttf (The-Talent-Foundation)
│       ├── runner-personal (adambkovacs)
│       └── watchtower (auto-updates)
├── Nginx Proxy Manager
│   └── gitrunners.harbor.fyi → Docker VM
└── Tailscale VPN
    └── Secure access
```

## Deployment to Proxmox

### Prerequisites

1. **Proxmox Debian Docker VM** (already exists)
2. **Docker & Docker Compose** installed
3. **Tailscale** for secure access
4. **Nginx Proxy Manager** for subdomain

### Step 1: Copy Files to Proxmox VM

From your Mac:

```bash
# Via Tailscale
scp -r /Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners \
  root@debian-docker-vm.tailscale.net:/opt/

# Or via local network
scp -r /Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners \
  root@<VM-IP>:/opt/
```

### Step 2: Deploy on Proxmox VM

SSH into the Debian Docker VM:

```bash
ssh root@debian-docker-vm.tailscale.net

# Navigate to runners directory
cd /opt/github-runners

# Deploy all runners
./deploy-multi-org.sh
```

### Step 3: Configure Nginx Subdomain

In **Nginx Proxy Manager** (npm.harbor.fyi):

**Proxy Host:**
- Domain: `gitrunners.harbor.fyi`
- Scheme: `http`
- Forward Hostname/IP: `<Docker-VM-IP>` or `debian-docker-vm.tailscale.net`
- Forward Port: `8080` (we'll add a status dashboard)
- Websockets: ✅ On

**SSL:**
- SSL Certificate: Harbor wildcard cert (`*.harbor.fyi`)
- Force SSL: ✅ On
- HTTP/2: ✅ On

### Step 4: Add Status Dashboard (Optional)

Create a simple status page:

```bash
# On Proxmox VM
docker run -d \
  --name runner-status \
  --restart unless-stopped \
  -p 8080:80 \
  -v /opt/github-runners:/data:ro \
  nginx:alpine

# Create status page
cat > /opt/github-runners/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>GitHub Runners - Harbor Homelab</title>
  <style>
    body { font-family: Arial; max-width: 800px; margin: 50px auto; }
    .runner { padding: 20px; margin: 10px 0; border-radius: 8px; }
    .active { background: #d4edda; border: 1px solid #c3e6cb; }
    .status { font-weight: bold; color: #155724; }
  </style>
</head>
<body>
  <h1>🏃 GitHub Runners Status</h1>
  <p>Multi-organization runners deployed on Harbor Homelab</p>

  <div class="runner active">
    <h3>AI-Enablement-Academy</h3>
    <p class="status">✅ Active</p>
    <a href="https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners">Manage →</a>
  </div>

  <div class="runner active">
    <h3>OPEN-Talent-Society</h3>
    <p class="status">✅ Active</p>
    <a href="https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners">Manage →</a>
  </div>

  <div class="runner active">
    <h3>The-Talent-Foundation</h3>
    <p class="status">✅ Active</p>
    <a href="https://github.com/organizations/The-Talent-Foundation/settings/actions/runners">Manage →</a>
  </div>

  <div class="runner active">
    <h3>Personal (adambkovacs)</h3>
    <p class="status">✅ Active</p>
    <a href="https://github.com/settings/actions/runners">Manage →</a>
  </div>

  <hr>
  <p><small>Deployed on Proxmox Debian Docker VM | Managed via Tailscale</small></p>
</body>
</html>
EOF
```

## Monitoring Integration

### Uptime Kuma

Add 4 monitors to Uptime Kuma (uptime.harbor.fyi):

```bash
# Monitor each runner container
- Name: GitHub Runner - AEA
  Type: Docker Container
  Container: github-runner-aea

- Name: GitHub Runner - OTS
  Type: Docker Container
  Container: github-runner-ots

- Name: GitHub Runner - TTF
  Type: Docker Container
  Container: github-runner-ttf

- Name: GitHub Runner - Personal
  Type: Docker Container
  Container: github-runner-personal
```

### Netdata

Netdata automatically monitors:
- Container CPU/Memory usage
- Network I/O
- Health checks

Access: `netdata.harbor.fyi`

## Management Commands

**On Proxmox VM:**

```bash
# SSH into VM
ssh root@debian-docker-vm.tailscale.net

cd /opt/github-runners

# View all runner status
docker compose -f docker-compose.multi-org.yml ps

# View logs
docker compose -f docker-compose.multi-org.yml logs -f

# Restart specific runner
docker compose -f docker-compose.multi-org.yml restart runner-aea

# Update all runners
docker compose -f docker-compose.multi-org.yml pull
docker compose -f docker-compose.multi-org.yml up -d

# Stop all runners
docker compose -f docker-compose.multi-org.yml down
```

## Backup & Recovery

### Automated Backup

Add to your backup rotation script:

```bash
# In backup-rotation.sh
backup_github_runners() {
  ssh root@debian-docker-vm.tailscale.net \
    "tar -czf /tmp/github-runners-backup.tar.gz \
      /opt/github-runners/.env \
      /opt/github-runners/docker-compose.multi-org.yml"

  scp root@debian-docker-vm.tailscale.net:/tmp/github-runners-backup.tar.gz \
    /nas/backups/github-runners/
}
```

### Manual Backup

```bash
# From Mac
scp root@debian-docker-vm.tailscale.net:/opt/github-runners/.env \
  ~/backups/github-runners-env-$(date +%Y%m%d).backup
```

## Troubleshooting

### Runners Not Connecting

```bash
# Check Docker service
systemctl status docker

# Check runner logs
docker logs github-runner-aea

# Verify network
docker network inspect github-runners_runner-network

# Test GitHub connectivity
docker exec github-runner-aea curl -I https://github.com
```

### High Resource Usage

```bash
# Check resource usage
docker stats

# Limit resources in docker-compose.multi-org.yml
deploy:
  resources:
    limits:
      cpus: '1.5'
      memory: 3G
```

### SSL Issues

```bash
# Verify Nginx Proxy Manager config
# Check certificate status at npm.harbor.fyi
# Ensure DNS points to correct IP
```

## Security

### Firewall Rules

```bash
# On Proxmox host
# Allow only Tailscale and internal network
ufw allow from 100.64.0.0/10 to any port 22  # Tailscale SSH
ufw allow from 192.168.1.0/24              # Internal network
```

### Rotate PAT

```bash
# 1. Generate new PAT at GitHub
# 2. Update .env on Proxmox VM
nano /opt/github-runners/.env

# 3. Restart runners
docker compose -f docker-compose.multi-org.yml down
docker compose -f docker-compose.multi-org.yml up -d
```

## Cost Analysis

**Infrastructure:**
- Proxmox VM: $0 (existing)
- Storage: ~2GB
- Network: Minimal (<100MB/month)

**Power:**
- Runners: ~5W continuous
- Cost: ~$1-2/month

**Total: $1-2/month for UNLIMITED CI minutes across 4 GitHub accounts**

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| Status Dashboard | https://gitrunners.harbor.fyi | Runner status overview |
| Uptime Kuma | https://uptime.harbor.fyi | Health monitoring |
| Netdata | https://netdata.harbor.fyi | Resource monitoring |
| Proxmox | https://proxmox.harbor.fyi | VM management |
| GitHub - AEA | https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners | Org settings |
| GitHub - OTS | https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners | Org settings |
| GitHub - TTF | https://github.com/organizations/The-Talent-Foundation/settings/actions/runners | Org settings |
| GitHub - Personal | https://github.com/settings/actions/runners | Personal settings |

## Support

- Proxmox Docs: https://pve.proxmox.com/wiki/Main_Page
- GitHub Runner: https://github.com/myoung34/docker-github-actions-runner
- Nginx Proxy Manager: https://nginxproxymanager.com/guide/
