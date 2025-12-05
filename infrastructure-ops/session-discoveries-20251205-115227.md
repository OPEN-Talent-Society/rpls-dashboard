# Infrastructure Discovery Session - 2025-12-05

## Key Discoveries

### 1. DNS Migration Resolved
- **Issue**: After migrating aienablement.academy to new Cloudflare account, DNS records pointed to old Cloudflare anycast IPs
- **Solution**: Deleted 15+ duplicate records, created correct ones pointing to origin servers
- **Result**: All 13 aienablement.academy services now working

### 2. Complete Infrastructure Inventory
- **Location**: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/infrastructure-discovery-report.md`
- **Scope**: 66+ services across OCI (28 containers) and homelab (34+ containers, 4 LXC, 4 VMs)
- **Critical Finding**: OCI disk at 83% capacity

### 3. Service Locations Confirmed
- **Netdata**: On OCI → metrics.aienablement.academy is CORRECT
- **dash.harbor.fyi**: Was deployed as dash.aienablement.academy (found in activity.json)
- **nas.harbor.fyi**: QNAP at 192.168.50.251, needs simple HTTP proxy (no port/SSL)

### 4. Monitoring Status
**Current Coverage**: Only 2/29 domains (~7%)
- ✅ Monitored: status.aienablement.academy, uptime.aienablement.academy
- ❌ Missing: 10 aienablement.academy + 19 harbor.fyi services
- ❌ Missing: Infrastructure health (disk, memory, SSL certs)

**Current Stack (Scattered)**:
- Uptime Kuma: status + uptime subdomains
- Netdata: metrics.aienablement.academy
- Dozzle: monitor.aienablement.academy

### 5. harbor.fyi Services Inventory
**Working (11)**:
- n8n, qdrant, jellyfin, ddns, nginx, portainer, bitwarden, bookmarks, chat, postiz, supabase

**Issues (4)**:
- dash: Not configured in NPM (was at dash.aienablement.academy)
- nas: Config needs fixing (192.168.50.251, HTTP, no port)
- library, mem0: Backend services down/unused

### 6. Critical Issues Found
1. **OCI Disk**: 83% full (38GB/45GB) - needs cleanup
2. **Broken Containers**: Cal.com (unhealthy), Supabase-auth (restart loop), Supabase-realtime (unhealthy)
3. **Exposed Ports**: 3 services publicly exposed without reverse proxy (security risk)
4. **Duplicate NPM Entries**: Multiple proxy hosts for same services

### 7. Infrastructure Repository
- **Location**: https://github.com/AI-Enablement-Academy/infrastructure
- **Local**: `/Users/adamkovacs/Documents/codebuild/infrastructure`
- **Contains**: 
  - ops/dash/ - Landing page HTML and Docker setup
  - ops/backup/ - Backup scripts and automation
  - .docs/ - Runbooks and operational guides

## Technical Details

### OCI Server (163.192.41.116)
- OS: Ubuntu 22.04 ARM64
- Memory: 23GB total, 18GB available
- Disk: 45GB total, 38GB used (83% ⚠️)
- Reverse Proxy: Caddy (edge-proxy)
- Networks: reverse-proxy + isolated per-stack networks

### Homelab (100.103.83.62 - Tailscale)
- Proxmox host
- Docker VM: 192.168.50.149 (VM 101)
- NPM LXC: 192.168.50.45 (LXC 106)
- QNAP NAS: 192.168.50.251
- Reverse Proxy: Nginx Proxy Manager

### DNS Configuration
**Cloudflare (aienablement.academy)**:
- Zone ID: 867d062b45f08b4f148828ac6212728c (NEW)
- Old Zone: 78bc8afbb8fbc182da21dde984fd005f (docs need updating)
- 13 active subdomains

**Porkbun (harbor.fyi)**:
- Points to: 50.47.243.79 (homelab public IP)
- 14+ active subdomains via NPM

## Next Steps

### Immediate (High Priority)
1. Fix nas.harbor.fyi NPM config and restart NPM
2. Free up OCI disk space (docker system prune)
3. Deploy or locate dash.harbor.fyi properly
4. Create comprehensive monitoring consolidation plan

### Monitoring Setup (Critical)
1. Add all 29 domains to Uptime Kuma
2. Configure infrastructure health checks
3. Set up SSL certificate expiry monitoring
4. Add Docker container health checks

### Alerting (After Monitoring)
1. Push notifications: opensource/lightweight (Ntfy, Gotify, Pushover)
2. SMS: Twilio or alternative
3. Email: Brevo (already configured)

### Cleanup
1. Remove unused services (mem0, etc)
2. Fix broken containers (Cal.com, Supabase)
3. Secure exposed ports
4. Remove duplicate NPM entries

## Files Created This Session
- `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/` - New infrastructure docs folder
- `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/README.md` - Infrastructure overview
- `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/infrastructure-discovery-report.md` - Complete service inventory

## Memory Storage
- Session ID: session-20251205
- Pattern: Comprehensive infrastructure discovery and DNS troubleshooting
- Success: ✅ All DNS issues resolved, complete infrastructure mapped
- Reward: 0.95 (high success, comprehensive documentation)
