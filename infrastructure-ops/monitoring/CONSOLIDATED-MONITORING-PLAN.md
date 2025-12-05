# Consolidated Monitoring Plan
**Created:** 2025-12-05
**Status:** Draft
**Objective:** Rock-solid, comprehensive, secure monitoring across ALL infrastructure

---

## Current State Analysis

### Existing Monitoring Services

| Service | Domain | Location | Purpose | Access | Status |
|---------|--------|----------|---------|--------|--------|
| **Uptime Kuma** | uptime.aienablement.academy | OCI | HTTP/TCP monitoring, public status page | Cloudflare Access + login | ✅ Active |
| **Uptime Kuma** | status.aienablement.academy | OCI | Public status page | Public read-only | ✅ Active |
| **Dozzle** | monitor.aienablement.academy | OCI | Docker container logs (OCI only) | Cloudflare Access | ✅ Active |
| **Netdata** | metrics.aienablement.academy | OCI | System metrics (OCI host) | Cloudflare Access + portal login | ✅ Active |

### Coverage Gaps (CRITICAL)

Currently monitoring **2/29 domains** (~7%):
- ❌ **10 aienablement.academy services** not monitored
- ❌ **19 harbor.fyi services** not monitored
- ❌ No infrastructure health checks (disk, memory, SSL certs)
- ❌ No homelab Proxmox/LXC/VM monitoring
- ❌ No homelab Docker container monitoring

### Security Assessment

✅ **Good:**
- Cloudflare Access on admin interfaces
- Service tokens for automation
- Login gates on sensitive services

⚠️ **Needs Improvement:**
- Monitoring services only cover OCI, not homelab
- No centralized alerting
- Some services exposed without auth (status page is intentional)

---

## Proposed Consolidated Architecture

### Design Principles

1. **Separation of Concerns**
   - Public status page (status.aienablement.academy) - read-only, no auth
   - Admin interfaces (uptime/monitor/metrics) - Cloudflare Access + auth
   - Internal monitoring - Tailscale only

2. **Monitoring Layers**
   - **Layer 1: Service Health** - HTTP/TCP checks (Uptime Kuma)
   - **Layer 2: Container Health** - Docker logs and stats (Dozzle + Netdata)
   - **Layer 3: System Health** - CPU/RAM/disk/network (Netdata)
   - **Layer 4: Infrastructure** - Proxmox, SSL certs, DNS

3. **Security by Default**
   - Admin tools behind Cloudflare Access
   - Internal tools on Tailscale only
   - Service tokens for automation
   - No credentials in configs (env files only)

---

## Implementation Plan

### Phase 1: Complete Uptime Kuma Coverage (HIGH PRIORITY)

**Add all 29 domains to Uptime Kuma:**

#### aienablement.academy (10 services)
- [ ] aienablement.academy (main site - Lovable)
- [ ] www.aienablement.academy
- [ ] wiki.aienablement.academy (Docmost)
- [ ] forms.aienablement.academy (Formbricks)
- [ ] ops.aienablement.academy (NocoDB)
- [ ] cortex.aienablement.academy (SiYuan)
- [ ] calendar.aienablement.academy (Cal.com)
- [ ] sign.aienablement.academy (OpenSign)
- [ ] preview.aienablement.academy (Vercel)
- [ ] n8n.aienablement.academy (n8n automation)

#### harbor.fyi (19 services)
- [ ] n8n.harbor.fyi
- [ ] qdrant.harbor.fyi
- [ ] jellyfin.harbor.fyi
- [ ] ddns.harbor.fyi
- [ ] nginx.harbor.fyi (NPM admin)
- [ ] portainer.harbor.fyi
- [ ] bitwarden.harbor.fyi
- [ ] bookmarks.harbor.fyi
- [ ] chat.harbor.fyi
- [ ] postiz.harbor.fyi
- [ ] supabase.harbor.fyi
- [ ] library.harbor.fyi (⚠️ currently timeout)
- [ ] nas.harbor.fyi (QNAP)
- [ ] mem0.harbor.fyi (⚠️ 502 - to be removed)
- [ ] dash.harbor.fyi (never deployed - use dash.aienablement.academy instead)

**Monitor Configuration:**
- Check interval: 60s for critical services, 300s for secondary
- Retries: 3 before marking down
- Timeout: 10s for HTTP, 5s for TCP
- Notifications: Default notification group (to be configured in Phase 3)

---

### Phase 2: Infrastructure Health Monitoring (HIGH PRIORITY)

#### Install Netdata on Homelab

**Target:** Proxmox host + all LXC containers + Docker VM

1. **Proxmox Host** (100.103.83.62)
   - Install Netdata directly on Proxmox
   - Monitor: CPU, RAM, disk, network, ZFS pools
   - Access: Tailscale only (100.x.x.x:19999)

2. **LXC Containers** (104-106)
   - LXC 104: Supabase stack
   - LXC 105: n8n instance
   - LXC 106: Nginx Proxy Manager
   - Install Netdata in each
   - Access: Tailscale only

3. **Docker VM** (101)
   - Install Netdata on the VM
   - Monitor all Docker containers via Docker socket
   - Access: Tailscale only or proxy via NPM

#### Deployment Method

**Option A: Netdata Cloud Stream (RECOMMENDED)**
- Install Netdata on each host
- All stream to Netdata parent on OCI
- Single dashboard at metrics.aienablement.academy
- Pros: Centralized, existing setup
- Cons: Requires network connectivity

**Option B: Separate Netdata Instances**
- Each host has its own Netdata
- Access via Tailscale or NPM proxies
- Pros: Independent, survives network issues
- Cons: Multiple dashboards

**Decision:** Use Option A with Option B as fallback (all accessible via Tailscale directly)

---

#### SSL Certificate Monitoring

Add to Uptime Kuma:
- [ ] Enable SSL expiry checks on all HTTPS monitors
- [ ] Alert 30 days before expiration
- [ ] Check Let's Encrypt renewal logs

---

#### Disk Space Monitoring

**Current Critical Issue:** OCI disk at 83% capacity

Netdata monitors:
- [ ] OCI: /dev/sda1 disk usage (alert at 80%, critical at 90%)
- [ ] Homelab Proxmox: ZFS pool usage
- [ ] Docker volumes on both hosts

---

### Phase 3: Alerting System (HIGH PRIORITY)

#### Alert Channels

1. **Email (Primary)** - Brevo
   - Already configured in Uptime Kuma
   - Use for all alerts
   - Email: adam@aienablement.academy

2. **Push Notifications** - Ntfy.sh (opensource, lightweight)
   - Self-hosted ntfy server OR use ntfy.sh public instance
   - Mobile app available (iOS/Android)
   - Supports priorities, attachments, actions
   - Implementation:
     ```bash
     # Option 1: Self-hosted (recommended)
     docker run -d -p 8082:80 -v /srv/ntfy:/var/cache/ntfy binwiederhier/ntfy serve

     # Option 2: Public instance (quick start)
     curl -d "Service down: wiki.aienablement.academy" ntfy.sh/aienablement-alerts
     ```

3. **SMS (High-Priority Only)** - Twilio OR Brevo SMS
   - Use for critical services only (main site, database, auth)
   - Brevo pricing: $0.10-0.15 per SMS (cheaper than Twilio)
   - Configure in Uptime Kuma as secondary notification

#### Alert Rules

**Priority Levels:**

| Priority | Services | Channels | Example |
|----------|----------|----------|---------|
| **Critical** | Main site, auth, databases | Email + Push + SMS | aienablement.academy down |
| **High** | Core services (wiki, ops, calendar) | Email + Push | ops.aienablement.academy down |
| **Medium** | Supporting services (monitoring, logs) | Email + Push | dozzle timeout |
| **Low** | Development/test services | Email only | preview.aienablement.academy |

**Thresholds:**
- Down time: Alert after 2 failed checks (2 minutes)
- SSL expiry: 30 days warning, 7 days critical
- Disk space: 80% warning, 90% critical
- CPU: 80% sustained for 5m warning
- Memory: 90% warning

---

### Phase 4: Monitoring Domain Consolidation (MEDIUM PRIORITY)

**Current Situation:**
- 4 monitoring domains on aienablement.academy (status, uptime, monitor, metrics)
- 0 monitoring domains on harbor.fyi

**Proposed Cleanup:**

Keep on **aienablement.academy** (public-facing):
- ✅ status.aienablement.academy - Public status page
- ✅ uptime.aienablement.academy - Uptime Kuma admin (Cloudflare Access)

Move to **harbor.fyi** (internal operations):
- 🔄 monitor.harbor.fyi - Dozzle (replace monitor.aienablement.academy)
- 🔄 metrics.harbor.fyi - Netdata (replace metrics.aienablement.academy)

**Benefits:**
- Clear separation: public status vs internal operations
- Aligns with domain purposes (academy = public, harbor = internal)
- Reduces DNS records on primary domain

**Migration Steps:**
1. Create monitor.harbor.fyi and metrics.harbor.fyi DNS
2. Add NPM proxy hosts pointing to OCI
3. Update Cloudflare Access policies
4. Test new domains
5. Deprecate old domains (keep redirects for 30 days)

---

### Phase 5: Service Cleanup (LOW PRIORITY)

**Services to Remove:**

Homelab Docker:
- [ ] mem0.harbor.fyi (502 error, not in use)
- [ ] library.harbor.fyi (timeout, unknown purpose)

OCI:
- [ ] dash.aienablement.academy (525 error, needs investigation)
- [ ] Mailpit container (if still present - was supposed to be removed per activity.json)

**Investigation Needed:**
- [ ] dash.aienablement.academy SSL issue (currently 525)
- [ ] Cal.com broken container (supabase-auth, supabase-realtime)

---

## Security Hardening

### Access Control Matrix

| Service | Public | Cloudflare Access | Tailscale | Login Required |
|---------|--------|-------------------|-----------|----------------|
| status.aienablement.academy | ✅ | ❌ | ❌ | ❌ |
| uptime.aienablement.academy | ❌ | ✅ | ✅ | ✅ |
| monitor.* | ❌ | ✅ | ✅ | ❌ (Access is auth) |
| metrics.* | ❌ | ✅ | ✅ | ✅ (portal login) |
| Homelab Netdata | ❌ | ❌ | ✅ | ❌ |

### Tailscale ACLs

```json
{
  "hosts": {
    "oci": "163.192.41.116",
    "homelab": "100.103.83.62"
  },
  "acls": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:infra:*"]
    },
    {
      "action": "accept",
      "src": ["autogroup:member"],
      "dst": ["tag:infra:19999"]
    }
  ],
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:admin"],
      "dst": ["tag:infra"],
      "users": ["root", "ubuntu"]
    }
  ]
}
```

---

## Implementation Timeline

### Immediate (Today)
- [x] Fix nas.harbor.fyi configuration
- [x] Document monitoring plan
- [ ] Add all 29 domains to Uptime Kuma
- [ ] Configure Ntfy push notifications
- [ ] Set up alert rules

### This Week
- [ ] Install Netdata on homelab Proxmox + LXCs + Docker VM
- [ ] Configure Netdata streaming to OCI parent
- [ ] Set up SMS alerting via Brevo
- [ ] Fix dash.aienablement.academy SSL issue
- [ ] Remove mem0 and library containers

### Next Week
- [ ] Migrate monitor/metrics to harbor.fyi
- [ ] Create monitoring runbook
- [ ] Test failover scenarios
- [ ] Document alert response procedures

---

## Monitoring Stack Summary

### Final Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Public Status Page                        │
│           status.aienablement.academy                        │
│                  (read-only, no auth)                        │
└─────────────────────────────────────────────────────────────┘
                           │
                           │
┌──────────────────────────┴───────────────────────────────────┐
│                                                               │
│  Uptime Kuma (OCI)                                           │
│  uptime.aienablement.academy                                 │
│  - 29 domain monitors                                        │
│  - SSL expiry checks                                         │
│  - Alert management                                          │
│                                                               │
└───────────────────────┬─────────────────────┬────────────────┘
                        │                     │
              ┌─────────┴──────────┐ ┌────────┴─────────────┐
              │                    │ │                      │
              │  Netdata (OCI)     │ │  Dozzle (OCI)        │
              │  metrics.*         │ │  monitor.*           │
              │  - OCI host        │ │  - OCI containers    │
              │  - Homelab streams │ │                      │
              │  - All systems     │ │                      │
              │                    │ │                      │
              └────────────────────┘ └──────────────────────┘
                        │
              ┌─────────┴──────────┐
              │                    │
              │  Netdata Agents    │
              │  (Tailscale only)  │
              │  - Proxmox         │
              │  - LXC 104-106     │
              │  - Docker VM       │
              │                    │
              └────────────────────┘
```

### Alert Flow

```
Service Down ──► Uptime Kuma ──┬──► Email (Brevo)
                                ├──► Push (Ntfy)
                                └──► SMS (Brevo - critical only)

Disk 90% Full ─► Netdata ──────┬──► Webhook to Uptime Kuma
                                └──► (Uptime Kuma handles notifications)

SSL Expiring ──► Uptime Kuma ──┬──► Email 30 days before
                                ├──► Push + Email 7 days before
                                └──► SMS 24h before
```

---

## Cost Analysis

| Service | Provider | Cost/Month | Notes |
|---------|----------|------------|-------|
| Uptime Kuma | Self-hosted | $0 | Included in OCI |
| Netdata | Self-hosted | $0 | Included in OCI + Homelab |
| Dozzle | Self-hosted | $0 | Included in OCI |
| Ntfy | Self-hosted | $0 | OR use free ntfy.sh tier |
| Email alerts | Brevo | $0 | Included in current plan |
| SMS alerts | Brevo | ~$1-5 | Pay per use (~10-50 SMS/mo) |
| Cloudflare Access | Cloudflare | $0 | Free tier (up to 50 users) |
| Tailscale | Tailscale | $0 | Free tier (up to 100 devices) |
| **Total** | | **$1-5/mo** | SMS only variable cost |

---

## Success Criteria

✅ **Coverage**
- All 29 domains monitored
- All infrastructure hosts monitored
- SSL certificates tracked

✅ **Alerting**
- Email alerts working
- Push notifications working
- SMS for critical services

✅ **Security**
- Admin interfaces behind Access
- Internal tools on Tailscale
- No public exposure without auth

✅ **Reliability**
- < 5 minute detection time
- < 15 minute response time
- Zero false positives

---

## Next Steps

1. Review and approve this plan
2. Begin Phase 1: Add all domains to Uptime Kuma
3. Set up Ntfy push notifications
4. Install Netdata on homelab
5. Configure alerting channels

**Estimated Time:** 4-6 hours total implementation
**Risk Level:** Low (all changes are additive, no disruption to existing services)
