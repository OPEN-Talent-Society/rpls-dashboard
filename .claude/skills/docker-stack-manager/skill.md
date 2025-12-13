# Docker Stack Manager Skill

Manage Docker Compose stacks with advanced deployment, update, and rollback capabilities tailored for the Harbor Homelab.

## Environment

**Docker VM**: 192.168.50.149 (Tailscale: 100.103.83.62)
- 33 containers across multiple stacks
- Supabase (12 containers), LibreChat, Linkwarden, Postiz
- Standalone: Portainer, N8N, Vaultwarden, etc.

## Core Capabilities

### 1. Stack Deployment

Deploy Docker Compose stacks with validation and health checks:

```bash
# Navigate to stack directory
cd /path/to/stack

# Validate compose file
docker compose config --quiet

# Deploy with health monitoring
docker compose up -d --wait --wait-timeout 300

# Verify all containers are healthy
docker compose ps --format json | jq -r '.[] | select(.Health != "healthy") | .Name'
```

### 2. Stack Updates

Update stacks with automatic rollback on failure:

```bash
# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d --force-recreate --remove-orphans

# Wait for health checks
docker compose ps --format json | jq -r '.[] | select(.Health != "healthy")'
```

### 3. Stack Rollback

Rollback to previous version:

```bash
# Stop current stack
docker compose down

# Restore from backup
docker compose -f docker-compose.backup.yml up -d

# Verify health
docker compose ps
```

### 4. Stack Health Monitoring

Monitor stack health and auto-restart unhealthy containers:

```bash
# Check all container health
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"

# Restart unhealthy containers
docker compose ps --filter health=unhealthy -q | xargs -r docker restart

# View logs for failing containers
docker compose logs --tail=100 --follow
```

## Best Practices (2025)

### Health Checks in Compose Files

```yaml
services:
  api:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
      start_interval: 5s
    deploy:
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
```

### Resource Limits

```yaml
services:
  database:
    image: postgres:16
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 4G
        reservations:
          cpus: '1.0'
          memory: 2G
```

### Network Isolation

```yaml
networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
```

## Stack Management Workflows

### Pre-Deployment Checklist

1. Validate compose file: `docker compose config`
2. Check available resources: `docker stats --no-stream`
3. Backup current state: `docker compose config > docker-compose.backup.yml`
4. Pull images: `docker compose pull`
5. Create snapshots of volumes if critical

### Deployment Workflow

1. Deploy stack: `docker compose up -d --wait`
2. Monitor logs: `docker compose logs -f`
3. Verify health: `docker compose ps`
4. Run smoke tests
5. Document deployment in Cortex

### Rollback Workflow

1. Stop current stack: `docker compose down`
2. Restore backup: `mv docker-compose.backup.yml docker-compose.yml`
3. Redeploy: `docker compose up -d`
4. Verify rollback: `docker compose ps`
5. Document incident

## Harbor Homelab Stacks

### Supabase Stack (12 containers)

```bash
# Location: /opt/supabase
cd /opt/supabase

# Deploy
docker compose -f docker-compose.yml up -d --wait

# Check health
docker compose ps | grep -i health

# Backup database
docker compose exec postgres pg_dump -U postgres > backup.sql
```

### LibreChat Stack

```bash
# Deploy with environment validation
docker compose config | grep -i api_key
docker compose up -d --wait --wait-timeout 180
```

### Standalone Services

```bash
# Update Portainer
docker compose pull portainer
docker compose up -d portainer --force-recreate

# Update N8N with zero downtime
docker compose up -d --no-deps --force-recreate n8n
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs <service> --tail=100

# Inspect container
docker compose ps <service> --format json | jq

# Check resource constraints
docker stats <container> --no-stream
```

### Network Issues

```bash
# List networks
docker network ls

# Inspect network
docker network inspect <network_name>

# Recreate network
docker compose down
docker network prune -f
docker compose up -d
```

### Volume Issues

```bash
# List volumes
docker volume ls

# Inspect volume
docker volume inspect <volume_name>

# Backup volume
docker run --rm -v <volume>:/data -v $(pwd):/backup alpine tar czf /backup/volume.tar.gz /data
```

## Integration Points

- **Memory System**: Store deployment patterns in AgentDB
- **Cortex**: Document deployments and incidents
- **NocoDB**: Track deployment tasks
- **Hooks**: Pre/post deployment validation

## Environment Variables

Store in `/Users/adamkovacs/Documents/codebuild/.env`:

```bash
DOCKER_HOST=ssh://user@192.168.50.149
DOCKER_STACK_DIR=/opt/stacks
BACKUP_DIR=/opt/backups
```

## Usage Examples

### Deploy New Stack

```bash
# Use the skill
Skill({ skill: "docker-stack-manager" })

# Request: "Deploy the new monitoring stack to Harbor"
# - Validates compose file
# - Checks resources
# - Creates backup
# - Deploys with health monitoring
# - Documents in Cortex
```

### Update Existing Stack

```bash
# Request: "Update Supabase stack to latest version"
# - Backs up current config
# - Pulls new images
# - Recreates containers
# - Waits for health checks
# - Rolls back on failure
```

### Emergency Rollback

```bash
# Request: "Rollback LibreChat stack immediately"
# - Stops current version
# - Restores previous config
# - Redeploys
# - Verifies health
# - Alerts on completion
```
