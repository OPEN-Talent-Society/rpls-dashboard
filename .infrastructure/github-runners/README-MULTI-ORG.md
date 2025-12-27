# Multi-Organization GitHub Runner Setup

Deploy self-hosted GitHub runners for **all your organizations and personal repos** from a single Docker stack.

## Your GitHub Accounts

This setup serves:
1. **AI-Enablement-Academy** (organization)
2. **OPEN-Talent-Society** (organization)
3. **The-Talent-Foundation** (organization)
4. **adambkovacs** (personal repos)

## Benefits

- ✅ **One machine, 4 runners** - All orgs covered
- ✅ **Unlimited CI minutes** across all accounts
- ✅ **Shared caching** - Bun and node_modules cached once
- ✅ **Centralized management** - Single Docker stack
- ✅ **Cost-effective** - ~$10-15/month for everything

## Resource Usage

**Total Resources:**
- CPU: 8 cores reserved (2 per runner)
- Memory: 16GB reserved (4GB per runner)
- Disk: ~20GB for caches and runner data

**Recommended Hardware:**
- 8+ CPU cores
- 24GB+ RAM
- 100GB+ SSD storage

Perfect for: Proxmox LXC, OCI Ampere A1 (free), or your Mac

## Quick Start

### 1. Generate GitHub Personal Access Token

Go to: https://github.com/settings/tokens/new

**Required scopes:**
- ✅ `repo` (Full control of private repositories)
- ✅ `workflow` (Update GitHub Action workflows)
- ✅ `admin:org` (Manage organization runners)

**IMPORTANT:** The same PAT can be used for all organizations if you have admin access to all of them.

### 2. Configure Environment

```bash
cd .infrastructure/github-runner
cp .env.example .env
nano .env
```

Add your PAT:
```bash
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

That's it! The docker-compose.multi-org.yml is pre-configured for all your orgs.

### 3. Deploy All Runners

```bash
./deploy-multi-org.sh
```

This will:
1. Validate configuration
2. Create cache directories
3. Pull latest runner image
4. Start 4 runners simultaneously
5. Show status of all runners

### 4. Verify Runners Connected

Visit each organization's settings:

**Organizations:**
- https://github.com/organizations/AI-Enablement-Academy/settings/actions/runners
- https://github.com/organizations/OPEN-Talent-Society/settings/actions/runners
- https://github.com/organizations/The-Talent-Foundation/settings/actions/runners

**Personal:**
- https://github.com/settings/actions/runners

You should see all 4 runners with green dots (Idle status).

## Managing Runners

### View All Runner Status

```bash
docker compose -f docker-compose.multi-org.yml ps
```

### View Logs

```bash
# All runners
docker compose -f docker-compose.multi-org.yml logs -f

# Specific runner
docker compose -f docker-compose.multi-org.yml logs -f runner-aea
docker compose -f docker-compose.multi-org.yml logs -f runner-ots
docker compose -f docker-compose.multi-org.yml logs -f runner-ttf
docker compose -f docker-compose.multi-org.yml logs -f runner-personal
```

### Restart Specific Runner

```bash
docker compose -f docker-compose.multi-org.yml restart runner-aea
docker compose -f docker-compose.multi-org.yml restart runner-ots
docker compose -f docker-compose.multi-org.yml restart runner-ttf
docker compose -f docker-compose.multi-org.yml restart runner-personal
```

### Stop All Runners

```bash
docker compose -f docker-compose.multi-org.yml down
```

### Update Runners

```bash
docker compose -f docker-compose.multi-org.yml pull
docker compose -f docker-compose.multi-org.yml up -d
```

Watchtower will also auto-update runners daily.

## Using Runners in Workflows

### Organization Repos

Workflows in organization repos automatically see their org runner:

```yaml
# In AI-Enablement-Academy repos
jobs:
  build:
    runs-on: self-hosted  # Uses runner-aea

# Or target specific labels
jobs:
  build:
    runs-on: [self-hosted, aea]  # Explicit
```

### Personal Repos

```yaml
jobs:
  build:
    runs-on: [self-hosted, personal]
```

### Target Specific Organizations

```yaml
jobs:
  aea-job:
    runs-on: [self-hosted, aea]

  ots-job:
    runs-on: [self-hosted, ots]

  ttf-job:
    runs-on: [self-hosted, ttf]
```

## Resource Allocation

Each runner is configured with:

**Limits:**
- 2 CPU cores
- 4GB RAM

**Reservations:**
- 1 CPU core
- 2GB RAM

This allows bursting when other runners are idle.

## Cost Analysis

### Self-Hosted (4 runners)
- Hardware: $0 (existing infrastructure)
- Electricity: ~$10-15/month
- **Total: $10-15/month for UNLIMITED minutes across 4 accounts**

### GitHub-Hosted (if over free tier)
- 2,000 free min/month per account
- Overages: $0.008/minute
- **Example:** 4 accounts × 1,000 overage min = $32/month

**ROI:** Saves $15-20/month + unlimited scaling

## Troubleshooting

### Runner Not Appearing

1. Check logs: `docker compose -f docker-compose.multi-org.yml logs runner-XXX`
2. Common issues:
   - Invalid PAT (regenerate with correct scopes)
   - Organization name typo (check exact spelling)
   - PAT doesn't have admin:org scope

### Out of Memory

If runners crash:
1. Reduce parallel jobs in workflows
2. Increase host RAM
3. Reduce resource limits in docker-compose

### Network Issues

If runners can't connect to GitHub:
1. Check firewall rules
2. Verify Docker networking: `docker network ls`
3. Test connectivity: `docker compose -f docker-compose.multi-org.yml exec runner-aea curl https://github.com`

## Scaling Up

### Add More Runners Per Org

Edit `docker-compose.multi-org.yml`:

```yaml
runner-aea-2:
  extends: runner-aea
  container_name: github-runner-aea-2
  environment:
    RUNNER_NAME: docker-runner-aea-2
  volumes:
    - ./runner-data/aea-2:/tmp/runner-aea
```

### Add More Organizations

Copy any runner block and change:
- Service name
- Container name
- `ORG_NAME`
- Labels
- Data directory

## Monitoring

### Integration with Uptime Kuma

Monitor all 4 runners:

```bash
# Add Docker container monitors
curl -X POST http://uptime-kuma:3001/api/push/...
```

### Integration with Netdata

Netdata automatically detects and monitors all Docker containers.

## Backup & Recovery

### Backup Configuration

```bash
tar -czf runner-backup-$(date +%Y%m%d).tar.gz \
  .env \
  docker-compose.multi-org.yml \
  deploy-multi-org.sh
```

### Restore from Backup

```bash
tar -xzf runner-backup-YYYYMMDD.tar.gz
./deploy-multi-org.sh
```

## Security

### Rotate PAT Regularly

```bash
# 1. Generate new PAT
# 2. Update .env
# 3. Restart runners
docker compose -f docker-compose.multi-org.yml down
docker compose -f docker-compose.multi-org.yml up -d
```

### Network Isolation

Add to Tailscale for secure access:

```bash
tailscale up --authkey=<your-auth-key>
```

## Support

- GitHub Runner Image: https://github.com/myoung34/docker-github-actions-runner
- GitHub Actions Docs: https://docs.github.com/en/actions/hosting-your-own-runners
- Issues: File in ai-enablement-academy-v2 repo
