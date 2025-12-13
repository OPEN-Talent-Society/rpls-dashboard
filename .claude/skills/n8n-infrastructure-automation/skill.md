---
name: n8n-infrastructure-automation
description: Use N8N for infrastructure automation tasks including monitoring, deployment, and orchestration
---

# N8N Infrastructure Automation Skill

This skill enables N8N-based infrastructure automation including monitoring, deployment pipelines, backup coordination, and event-driven automation.

## When to Use This Skill

Use this skill when you need to:
- Automate infrastructure monitoring and alerting
- Coordinate backup operations across systems
- Create deployment pipelines
- Implement event-driven automation
- Orchestrate multi-system workflows
- Automate routine maintenance tasks
- Integrate infrastructure services

## Automation Capabilities

### Monitoring & Alerting
- Aggregate metrics from Netdata
- Process alerts from Uptime Kuma
- Monitor service health across infrastructure
- Send notifications (Slack, email, webhooks)
- Create custom monitoring dashboards

### Backup Coordination
- Orchestrate backup schedules
- Verify backup completion
- Rotate old backups
- Send backup status reports
- Trigger off-site backup sync

### Deployment Automation
- GitHub webhook receivers
- Automated deployment pipelines
- Container orchestration
- Configuration management
- Service restarts and updates

### Security Automation
- Certificate expiry monitoring
- Security event aggregation
- Automated security scans
- Access log analysis
- Incident response workflows

## Integration Workflows

### Uptime Kuma → N8N
- Receive downtime alerts
- Escalate critical issues
- Auto-remediation workflows
- Status page updates

### Netdata → N8N
- Metrics threshold alerts
- Performance anomaly detection
- Resource usage tracking
- Capacity planning triggers

### GitHub → N8N
- Push event triggers
- PR merge automation
- Release deployment
- Issue tracking integration

### Docker → N8N
- Container lifecycle events
- Image update notifications
- Health check failures
- Resource limit alerts

### Vaultwarden → N8N
- Secret rotation schedules
- Access audit logging
- Backup verification
- Emergency access workflows

## Available Workflow Templates

Located in: `infrastructure-ops/n8n-workflows/`

1. **infrastructure-monitoring.json**
   - Service health checks
   - Metric aggregation
   - Alert routing
   - Dashboard updates

2. **backup-coordinator.json**
   - Schedule coordination
   - Backup verification
   - Rotation management
   - Status reporting

3. **certificate-renewal.json**
   - Expiry monitoring
   - Auto-renewal triggers
   - Validation checks
   - Deployment automation

4. **security-alerting.json**
   - Event aggregation
   - Threat detection
   - Incident response
   - Audit logging

5. **service-health-check.json**
   - Periodic health checks
   - Service discovery
   - Dependency validation
   - Uptime tracking

## Webhook Endpoints

Common webhook patterns:
- `/webhook/uptime-alert` - Uptime Kuma alerts
- `/webhook/github-push` - GitHub events
- `/webhook/backup-complete` - Backup notifications
- `/webhook/security-event` - Security alerts
- `/webhook/health-check` - Health status updates

## Usage Examples

- "Create N8N workflow for Uptime Kuma integration"
- "Set up automated backup coordination"
- "Deploy infrastructure monitoring workflow"
- "Create GitHub webhook for auto-deployment"
- "Set up certificate expiry alerts"

## Best Practices

- Use webhook authentication
- Implement error handling and retries
- Log all automation actions
- Version control workflows
- Test before production deployment
- Monitor workflow execution
- Set up failure notifications
