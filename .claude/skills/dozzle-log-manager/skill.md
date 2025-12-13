# Dozzle Log Manager Skill

Real-time Docker log aggregation, search, and analysis using Dozzle.

## Mission

Deploy and manage Dozzle for centralized Docker container log viewing, searching, and troubleshooting across all infrastructure.

## Capabilities

1. **Log Aggregation**
   - Real-time log streaming from all Docker containers
   - Multi-host log collection
   - Historical log retention
   - Log file export

2. **Search & Filter**
   - Full-text search across all logs
   - Container-specific filtering
   - Time-range filtering
   - Regex pattern matching

3. **Visualization**
   - Color-coded log levels
   - Multi-container view
   - Split-screen comparison
   - Log statistics

4. **Troubleshooting**
   - Error pattern detection
   - Log correlation across containers
   - Container resource usage
   - Quick container restart

## Usage

### Deploy Dozzle

```bash
Skill({ skill: "dozzle-log-manager" })

# In skill context:
"Deploy Dozzle with multi-host support for all Docker infrastructure"
```

### Search Logs

```bash
Skill({ skill: "dozzle-log-manager" })

# In skill context:
"Search for errors in nginx container from last 24 hours"
```

### Analyze Container Logs

```bash
Skill({ skill: "dozzle-log-manager" })

# In skill context:
"Show all ERROR level logs across containers in the last hour"
```

## Configuration

**Dozzle Details:**
- Dashboard: `https://logs.aienablement.academy`
- Port: 8080
- Docker Socket: `/var/run/docker.sock`
- Config: `/data/dozzle/config.yml`

**Deployment:**

1. **Primary Host** (docker-vm.internal):
   - Monitors all containers on Docker VM
   - Exposed via reverse proxy
   - Authentication enabled

2. **Multi-Host** (optional):
   - Connect to remote Docker hosts
   - Aggregated view of all infrastructure
   - Secure socket forwarding

**Log Sources:**

- **Web Services**: nginx, caddy, traefik
- **Databases**: postgres, mysql, redis, qdrant
- **Applications**: n8n, docmost, nocodb, cortex
- **Infrastructure**: portainer, watchtower, ddns-updater
- **Media**: plex, jellyfin, calibre-web
- **Security**: bitwarden, supabase-auth

## Implementation

When this skill is invoked:

1. **Deploy Dozzle** as Docker container
2. **Configure multi-host** if multiple Docker hosts
3. **Set up authentication** for secure access
4. **Configure reverse proxy** for HTTPS access
5. **Set log retention** based on storage capacity
6. **Test log streaming** from all containers

## Scripts

- `deploy-dozzle.sh` - Deploy Dozzle container
- `configure-multihost.sh` - Set up multi-host log aggregation
- `setup-auth.sh` - Configure authentication
- `export-logs.sh` - Export logs for analysis
- `rotate-logs.sh` - Rotate and compress old logs
- `health-check.sh` - Verify Dozzle is running

## Docker Compose

```yaml
version: '3.8'

services:
  dozzle:
    image: amir20/dozzle:latest
    container_name: dozzle
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data/dozzle:/data
    environment:
      DOZZLE_LEVEL: info
      DOZZLE_TAILSIZE: 300
      DOZZLE_FILTER: "status=running"
      DOZZLE_AUTH_PROVIDER: simple
      DOZZLE_AUTH_USERNAME: admin
      DOZZLE_AUTH_PASSWORD: ${DOZZLE_PASSWORD}
      DOZZLE_ENABLE_ACTIONS: true
      DOZZLE_REMOTE_HOST: |
        docker-vm|tcp://docker-vm.internal:2375
    networks:
      - monitoring

networks:
  monitoring:
    external: true
```

## Features

**Real-time Streaming:**
- Live log tailing with auto-scroll
- Pause/resume streaming
- Clear log buffer
- Download logs

**Search:**
- Full-text search
- Case-sensitive/insensitive
- Regex support
- Multi-line search

**Filters:**
- By container name
- By log level (INFO, WARN, ERROR)
- By time range
- By content pattern

**Actions:**
- Restart container
- Stop container
- View container stats
- Open container shell

## Integration

**Works with:**
- `uptime-kuma-manager` - Correlate downtime with logs
- `netdata-monitoring` - Cross-reference metrics with logs
- `monitoring-alerting` - Log-based alerting
- `docker-deploy` - Deployment verification via logs

**Triggers:**
- Uptime Kuma alert: View logs of affected service
- Netdata metric spike: Check logs for errors
- Deployment: Verify successful startup
- Incident: Investigate root cause

## Best Practices

1. **Log Levels**: Use structured logging (INFO/WARN/ERROR)
2. **Retention**: Keep 7 days of logs locally
3. **Authentication**: Always enable auth for production
4. **SSL**: Use reverse proxy with HTTPS
5. **Monitoring**: Monitor Dozzle itself via Uptime Kuma

## Troubleshooting

**Dozzle not showing containers:**
- Verify Docker socket is mounted: `ls -la /var/run/docker.sock`
- Check Dozzle has socket permissions
- Review Dozzle logs: `docker logs dozzle`
- Verify container filter settings

**Logs not updating:**
- Check container is running: `docker ps`
- Verify container is producing logs
- Check Dozzle connection to Docker daemon
- Restart Dozzle container

**Cannot connect to remote host:**
- Verify Docker TCP socket is exposed
- Check firewall rules for port 2375
- Validate remote host configuration
- Test connection: `curl http://remote:2375/_ping`

**High memory usage:**
- Reduce tail size: `DOZZLE_TAILSIZE=100`
- Limit log retention
- Filter containers: `DOZZLE_FILTER="label!=exclude"`
- Restart Dozzle periodically

## Advanced Configuration

**Multi-Host Setup:**
```yaml
environment:
  DOZZLE_REMOTE_HOST: |
    proxmox-01|tcp://proxmox-01.internal:2375
    proxmox-02|tcp://proxmox-02.internal:2375
    docker-vm|tcp://docker-vm.internal:2375
```

**Container Filtering:**
```yaml
environment:
  # Only show containers with specific label
  DOZZLE_FILTER: "label=monitoring=true"

  # Exclude system containers
  DOZZLE_FILTER: "name!=^/dozzle$"
```

**Custom Authentication:**
```yaml
environment:
  DOZZLE_AUTH_PROVIDER: forward-proxy
  DOZZLE_AUTH_HEADER: X-Forwarded-User
```

## Log Analysis Patterns

**Common Searches:**

1. **Find errors in last hour:**
   ```
   Search: ERROR
   Time: Last 1 hour
   ```

2. **Database connection issues:**
   ```
   Search: connection.*refused|timeout
   Container: postgres, mysql
   ```

3. **Memory errors:**
   ```
   Search: OutOfMemory|OOM|killed
   All containers
   ```

4. **HTTP 500 errors:**
   ```
   Search: HTTP.*500|Internal Server Error
   Container: nginx, caddy
   ```

## Performance Tips

1. **Limit Tail Size**: Default 300 lines, reduce for many containers
2. **Use Filters**: Only show relevant containers
3. **Time Range**: Narrow search window for faster results
4. **Resource Limits**: Set memory/CPU limits on Dozzle container
5. **Log Rotation**: Configure log rotation on Docker daemon

## Related

- Skill: `uptime-kuma-manager` - Service uptime monitoring
- Skill: `netdata-monitoring` - System metrics
- Skill: `monitoring-alerting` - Alert management
- Command: `/logs <container>` - Quick log access
- Command: `/docker-logs` - Alternative log viewer
- Script: `infrastructure-ops/scripts/monitoring/dozzle-setup.sh`

---

**Last Updated:** 2025-12-06
**Category:** Infrastructure, Monitoring, Logging
**Priority:** High
