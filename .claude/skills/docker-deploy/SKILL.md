---
name: docker-deploy
description: Standardized Docker deployment workflow for infrastructure services including health checks, rollbacks, and validation
triggers:
  - docker deploy
  - deploy service
  - docker update
  - rolling update
  - deployment rollback
  - docker restart
  - service deployment
---

# Docker Deploy Skill

This skill provides a standardized, repeatable deployment process for Docker-based infrastructure services with built-in health checks, rollback capabilities, and deployment validation.

## When to Use This Skill

Use this skill when you need to:
- Deploy new services or updates to existing services
- Perform rolling updates with minimal downtime
- Validate deployments before and after
- Rollback failed deployments quickly
- Standardize deployment procedures across services

## Supported Services

This skill is designed for the current infrastructure stack:
- Docmost (`/srv/docmost`)
- NocoDB (`/srv/nocodb`)
- n8n (`/srv/n8n`)
- Dashboard (`/srv/dash`)
- Monitoring services (`/srv/monitoring`)
- Reverse proxy (`/srv/proxy`)

## Deployment Workflow

1. **Pre-deployment checks**
2. **Backup current state**
3. **Pull updated images**
4. **Deploy with health validation**
5. **Post-deployment verification**
6. **Generate deployment report**

## Available Scripts

- `scripts/pre-deploy.sh` - Pre-deployment validation and backup
- `scripts/deploy.sh` - Main deployment orchestration
- `scripts/health-check.sh` - Service health validation
- `scripts/rollback.sh` - Emergency rollback procedure
- `scripts/post-deploy.sh` - Post-deployment verification

## Templates

- `templates/deployment-report.md` - Standardized deployment documentation
- `templates/rollback-plan.md` - Rollback procedure template
- `templates/health-status.md` - Health check report format

## Usage Examples

- "Deploy Docmost update with full validation"
- "Perform rolling update for NocoDB"
- "Deploy new monitoring service configuration"
- "Rollback failed n8n deployment"

## Safety Features

- Automatic backups before deployment
- Health check validation at each step
- Automatic rollback on failure
- Service dependency validation
- Configuration change tracking