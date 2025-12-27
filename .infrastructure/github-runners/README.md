# GitHub Runners - Multi-Organization Setup

Self-hosted GitHub runners for all organizations and personal repos, deployed on Harbor Homelab (Proxmox).

## Quick Start

### 1. Deploy to Proxmox Homelab

From your Mac (codebuild root):

```bash
cd /Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners

# Deploy to Proxmox VM via Tailscale
./deploy-to-proxmox.sh
```

This will:
1. Copy all files to `/opt/github-runners` on Proxmox VM
2. Deploy 4 runners for all your GitHub accounts
3. Start monitoring with Watchtower

### 2. Configure Nginx Subdomain

In Nginx Proxy Manager (npm.harbor.fyi):
- Add proxy host: `gitrunners.harbor.fyi` → Debian Docker VM
- Enable SSL with Harbor wildcard cert
- Force HTTPS

### 3. Verify Runners

Visit each organization:
- [AI-Enablement-Academy](https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners)
- [OPEN-Talent-Society](https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners)
- [The-Talent-Foundation](https://github.com/organizations/The-Talent-Foundation/settings/actions/runners)
- [Personal repos](https://github.com/settings/actions/runners)

You should see 4 runners with green dots (Idle).

## Architecture

**Deployment Location:** Proxmox Debian Docker VM
**Access:** `gitrunners.harbor.fyi` (via Nginx Proxy Manager)
**Network:** Tailscale VPN
**Monitoring:** Uptime Kuma + Netdata

## What's Included

- `docker-compose.multi-org.yml` - All 4 runners + Watchtower
- `deploy-multi-org.sh` - Local deployment script (on VM)
- `deploy-to-proxmox.sh` - Remote deployment from Mac
- `.env` - GitHub PAT and configuration (gitignored)
- `DEPLOYMENT.md` - Detailed homelab deployment guide

## Organizations Served

1. **AI-Enablement-Academy** - Primary development
2. **OPEN-Talent-Society** - Client projects
3. **The-Talent-Foundation** - Foundation projects
4. **adambkovacs** - Personal repositories

## Management

### From Your Mac (Remote)

```bash
# SSH to VM
ssh root@debian-docker-vm.tailscale.net

# View status
cd /opt/github-runners
docker compose -f docker-compose.multi-org.yml ps

# View logs
docker compose -f docker-compose.multi-org.yml logs -f runner-aea

# Restart runner
docker compose -f docker-compose.multi-org.yml restart runner-aea
```

### Update Runners

```bash
# From your Mac - update and redeploy
cd /Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners
./deploy-to-proxmox.sh
```

## Monitoring

**Uptime Kuma:** Monitor all 4 runner containers
**Netdata:** CPU, memory, network usage
**Status Dashboard:** https://gitrunners.harbor.fyi

## Cost

- Infrastructure: $0 (existing Proxmox)
- Power: ~$1-2/month
- **Total: ~$2/month for UNLIMITED CI minutes**

vs. GitHub hosted: $0.008/min × 4 accounts = $32/month+ for overages

## Support

See `DEPLOYMENT.md` for detailed documentation.
