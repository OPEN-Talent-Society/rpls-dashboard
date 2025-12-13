---
name: n8n-workflow-manager
description: N8N workflow backup, deployment, version control, and lifecycle management
triggers:
  - manage n8n workflows
  - backup workflows
  - deploy n8n workflow
  - n8n automation
  - workflow version control
  - test n8n workflow
  - export workflows
---

# N8N Workflow Manager Skill

This skill provides comprehensive workflow lifecycle management for N8N automation platform including backup, version control, deployment, and testing.

## When to Use This Skill

Use this skill when you need to:
- Backup N8N workflows to version control
- Deploy workflows from git to N8N instance
- Export workflows for migration or backup
- Import workflows from templates or backups
- Track workflow changes over time
- Test workflow execution
- Restore workflows after failures

## N8N Instance Details

- **URL**: https://n8n.harbor.fyi (internal: http://192.168.50.149:5678)
- **Location**: Proxmox VM at 192.168.50.149
- **Port**: 5678 (currently exposed - SECURITY ISSUE)
- **Purpose**: Infrastructure automation and workflow orchestration

## Workflow Operations

### Backup Operations
- Export all workflows to JSON
- Commit workflows to git with versioning
- Create incremental backups
- Full database backup of N8N data

### Deployment Operations
- Deploy workflows from git repository
- Import workflow templates
- Activate/deactivate workflows
- Update workflow configurations

### Testing Operations
- Test workflow execution
- Validate webhook endpoints
- Check workflow triggers
- Verify integrations

## Available Scripts

Located in: `infrastructure-ops/scripts/n8n/`

- `n8n-workflow-backup.sh` - Backup all workflows to git
- `n8n-workflow-deploy.sh` - Deploy workflows from git
- `n8n-workflow-export.sh` - Export individual workflow
- `n8n-workflow-import.sh` - Import workflow from JSON
- `n8n-workflow-list.sh` - List all workflows
- `n8n-workflow-test.sh` - Test workflow execution
- `n8n-workflow-activate.sh` - Activate/deactivate workflows

## Workflow Templates

Located in: `infrastructure-ops/n8n-workflows/`

- `infrastructure-monitoring.json` - Infrastructure monitoring and alerting
- `backup-coordinator.json` - Backup orchestration
- `certificate-renewal.json` - SSL certificate monitoring
- `security-alerting.json` - Security event aggregation
- `service-health-check.json` - Service health monitoring

## Integration Points

- **Uptime Kuma**: Webhook receivers for downtime alerts
- **Netdata**: Metrics-based automation triggers
- **GitHub**: Repository event webhooks
- **Docker**: Container lifecycle events
- **Vaultwarden**: Secret rotation automation
- **Cloudflare**: DNS and SSL management

## Commands

- `/n8n-workflows` - List all N8N workflows
- `/n8n-backup` - Backup workflows to git
- `/n8n-deploy` - Deploy workflow from template
- `/n8n-test` - Test workflow execution

## Usage Examples

- "Backup all N8N workflows to git"
- "Deploy infrastructure monitoring workflow"
- "Test the backup coordinator workflow"
- "Export security alerting workflow"
- "List all active N8N workflows"

## Safety Features

- Automatic backup before deployment
- Workflow validation before import
- Rollback capability for failed deployments
- Dry-run mode for testing
- Workflow versioning in git
