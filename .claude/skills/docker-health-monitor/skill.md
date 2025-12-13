# Docker Health Monitor Skill

Automated container health monitoring and self-healing for Docker environments.

## Environment

**Docker VM**: 192.168.50.149
- 33 containers requiring continuous monitoring
- Critical services: Supabase, LibreChat, N8N, Vaultwarden

## Core Capabilities

### 1. Health Check Monitoring

Monitor container health status and automatically restart unhealthy containers:

```bash
# Check health status of all containers
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}" | grep -E "(unhealthy|starting)"

# Get unhealthy containers
docker ps --filter health=unhealthy --format "{{.Names}}"

# Check container health via inspect
docker inspect --format='{{.State.Health.Status}}' <container>
```

### 2. Auto-Restart Unhealthy Containers

```bash
# Restart all unhealthy containers
docker ps --filter health=unhealthy -q | xargs -r docker restart

# Restart with specific wait time
for container in $(docker ps --filter health=unhealthy -q); do
  docker restart -t 30 "$container"
  sleep 10
done

# Force recreate if restart fails
docker compose ps --filter health=unhealthy -q | xargs -r docker compose up -d --force-recreate
```

### 3. Container Resource Monitoring

```bash
# Monitor CPU and memory usage
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"

# Alert on high resource usage (>80%)
docker stats --no-stream --format "{{.Name}},{{.MemPerc}}" | awk -F',' '$2 > 80 {print $1}'

# Check disk usage
docker system df
docker system df -v  # Verbose output
```

### 4. Log Analysis

```bash
# Check for errors in logs (last 100 lines)
docker logs --tail=100 <container> 2>&1 | grep -iE "(error|fatal|exception|failed)"

# Monitor logs in real-time
docker logs -f --since 5m <container>

# Export logs for analysis
docker logs <container> --since 24h > /tmp/container-logs.txt
```

### 5. Network Health Checks

```bash
# Check container connectivity
docker exec <container> ping -c 3 8.8.8.8

# Check DNS resolution
docker exec <container> nslookup google.com

# Check port availability
docker exec <container> nc -zv localhost 8080

# Inspect network
docker network inspect <network> | jq '.[0].Containers'
```

## Health Check Best Practices (2025)

### Define Health Checks in Docker Compose

```yaml
services:
  api:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s          # Check every 30 seconds
      timeout: 10s           # Fail if check takes >10s
      retries: 3             # Mark unhealthy after 3 failures
      start_period: 40s      # Grace period for startup
      start_interval: 5s     # Check every 5s during start_period
    restart: unless-stopped
```

### Different Health Check Types

#### HTTP Endpoint

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

#### TCP Socket

```yaml
healthcheck:
  test: ["CMD-SHELL", "nc -z localhost 5432 || exit 1"]
  interval: 20s
  timeout: 5s
  retries: 3
```

#### Process Check

```yaml
healthcheck:
  test: ["CMD-SHELL", "pgrep -f nginx || exit 1"]
  interval: 30s
  timeout: 5s
  retries: 3
```

#### Custom Script

```yaml
healthcheck:
  test: ["CMD", "/app/healthcheck.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### Database Health Checks

#### PostgreSQL

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```

#### Redis

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 3s
  retries: 3
```

#### MongoDB

```yaml
healthcheck:
  test: ["CMD", "mongosh", "--eval", "db.adminCommand('ping')"]
  interval: 10s
  timeout: 5s
  retries: 3
```

## Automated Health Monitoring Script

```bash
#!/bin/bash
# /opt/scripts/docker-health-monitor.sh

set -euo pipefail

LOG_FILE="/var/log/docker-health-monitor.log"
ALERT_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK/URL"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

alert() {
  local message="$1"
  log "ALERT: $message"

  # Send to Slack/Discord/Email
  curl -X POST "$ALERT_WEBHOOK" \
    -H 'Content-Type: application/json' \
    -d "{\"text\":\"Docker Health Alert: $message\"}" || true
}

check_unhealthy_containers() {
  local unhealthy
  unhealthy=$(docker ps --filter health=unhealthy --format "{{.Names}}")

  if [ -n "$unhealthy" ]; then
    log "Found unhealthy containers: $unhealthy"
    alert "Unhealthy containers detected: $unhealthy"

    # Attempt restart
    for container in $unhealthy; do
      log "Restarting unhealthy container: $container"
      docker restart "$container"
      sleep 10

      # Check if restart fixed the issue
      if docker ps --filter "name=$container" --filter health=unhealthy | grep -q "$container"; then
        alert "CRITICAL: Container $container still unhealthy after restart"
      else
        log "Container $container is now healthy"
      fi
    done
  fi
}

check_exited_containers() {
  local exited
  exited=$(docker ps -a --filter status=exited --filter restart=unless-stopped --format "{{.Names}}")

  if [ -n "$exited" ]; then
    log "Found exited containers: $exited"
    alert "Containers unexpectedly exited: $exited"

    # Attempt restart
    for container in $exited; do
      log "Starting exited container: $container"
      docker start "$container" || alert "Failed to start $container"
    done
  fi
}

check_resource_usage() {
  # Alert if any container uses >90% memory
  docker stats --no-stream --format "{{.Name}},{{.MemPerc}}" | while IFS=',' read -r name mem; do
    mem_numeric=$(echo "$mem" | sed 's/%//')
    if (( $(echo "$mem_numeric > 90" | bc -l) )); then
      alert "High memory usage on $name: $mem"
    fi
  done
}

check_disk_space() {
  local usage
  usage=$(df -h /var/lib/docker | awk 'NR==2 {print $5}' | sed 's/%//')

  if [ "$usage" -gt 85 ]; then
    alert "Docker disk usage is at ${usage}%"
    log "Running docker system prune..."
    docker system prune -f --volumes
  fi
}

main() {
  log "Starting health check cycle"

  check_unhealthy_containers
  check_exited_containers
  check_resource_usage
  check_disk_space

  log "Health check cycle complete"
}

main "$@"
```

### Cron Job Setup

```bash
# Run every 5 minutes
*/5 * * * * /opt/scripts/docker-health-monitor.sh

# Or use systemd timer (recommended)
# /etc/systemd/system/docker-health-monitor.timer
```

## Systemd Timer (Recommended)

### Service File

```ini
# /etc/systemd/system/docker-health-monitor.service
[Unit]
Description=Docker Health Monitor
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/opt/scripts/docker-health-monitor.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

### Timer File

```ini
# /etc/systemd/system/docker-health-monitor.timer
[Unit]
Description=Run Docker Health Monitor every 5 minutes
Requires=docker-health-monitor.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min
Unit=docker-health-monitor.service

[Install]
WantedBy=timers.target
```

### Enable Timer

```bash
systemctl daemon-reload
systemctl enable docker-health-monitor.timer
systemctl start docker-health-monitor.timer
systemctl status docker-health-monitor.timer
```

## Harbor Homelab Monitoring

### Critical Services to Monitor

```yaml
# Supabase Stack (12 containers)
- supabase-db (PostgreSQL)
- supabase-auth
- supabase-rest
- supabase-realtime
- supabase-storage
- supabase-kong

# Business Critical
- vaultwarden (Password manager)
- n8n (Automation)
- portainer (Container management)

# Infrastructure
- nginx-proxy-manager
- cloudflare-tunnel
```

### Custom Health Check Script

```bash
#!/bin/bash
# /opt/scripts/check-critical-services.sh

CRITICAL_SERVICES=(
  "supabase-db"
  "vaultwarden"
  "n8n"
  "portainer"
)

for service in "${CRITICAL_SERVICES[@]}"; do
  if ! docker ps --filter "name=$service" --filter "status=running" | grep -q "$service"; then
    echo "CRITICAL: $service is not running!"
    # Send alert
    # Attempt recovery
    docker compose up -d "$service"
  fi
done
```

## Troubleshooting

### Container Constantly Unhealthy

```bash
# Check health check command
docker inspect <container> | jq '.[0].Config.Healthcheck'

# View health check logs
docker inspect <container> | jq '.[0].State.Health.Log'

# Test health check manually
docker exec <container> curl -f http://localhost:8080/health

# Adjust health check parameters
docker compose up -d --force-recreate <service>
```

### Container Keeps Restarting

```bash
# Check logs for crash reason
docker logs --tail=200 <container>

# Check exit code
docker inspect <container> | jq '.[0].State.ExitCode'

# Disable restart policy temporarily
docker update --restart=no <container>

# Debug interactively
docker run -it --rm <image> /bin/sh
```

## Integration Points

- **Netdata**: Visual monitoring dashboard
- **Cortex**: Log incidents and resolutions
- **AgentDB**: Store health check patterns
- **NocoDB**: Track maintenance events
- **Slack/Discord**: Real-time alerts

## Environment Variables

```bash
HEALTH_CHECK_INTERVAL=300  # 5 minutes
ALERT_WEBHOOK=https://hooks.slack.com/...
LOG_RETENTION_DAYS=30
RESTART_ATTEMPTS=3
```

## Usage Examples

```bash
Skill({ skill: "docker-health-monitor" })

# Request: "Monitor all containers and restart unhealthy ones"
# - Scans all containers
# - Identifies unhealthy/exited containers
# - Attempts automatic recovery
# - Sends alerts if recovery fails
# - Logs all actions

# Request: "Check Supabase stack health"
# - Verifies all 12 Supabase containers
# - Tests connectivity between services
# - Validates database connections
# - Reports status

# Request: "Alert me if any container uses >80% memory"
# - Monitors resource usage
# - Sends alert on threshold breach
# - Suggests optimization actions
```
