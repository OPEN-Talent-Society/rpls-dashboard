# Uptime Kuma Manager Skill

Configure and manage Uptime Kuma monitoring for all infrastructure services.

## Mission

Automate the configuration of 25+ service monitors across aienablement.academy and harbor.fyi domains, manage notifications, and create status pages.

## Capabilities

1. **Monitor Configuration**
   - Automatically configure HTTP(S) monitors for all services
   - Set up TCP monitors for database services
   - Configure Docker container monitors
   - Manage check intervals and retry logic

2. **Notification Management**
   - Email notifications via Brevo
   - Slack/Discord webhooks
   - Custom notification channels
   - Escalation policies

3. **Status Pages**
   - Public status page for aienablement.academy
   - Internal status page for harbor.fyi
   - Custom branding and themes
   - Incident management

4. **Health Checks**
   - HTTP status code validation
   - Response time tracking
   - SSL certificate monitoring
   - Keyword matching in responses

## Usage

### Configure All Monitors

```bash
Skill({ skill: "uptime-kuma-manager" })

# In skill context:
"Configure all 25 monitors from /tmp/uptime-kuma-services.json"
```

### Add New Monitor

```bash
Skill({ skill: "uptime-kuma-manager" })

# In skill context:
"Add monitor for newservice.aienablement.academy with 5-minute intervals"
```

### Check Monitor Status

```bash
Skill({ skill: "uptime-kuma-manager" })

# In skill context:
"Show status of all monitors and identify failing services"
```

## Configuration

**Uptime Kuma Details:**
- URL: `https://uptime.aienablement.academy`
- API: REST API for automation
- Monitors: 25 services (10 aienablement.academy + 15 harbor.fyi)

**Monitor Defaults:**
- HTTP(S) interval: 5 minutes
- TCP interval: 2 minutes
- Docker interval: 1 minute
- Retry: 3 attempts
- Timeout: 30 seconds

**Services:**

**aienablement.academy (10):**
- cortex.aienablement.academy - Cortex Knowledge Base
- wiki.aienablement.academy - Docmost Wiki
- ops.aienablement.academy - NocoDB Operations
- forms.aienablement.academy - Fillout Forms
- calendar.aienablement.academy - Cal.com Scheduling
- sign.aienablement.academy - DocuSeal Signatures
- monitor.aienablement.academy - Netdata Metrics
- metrics.aienablement.academy - Grafana Dashboards
- status.aienablement.academy - Status Page
- uptime.aienablement.academy - Uptime Kuma

**harbor.fyi (15):**
- nas.harbor.fyi - TrueNAS Storage
- nginx.harbor.fyi - Nginx Proxy Manager
- portainer.harbor.fyi - Portainer Container Management
- n8n.harbor.fyi - n8n Workflow Automation
- ddns.harbor.fyi - DDNS Service
- postiz.harbor.fyi - Postiz Social Media
- library.harbor.fyi - Calibre Library
- plex.harbor.fyi - Plex Media Server
- chat.harbor.fyi - Chat Service
- bookmarks.harbor.fyi - Bookmark Manager
- bitwarden.harbor.fyi - Bitwarden Password Manager
- supabase.harbor.fyi - Supabase Database
- mem0.harbor.fyi - Mem0 Memory Service
- jellyfin.harbor.fyi - Jellyfin Media Server
- qdrant.harbor.fyi - Qdrant Vector Database

## Implementation

When this skill is invoked:

1. **Read services configuration** from `/tmp/uptime-kuma-services.json`
2. **Use setup script** at `.claude/skills/uptime-kuma-manager/scripts/setup-monitors.sh`
3. **Configure monitors** via Uptime Kuma API or CLI
4. **Set up notifications** for all monitors
5. **Create status pages** for public/internal use
6. **Validate** all monitors are working

## Scripts

- `setup-monitors.sh` - Configure all monitors from JSON
- `add-monitor.sh` - Add a single monitor
- `update-monitor.sh` - Update existing monitor
- `delete-monitor.sh` - Remove monitor
- `export-config.sh` - Backup monitor configuration
- `import-config.sh` - Restore monitor configuration

## Integration

**Works with:**
- `netdata-monitoring` - System metrics and alerting
- `dozzle-log-manager` - Log correlation during incidents
- `monitoring-alerting` - Unified alert management
- `health-monitor` - Infrastructure health checks

**Triggers:**
- Session start: Check Uptime Kuma is accessible
- Pre-deployment: Verify monitors for affected services
- Post-deployment: Validate service health
- Incident: Correlate with logs and metrics

## Best Practices

1. **Monitor Naming**: Use FQDN as monitor name for clarity
2. **Tagging**: Tag monitors by domain, service type, criticality
3. **Intervals**: Critical services = 1 min, others = 5 min
4. **Notifications**: Group by severity and on-call rotation
5. **Maintenance**: Schedule maintenance windows to avoid false alerts

## Troubleshooting

**Monitor shows down but service is up:**
- Check firewall rules
- Verify SSL certificates
- Validate DNS resolution
- Check response time thresholds

**Too many alerts:**
- Increase retry count
- Adjust check intervals
- Review timeout settings
- Implement notification grouping

**Uptime Kuma not accessible:**
- Check Docker container status
- Verify reverse proxy configuration
- Check SSL certificate expiration
- Review Cloudflare DNS settings

## API Reference

```bash
# Uptime Kuma API endpoints (requires authentication)
POST /api/monitor - Create monitor
GET /api/monitor/:id - Get monitor details
PUT /api/monitor/:id - Update monitor
DELETE /api/monitor/:id - Delete monitor
GET /api/status-page - Get status page
POST /api/notification - Add notification
```

## Related

- Skill: `netdata-monitoring` - System metrics
- Skill: `dozzle-log-manager` - Log aggregation
- Skill: `monitoring-alerting` - Alert orchestration
- Command: `/uptime-status` - Quick status check
- Script: `infrastructure-ops/scripts/monitoring/uptime-kuma-setup.sh`

---

**Last Updated:** 2025-12-06
**Category:** Infrastructure, Monitoring
**Priority:** High
