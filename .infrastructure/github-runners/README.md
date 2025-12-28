# GitHub Runners - Multi-Organization Setup

Self-hosted GitHub runners for all organizations and personal repos, deployed on Harbor Homelab (Proxmox).

## Pre-installed Tools (Optimized for AI Enablement Projects)

All runners come with these tools baked into the Docker image:

| Tool | Version | Purpose |
|------|---------|---------|
| **Node.js** | 20 LTS | Runtime for Next.js, build tools |
| **Bun** | Latest | Fast package manager, runtime |
| **pnpm** | Latest | Alternative package manager |
| **Playwright** | Latest | E2E testing with Chromium, Firefox, WebKit |
| **Lighthouse CI** | Latest | Performance testing and audits |

**Result:** No more waiting for `setup-node`, `setup-bun`, or `playwright install` in CI jobs!

## Quick Start

### 1. Deploy to Proxmox Homelab

From your Mac (codebuild root):

```bash
cd /Users/adamkovacs/Documents/codebuild/.infrastructure/github-runners

# Deploy to Proxmox VM via Tailscale (builds image + deploys)
./deploy-to-proxmox.sh
```

This will:
1. Copy all files to `/opt/github-runners` on Proxmox VM
2. Build the optimized Docker image with all tools
3. Deploy 4 runners for all your GitHub accounts
4. Start monitoring with Watchtower

### 2. Use in Workflows

Update your GitHub Actions workflow to use the self-hosted runner:

```yaml
jobs:
  build:
    # Use the optimized self-hosted runner
    runs-on: [self-hosted, node20, playwright, lighthouse]

    steps:
      - uses: actions/checkout@v4

      # No need for setup-node or setup-bun - already installed!
      - name: Install dependencies
        run: bun install

      - name: Run tests
        run: bun test

      - name: Run E2E tests
        run: bun run test:e2e
        # Playwright browsers already installed!

      - name: Run Lighthouse
        run: bun run lhci
```

### 3. Verify Runners

Visit each organization's runner settings:
- [AI-Enablement-Academy](https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners)
- [OPEN-Talent-Society](https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners)
- [The-Talent-Foundation](https://github.com/organizations/The-Talent-Foundation/settings/actions/runners)
- [Personal repos](https://github.com/settings/actions/runners)

You should see 4 runners with green dots (Idle).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Proxmox Debian Docker VM                   │
│                     /opt/github-runners                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  runner-aea  │  │  runner-ots  │  │  runner-ttf  │  ...  │
│  │  (AI-Enable) │  │  (OPEN-Tal)  │  │  (Talent-Fn) │       │
│  │              │  │              │  │              │       │
│  │  Node 20     │  │  Node 20     │  │  Node 20     │       │
│  │  Bun         │  │  Bun         │  │  Bun         │       │
│  │  Playwright  │  │  Playwright  │  │  Playwright  │       │
│  │  LHCI        │  │  LHCI        │  │  LHCI        │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                              │
│  Shared Cache: bun / npm / pnpm / playwright                │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Deployment Location:** Proxmox Debian Docker VM
**Access:** `gitrunners.harbor.fyi` (via Nginx Proxy Manager)
**Network:** Tailscale VPN
**Monitoring:** Uptime Kuma + Netdata

## Files

| File | Purpose |
|------|---------|
| `Dockerfile` | Custom runner image with all pre-installed tools |
| `docker-compose.multi-org.yml` | All 4 runners + Watchtower |
| `deploy-multi-org.sh` | Local deployment script (on VM) |
| `deploy-to-proxmox.sh` | Remote deployment from Mac |
| `build-image.sh` | Build image only (for testing) |
| `.env` | GitHub PAT and configuration (gitignored) |

## Runner Labels

Each runner has these labels for workflow targeting:

```yaml
runs-on: [self-hosted, linux, x64, bun, node20, playwright, lighthouse, <org>]
```

Organization-specific labels:
- `aea` - AI-Enablement-Academy
- `ots` - OPEN-Talent-Society
- `ttf` - The-Talent-Foundation
- `personal` - Personal repos

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

# Verify installed tools
docker exec github-runner-aea node --version
docker exec github-runner-aea bun --version
docker exec github-runner-aea npx playwright --version
```

### Rebuild Image

After updating the Dockerfile:

```bash
# On VM
cd /opt/github-runners
./deploy-multi-org.sh              # Full rebuild + deploy
./deploy-multi-org.sh --skip-build # Deploy without rebuild
./deploy-multi-org.sh --build-only # Build only, no deploy

# Or from Mac
./deploy-to-proxmox.sh             # Copy + rebuild + deploy
```

## Resource Allocation

Each runner container:
- **CPU:** 2 cores limit, 1 core reserved
- **Memory:** 6GB limit, 3GB reserved (increased for Playwright)
- **Total:** 8 cores, 24GB RAM for all 4 runners

## Monitoring

**Uptime Kuma:** Monitor all 4 runner containers
**Netdata:** CPU, memory, network usage
**Status Dashboard:** https://status.aienablement.academy

## Cost Savings

| Item | Self-Hosted | GitHub Hosted |
|------|-------------|---------------|
| Infrastructure | $0 (existing Proxmox) | - |
| Power | ~$2/month | - |
| CI Minutes | **Unlimited** | $0.008/min (overages) |
| Tool Install Time | **0 seconds** | 30-60 seconds per job |
| **Total** | **~$2/month** | **$50+/month** |

**Estimated savings:** $48+/month + faster CI (no tool installation)

## Troubleshooting

### Runner not connecting

```bash
# Check logs
docker compose -f docker-compose.multi-org.yml logs runner-aea

# Verify PAT is valid
curl -H "Authorization: token $GITHUB_PAT" https://api.github.com/user

# Restart runner
docker compose -f docker-compose.multi-org.yml restart runner-aea
```

### Playwright tests failing

```bash
# Verify browsers are installed
docker exec github-runner-aea npx playwright --version
docker exec github-runner-aea ls /root/.cache/ms-playwright/

# If missing, rebuild image
./deploy-multi-org.sh
```

### Image build fails

```bash
# Build with verbose output
docker build --no-cache --progress=plain -t github-runner-optimized:latest .

# Check for disk space
df -h
docker system prune -a  # Clean up old images
```

## Support

See `DEPLOYMENT.md` for detailed homelab deployment guide.
