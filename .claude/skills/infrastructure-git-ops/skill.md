# Infrastructure GitOps Skill

**Category:** DevOps
**Dependencies:** git, GitHub CLI, Terraform (optional), Ansible (optional)
**Token Budget:** ~3000 tokens

## Purpose

Implement GitOps methodology for Harbor Homelab infrastructure management. Treat infrastructure configuration as code with version control, automated deployments, and declarative state management for Proxmox VMs, LXC containers, Docker services, and network configurations.

## When to Use

- Managing infrastructure configuration as code
- Deploying infrastructure changes via git commits
- Tracking infrastructure state in version control
- Rolling back infrastructure changes
- Syncing configuration across environments
- Auditing infrastructure modifications

## Capabilities

### Infrastructure as Code (IaC)
- Version control for infrastructure configs
- Declarative state management
- Automated drift detection
- Change history and auditing
- Rollback capabilities

### GitOps Workflow
- Git as single source of truth
- Pull-based deployment model
- Automated reconciliation
- Environment promotion (dev → staging → prod)
- Feature branching for infrastructure

### Configuration Management
- Docker Compose files versioned in git
- Proxmox VM/LXC configurations
- Network configuration (Caddy, DNS)
- Service configurations (env files)
- Secrets management (encrypted)

### Deployment Automation
- Automated deployments on git push
- Health checks after deployment
- Rollback on failure
- Deployment notifications
- Change approval workflows

## Usage Examples

### Repository Structure

```
infrastructure/
├── README.md
├── environments/
│   ├── production/
│   │   ├── docker-compose.yml
│   │   ├── .env.encrypted
│   │   └── config/
│   ├── staging/
│   │   └── ...
│   └── development/
│       └── ...
├── proxmox/
│   ├── vms/
│   │   ├── docker-vm.conf
│   │   └── monitoring-vm.conf
│   └── lxc/
│       ├── caddy.conf
│       └── portainer.conf
├── networking/
│   ├── caddy/
│   │   └── Caddyfile
│   └── dns/
│       └── cloudflare-zones.yaml
├── scripts/
│   ├── deploy.sh
│   ├── rollback.sh
│   └── health-check.sh
└── .github/
    └── workflows/
        └── deploy.yml
```

### Docker Compose GitOps

```yaml
# environments/production/docker-compose.yml
version: '3.8'

services:
  docmost:
    image: docmost/docmost:latest
    environment:
      DATABASE_URL: ${DATABASE_URL}
      APP_SECRET: ${APP_SECRET}
    volumes:
      - docmost-data:/app/data
    labels:
      - "gitops.managed=true"
      - "gitops.version=${GIT_COMMIT}"

  nocodb:
    image: nocodb/nocodb:latest
    environment:
      NC_DB: ${NC_DB}
    volumes:
      - nocodb-data:/usr/app/data

volumes:
  docmost-data:
  nocodb-data:
```

### Automated Deployment Workflow

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches:
      - main
    paths:
      - 'environments/production/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.DEPLOY_SSH_KEY }}

      - name: Deploy to Docker VM
        run: |
          ssh harbor-docker "cd /opt/infrastructure && \
            git pull origin main && \
            ./scripts/deploy.sh production"

      - name: Health Check
        run: |
          ./scripts/health-check.sh production

      - name: Notify
        if: always()
        run: |
          curl -X POST ${{ secrets.WEBHOOK_URL }} \
            -H "Content-Type: application/json" \
            -d '{"status": "${{ job.status }}", "commit": "${{ github.sha }}"}'
```

### Deployment Script

```bash
#!/bin/bash
# scripts/deploy.sh

set -euo pipefail

ENVIRONMENT="${1:-production}"
COMPOSE_FILE="environments/$ENVIRONMENT/docker-compose.yml"

echo "Deploying $ENVIRONMENT environment..."

# Load encrypted secrets
sops -d "environments/$ENVIRONMENT/.env.encrypted" > .env

# Pull latest images
docker-compose -f "$COMPOSE_FILE" pull

# Deploy with zero-downtime
docker-compose -f "$COMPOSE_FILE" up -d --remove-orphans

# Health check
sleep 10
./scripts/health-check.sh "$ENVIRONMENT"

# Cleanup old images
docker image prune -f

echo "Deployment complete!"
```

### Rollback Script

```bash
#!/bin/bash
# scripts/rollback.sh

set -euo pipefail

ENVIRONMENT="${1:-production}"
COMMIT="${2:-HEAD~1}"

echo "Rolling back $ENVIRONMENT to commit $COMMIT..."

# Checkout previous commit
git checkout "$COMMIT" -- "environments/$ENVIRONMENT/"

# Deploy previous version
./scripts/deploy.sh "$ENVIRONMENT"

# Create rollback commit
git add "environments/$ENVIRONMENT/"
git commit -m "rollback($ENVIRONMENT): revert to $COMMIT"
git push origin main

echo "Rollback complete!"
```

### Infrastructure Diff

```bash
#!/bin/bash
# Compare infrastructure state

ENVIRONMENT="${1:-production}"

echo "=== Docker Compose Diff ==="
git diff HEAD~1 "environments/$ENVIRONMENT/docker-compose.yml"

echo "=== Configuration Diff ==="
git diff HEAD~1 "environments/$ENVIRONMENT/config/"

echo "=== Currently Running ==="
ssh harbor-docker "docker-compose -f /opt/infrastructure/environments/$ENVIRONMENT/docker-compose.yml ps"
```

### Drift Detection

```bash
#!/bin/bash
# Detect configuration drift

ENVIRONMENT="${1:-production}"

# Compare git version with running version
EXPECTED=$(cat "environments/$ENVIRONMENT/docker-compose.yml" | md5sum)
ACTUAL=$(ssh harbor-docker "cat /opt/infrastructure/environments/$ENVIRONMENT/docker-compose.yml" | md5sum)

if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "⚠️  Configuration drift detected!"
  echo "Expected: $EXPECTED"
  echo "Actual: $ACTUAL"
  exit 1
else
  echo "✅ No drift detected"
fi
```

### Secrets Management with SOPS

```bash
# Encrypt secrets
sops --encrypt --age <AGE_PUBLIC_KEY> \
  environments/production/.env > environments/production/.env.encrypted

# Decrypt for deployment
sops --decrypt environments/production/.env.encrypted > .env

# Edit encrypted file
sops environments/production/.env.encrypted
```

### Proxmox VM Configuration

```bash
# proxmox/vms/docker-vm.conf
# Managed by GitOps - Do not edit manually

cores: 4
memory: 8192
scsi0: local-lvm:vm-100-disk-0,size=100G
net0: virtio,bridge=vmbr0
onboot: 1
```

```bash
# Apply VM configuration
pct set 100 --cores $(grep cores proxmox/vms/docker-vm.conf | cut -d: -f2)
pct set 100 --memory $(grep memory proxmox/vms/docker-vm.conf | cut -d: -f2)
```

## Configuration

### GitOps Principles

1. **Declarative**: Entire system state described declaratively
2. **Versioned**: All changes tracked in git history
3. **Automated**: Changes automatically applied
4. **Reconciled**: System continuously reconciles to desired state

### Environment Variables

```bash
# Infrastructure repository
export INFRA_REPO="/opt/infrastructure"

# Deployment environments
export ENVIRONMENTS="development staging production"

# Notification webhook
export DEPLOY_WEBHOOK_URL="https://hooks.slack.com/services/..."
```

### Pre-deployment Checks

```yaml
# .github/workflows/validate.yml
name: Validate Infrastructure

on:
  pull_request:
    paths:
      - 'environments/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate Docker Compose
        run: |
          for env in development staging production; do
            docker-compose -f environments/$env/docker-compose.yml config
          done

      - name: Lint Configurations
        run: |
          yamllint environments/
```

## Integration Points

- **GitHub Actions**: Automated deployments on push
- **Proxmox**: VM/LXC configuration management
- **Docker**: Service deployments
- **Caddy**: Reverse proxy configuration
- **Cloudflare**: DNS management
- **Cortex**: Log infrastructure changes
- **NocoDB**: Track deployment history

## Deployment Strategies

### Blue-Green Deployment

```bash
# Deploy to green environment
docker-compose -f docker-compose.green.yml up -d

# Health check
./scripts/health-check.sh green

# Switch traffic
docker-compose -f docker-compose.yml down
mv docker-compose.green.yml docker-compose.yml
docker-compose up -d

# Cleanup blue
docker-compose -f docker-compose.blue.yml down
```

### Canary Deployment

```bash
# Deploy 10% traffic to new version
docker-compose -f docker-compose.canary.yml up -d --scale app=1

# Monitor metrics
./scripts/monitor-canary.sh

# Promote to 100% if healthy
docker-compose up -d --scale app=10 --scale app-canary=0
```

## Error Handling

- Pre-deployment validation of all configs
- Health checks after every deployment
- Automatic rollback on failure
- Deployment locks to prevent concurrent deploys
- Notification on deployment status
- Audit log of all infrastructure changes

## Best Practices

1. **Small Changes**: Deploy small, incremental changes
2. **Test First**: Always test in staging before production
3. **Immutable**: Treat infrastructure as immutable
4. **Secrets**: Never commit unencrypted secrets
5. **Reviews**: Require PR approval for production changes
6. **Documentation**: Document all configurations
7. **Monitoring**: Monitor deployments actively
8. **Rollback Plan**: Always have rollback procedure ready

## Scripts Location

- **Deploy**: `infrastructure-ops/scripts/gitops-deploy.sh`
- **Rollback**: `infrastructure-ops/scripts/gitops-rollback.sh`
- **Drift Check**: `infrastructure-ops/scripts/drift-check.sh`
- **Health Check**: `infrastructure-ops/scripts/health-check.sh`

## Related Skills

- `docker-deploy` - Docker deployment workflows
- `github-workflow-automation` - Git automation
- `infrastructure-health` - Health monitoring

## References

- [GitOps Principles](https://www.gitops.tech/)
- [Terraform GitOps](https://www.terraform.io/docs/cloud/guides/recommended-practices/part1.html)
- [Docker Compose](https://docs.docker.com/compose/)
- [SOPS](https://github.com/mozilla/sops)
