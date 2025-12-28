# Harbor Homelab Infrastructure Inventory

**Last Updated:** 2025-12-26
**Location:** Harbor (192.168.50.x network)
**Primary Domain:** harbor.fyi
**Production Domain:** aienablement.academy

---

## Infrastructure Overview

The Harbor Homelab is a comprehensive self-hosted infrastructure running on Proxmox VE, providing:
- Vector database (Qdrant)
- Workflow automation (N8N)
- CI/CD (GitHub Actions Runners)
- Monitoring (Netdata, Uptime Kuma, Dozzle)
- Secrets management (Vaultwarden)
- Network access (Tailscale)
- Backup storage (QNAP NAS)

---

## Core Infrastructure

### Proxmox Hypervisor

**Type:** Virtualization Platform
**Version:** Proxmox VE
**Location:** 192.168.50.x
**Management:** Web UI at 192.168.50.x:8006

**Hosted VMs/Containers:**
- Debian Docker VM (Primary services host)
- Various LXC containers (as needed)

---

## Services Inventory

### 1. Qdrant Vector Database

**Purpose:** Semantic memory and vector search
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://qdrant.harbor.fyi
**Internal:** http://192.168.50.x:6333
**API Port:** 6333
**Collections:**
- embeddings (768-dim, Gemini embeddings)
- learnings (reasoning patterns)
- patterns (successful approaches)
- agent_memory (multi-tenant semantic memory)

**Integration:**
- Claude Code memory system
- AgentDB pattern storage
- Multi-tenant research indexing

**Monitoring:**
- Uptime Kuma: HTTPS endpoint check
- Netdata: Container metrics

**Documentation:** `.claude/docs/QDRANT-*.md`

---

### 2. N8N Workflow Automation (Harbor)

**Purpose:** Workflow automation and orchestration
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://n8n.harbor.fyi
**Internal:** http://192.168.50.149:5678
**API Port:** 5678

**Features:**
- 350+ integrations
- Visual workflow builder
- API endpoint creation
- Webhook automation
- Schedule-based triggers

**Integration:**
- Claude Code automation
- Memory sync workflows
- Infrastructure monitoring

**Monitoring:**
- Uptime Kuma: Service availability
- Netdata: Resource usage

**Documentation:** `.claude/skills/n8n-*/`

---

### 3. GitHub Actions Runners (Multi-Org) - Optimized

**Purpose:** Self-hosted CI/CD for all GitHub organizations
**Type:** Custom Docker containers (4 runners with pre-installed tools)
**Location:** Proxmox Debian Docker VM (`/opt/github-runners`)
**Domain:** https://gitrunners.harbor.fyi
**Management:** docker-compose.multi-org.yml
**Image:** github-runner-optimized:latest (custom Dockerfile)

**Pre-installed Tools (Optimized for AI Enablement Projects):**
| Tool | Version | Purpose |
|------|---------|---------|
| Node.js | 20 LTS | Runtime for Next.js, build tools |
| Bun | Latest | Fast package manager, runtime |
| pnpm | Latest | Alternative package manager |
| Playwright | Latest | E2E testing (Chromium, Firefox, WebKit) |
| Lighthouse CI | Latest | Performance testing and audits |

**Organizations Served:**
1. **AI-Enablement-Academy** (runner-aea)
2. **OPEN-Talent-Society** (runner-ots)
3. **The-Talent-Foundation** (runner-ttf)
4. **adambkovacs** (runner-personal)

**Runner Labels:**
```yaml
runs-on: [self-hosted, linux, x64, bun, node20, playwright, lighthouse, <org>]
```

**Resource Allocation (per runner):**
- CPU: 2 cores limit, 1 core reserved
- Memory: 6GB limit, 3GB reserved (increased for Playwright)
- Total: 8 cores, 24GB RAM reserved

**Benefits:**
- Unlimited CI minutes across all accounts
- **Zero setup time:** Node, Bun, Playwright pre-installed
- **Faster CI:** No `setup-node`, `setup-bun`, `playwright install`
- Shared caching (Bun, npm, pnpm, Playwright results)
- Monorepo support with git worktrees
- Centralized management

**Cache Sharing:**
- Bun cache: `./cache/bun` (shared)
- npm cache: `./cache/npm` (shared)
- pnpm store: `./cache/pnpm` (shared)
- Playwright results: `./cache/playwright` (shared)
- Runner data: Per-organization

**Workflow Example:**
```yaml
jobs:
  build:
    runs-on: [self-hosted, node20, playwright]
    steps:
      - uses: actions/checkout@v4
      - run: bun install   # Bun already installed!
      - run: bun test
      - run: bun run test:e2e  # Playwright browsers ready!
```

**Monitoring:**
- Uptime Kuma: Container health
- Netdata: Resource usage per runner
- GitHub: Runner connection status

**Documentation:** `.infrastructure/github-runners/README.md`

---

### 4. Vaultwarden (Bitwarden)

**Purpose:** Self-hosted password and secrets manager
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://bitwarden.harbor.fyi
**Features:**
- Password management
- SSH key storage
- API key vault
- Secure notes
- 2FA integration

**Integration:**
- Claude Code secret retrieval
- SSH key management
- API credential storage

**Monitoring:**
- Uptime Kuma: HTTPS endpoint
- Netdata: Container metrics

**Documentation:** `.claude/skills/vaultwarden-*/`

---

### 5. Netdata Monitoring

**Purpose:** Real-time infrastructure monitoring
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://netdata.harbor.fyi
**Features:**
- Real-time metrics (1-second resolution)
- Container monitoring
- Network traffic analysis
- Disk I/O tracking
- Process monitoring

**Monitored Services:**
- Qdrant
- N8N
- GitHub Runners (4 containers)
- Vaultwarden
- All Docker containers

**Alerts:**
- CPU usage > 80%
- Memory usage > 90%
- Disk space < 10%
- Container crashes

**Documentation:** `.claude/skills/netdata-monitoring/`

---

### 6. Uptime Kuma

**Purpose:** Service availability monitoring
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://status.aienablement.academy
**Features:**
- HTTP/HTTPS endpoint monitoring
- Docker container monitoring
- Multi-notification channels
- Status page
- SLA tracking

**Monitored Endpoints:**
- https://qdrant.harbor.fyi
- https://n8n.harbor.fyi
- https://gitrunners.harbor.fyi
- https://bitwarden.harbor.fyi
- https://netdata.harbor.fyi
- https://cortex.aienablement.academy
- https://ops.aienablement.academy (NocoDB)

**Notifications:**
- Email via Brevo
- Slack (future)
- Discord (future)

**Documentation:** `.claude/skills/uptime-kuma-manager/`

---

### 7. Dozzle Log Viewer

**Purpose:** Real-time Docker log aggregation
**Type:** Docker container
**Location:** Proxmox Debian Docker VM
**Domain:** https://logs.harbor.fyi
**Features:**
- Real-time log streaming
- Multi-container log viewing
- Log search and filtering
- No log storage (live only)

**Monitored Containers:**
- All Docker containers on host

**Documentation:** `.claude/skills/dozzle-log-manager/`

---

### 8. QNAP NAS (Harbor Storage)

**Purpose:** Network-attached storage and backups
**Type:** Physical NAS
**Model:** QNAP (specific model TBD)
**IP:** 192.168.50.251
**Ports:**
- SSH: 22
- Web UI: 8081
- SMB: 445

**Storage:**
- Backup path: `/mnt/harbor-nas/`
- Daily backups of all services
- Docker volume backups
- Configuration backups

**Backup Schedule:**
- Qdrant: Daily snapshots
- N8N workflows: Daily export
- Vaultwarden: Daily encrypted backup
- GitHub runner configs: Weekly

**Documentation:** `.claude/skills/qnap-nas-manager/`

---

### 9. Tailscale VPN

**Purpose:** Secure remote access to Harbor network
**Type:** Network overlay
**Features:**
- Zero-trust network access
- WireGuard-based VPN
- ACL-based access control
- MagicDNS for service discovery

**Accessible Services:**
- All harbor.fyi subdomains
- Internal 192.168.50.x network
- SSH access to Proxmox and containers

**Documentation:** `.claude/skills/tailscale-network-manager/`

---

## Network Architecture

### Domain Structure

**Primary Domain:** harbor.fyi (internal homelab)
**Production Domain:** aienablement.academy (public services)

**DNS Management:**
- Cloudflare DNS for aienablement.academy
- Local DNS for harbor.fyi
- Nginx Proxy Manager for reverse proxy

### Subdomains (harbor.fyi)

| Subdomain | Service | Port | SSL |
|-----------|---------|------|-----|
| qdrant.harbor.fyi | Qdrant Vector DB | 6333 | Yes |
| n8n.harbor.fyi | N8N Automation | 5678 | Yes |
| gitrunners.harbor.fyi | GitHub Runners | N/A | Yes |
| bitwarden.harbor.fyi | Vaultwarden | 80 | Yes |
| netdata.harbor.fyi | Netdata Monitoring | 19999 | Yes |
| logs.harbor.fyi | Dozzle Logs | 8080 | Yes |

### Subdomains (aienablement.academy)

| Subdomain | Service | Location | SSL |
|-----------|---------|----------|-----|
| status.aienablement.academy | Uptime Kuma | Harbor | Yes |
| cortex.aienablement.academy | SiYuan/Cortex | OCI | Yes |
| ops.aienablement.academy | NocoDB | OCI | Yes |
| n8n.aienablement.academy | N8N (Production) | OCI | Yes |
| forms.aienablement.academy | Formbricks | OCI | Yes |

---

## Resource Utilization

### Total Allocated Resources

**CPU:**
- GitHub Runners: 8 cores (4 × 2 cores)
- Qdrant: 2 cores
- N8N: 2 cores
- Other services: 4 cores
- **Total:** ~16 cores

**Memory:**
- GitHub Runners: 16GB (4 × 4GB)
- Qdrant: 4GB
- N8N: 2GB
- Other services: 4GB
- **Total:** ~26GB RAM

**Storage:**
- Docker volumes: ~50GB
- QNAP backups: ~500GB
- Qdrant data: ~10GB
- N8N workflows: ~5GB
- Logs: ~20GB

---

## Monitoring & Alerting

### Monitoring Stack

1. **Netdata** - Real-time metrics
2. **Uptime Kuma** - Availability monitoring
3. **Dozzle** - Log aggregation

### Alert Channels

- Email (via Brevo)
- Future: Slack, Discord

### Key Metrics Tracked

- Service uptime (99.9% target)
- Response time (< 500ms target)
- Resource usage (CPU, RAM, disk)
- Error rates
- Container health

---

## Backup Strategy

### Daily Backups (to QNAP NAS)

1. **Qdrant Collections**
   - Snapshot exports
   - JSON backups
   - Incremental sync

2. **N8N Workflows**
   - JSON export
   - Credential backup (encrypted)

3. **Vaultwarden**
   - Encrypted database dump
   - Attachment backup

4. **Docker Configs**
   - docker-compose.yml files
   - .env files (encrypted)
   - Volume snapshots

### Weekly Backups

1. **Full system snapshot**
2. **Proxmox VM backups**
3. **Configuration archive**

### Backup Retention

- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months

---

## Security

### Authentication

- **Vaultwarden:** Master password + 2FA
- **Cloudflare Access:** Zero Trust for public services
- **Tailscale:** Network-level access control

### SSL/TLS

- All external services: Let's Encrypt SSL
- Automatic renewal via Nginx Proxy Manager
- HTTPS-only for all domains

### Firewall

- UFW on all hosts
- Tailscale ACLs
- Cloudflare WAF for public services

### Secrets Management

- API keys: Vaultwarden
- Passwords: Vaultwarden
- SSH keys: Vaultwarden
- .env files: Git-ignored, encrypted backups

---

## Disaster Recovery

### Recovery Time Objectives (RTO)

- Critical services (Qdrant, N8N): 30 minutes
- GitHub Runners: 1 hour
- Monitoring: 2 hours

### Recovery Point Objectives (RPO)

- Qdrant data: 24 hours (daily backup)
- N8N workflows: 24 hours
- Vaultwarden: 24 hours

### Recovery Procedures

1. **Restore from QNAP backups**
2. **Redeploy Docker containers**
3. **Verify service connectivity**
4. **Update DNS if needed**

---

## Maintenance Windows

### Planned Maintenance

- **Weekly:** Sunday 2:00 AM - 4:00 AM UTC
- **Monthly:** First Sunday of month, 2:00 AM - 6:00 AM UTC

### Maintenance Tasks

- **Weekly:**
  - Docker image updates
  - Security patches
  - Log rotation

- **Monthly:**
  - Full system updates
  - Backup verification
  - Performance optimization

---

## Cost Analysis

### Hardware Costs

- Proxmox server: Existing hardware
- QNAP NAS: Existing hardware
- Network equipment: Existing hardware

### Operational Costs

- Electricity: ~$15/month
- Domain (harbor.fyi): $12/year
- Cloudflare (free tier): $0
- Total: ~$16-20/month

### Value Provided

- Unlimited GitHub CI minutes: $200+/month value
- Vector database: $100+/month value
- Workflow automation: $100+/month value
- Monitoring: $50+/month value
- **Total Value:** $450+/month for $20/month cost

**ROI:** 22.5x return on investment

---

## Future Expansion Plans

### Short-term (Q1 2025)

- Add more GitHub runner capacity
- Implement automated failover
- Enhanced monitoring dashboards

### Medium-term (Q2-Q3 2025)

- Kubernetes cluster for orchestration
- Multi-region backup replication
- Advanced analytics platform

### Long-term (2025+)

- Edge computing integration
- AI model hosting
- Multi-site infrastructure

---

## Documentation Index

### Infrastructure Docs

- `.infrastructure/HARBOR-INFRASTRUCTURE-INVENTORY.md` (this file)
- `.infrastructure/HARBOR-NETWORKING-MAP.md`
- `.infrastructure/HARBOR-SERVICE-DIRECTORY.md`
- `.infrastructure/github-runners/README-MULTI-ORG.md`

### Skills Documentation

- `.claude/skills/docker-*/` - Docker management
- `.claude/skills/proxmox-*/` - Proxmox operations
- `.claude/skills/n8n-*/` - N8N automation
- `.claude/skills/qdrant-*/` - Qdrant operations
- `.claude/skills/vaultwarden-*/` - Secrets management
- `.claude/skills/tailscale-*/` - Network access
- `.claude/skills/nas-*/` - NAS backup coordination

### Agent Documentation

- `.claude/agents/operations/docker-*.md` - Docker agents
- `.claude/agents/operations/proxmox-*.md` - Proxmox agents
- `.claude/agents/operations/n8n-*.md` - N8N agents

---

## Support & Contacts

**Primary Administrator:** Adam Kovacs
**Email:** username@aienablement.academy
**Monitoring Dashboard:** https://status.aienablement.academy

**Emergency Contacts:**
- Proxmox Console: Direct VM access
- Tailscale: Remote network access
- QNAP NAS: Physical access for recovery

---

**Document Version:** 1.0
**Last Review:** 2025-12-26
**Next Review:** 2026-01-26
