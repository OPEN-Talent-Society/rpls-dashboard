---
name: n8n-integration-builder
description: Build N8N workflows for common infrastructure tasks and service integrations
---

# N8N Integration Builder Skill

This skill provides templates, patterns, and guidance for building N8N workflows that integrate infrastructure services and automate common tasks.

## When to Use This Skill

Use this skill when you need to:
- Create new N8N workflow integrations
- Connect multiple infrastructure services
- Build event-driven automation
- Implement monitoring and alerting workflows
- Create deployment pipelines
- Automate routine maintenance tasks

## Common Integration Patterns

### 1. Monitoring & Alerting
**Pattern**: Service → N8N → Notification
- Uptime Kuma downtime → N8N → Slack/Email
- Netdata threshold → N8N → PagerDuty
- Log pattern → N8N → Security team

### 2. Backup & Recovery
**Pattern**: Schedule → N8N → Multiple Services
- Cron trigger → Backup services → Verify → Notify
- Failure detection → Alert → Auto-retry
- Success → Update tracking → Report

### 3. Deployment Pipeline
**Pattern**: Git Event → N8N → Deploy
- GitHub push → N8N → Build → Test → Deploy
- PR merge → Deploy staging → Run tests
- Release tag → Deploy production → Notify

### 4. Security Automation
**Pattern**: Event → N8N → Action
- Failed login → N8N → Block IP
- Certificate expiring → N8N → Renew → Deploy
- Vulnerability scan → N8N → Create tickets

### 5. Service Orchestration
**Pattern**: Multi-step coordination
- Service A ready → Trigger Service B
- All services healthy → Update status page
- Dependency check → Start dependent services

## Workflow Templates

### Infrastructure Monitoring
```json
{
  "name": "Infrastructure Health Monitor",
  "nodes": [
    {
      "type": "Schedule Trigger",
      "interval": "*/5 * * * *"
    },
    {
      "type": "HTTP Request",
      "url": "http://netdata.harbor.fyi/api/v1/alarms"
    },
    {
      "type": "Filter",
      "conditions": "status == CRITICAL"
    },
    {
      "type": "Slack",
      "message": "Alert: {{alarm.name}}"
    }
  ]
}
```

### Backup Coordinator
```json
{
  "name": "Daily Backup Coordination",
  "nodes": [
    {
      "type": "Cron",
      "schedule": "0 2 * * *"
    },
    {
      "type": "Execute Command",
      "services": ["docmost", "nocodb", "vaultwarden"]
    },
    {
      "type": "Wait",
      "timeout": 3600
    },
    {
      "type": "Verify Backups"
    },
    {
      "type": "Email Report"
    }
  ]
}
```

### GitHub Deployment
```json
{
  "name": "Auto Deploy on Push",
  "nodes": [
    {
      "type": "Webhook",
      "path": "/webhook/github-push"
    },
    {
      "type": "Filter",
      "branch": "main"
    },
    {
      "type": "SSH",
      "command": "cd /srv/app && git pull && docker-compose up -d"
    },
    {
      "type": "Health Check"
    },
    {
      "type": "Slack Notification"
    }
  ]
}
```

## Service Integration Guides

### Uptime Kuma Integration
**Setup**:
1. Create webhook in N8N: `/webhook/uptime-alert`
2. Configure Uptime Kuma notification
3. Add authentication token
4. Test webhook delivery

**Data Structure**:
```json
{
  "monitor": "Service Name",
  "status": "down",
  "timestamp": "2025-12-06T10:00:00Z",
  "message": "HTTP 500 error"
}
```

### Netdata Integration
**Setup**:
1. Enable Netdata API
2. Create N8N HTTP Request node
3. Parse metrics JSON
4. Set up threshold conditions

**Metrics to Monitor**:
- CPU usage over 80%
- Memory usage over 90%
- Disk space below 10%
- Network errors increasing

### GitHub Integration
**Setup**:
1. Create GitHub webhook in repo settings
2. Point to N8N webhook URL
3. Add webhook secret
4. Select events (push, PR, release)

**Event Types**:
- `push` - Code pushed to repository
- `pull_request` - PR opened/merged
- `release` - New release published
- `issues` - Issue created/updated

### Docker Integration
**Setup**:
1. Install Docker events webhook plugin
2. Configure event filters
3. Point to N8N webhook
4. Parse event data

**Events**:
- Container start/stop
- Image pull/push
- Health check failures
- Resource limit alerts

### Vaultwarden Integration
**Setup**:
1. Use Vaultwarden API
2. Authenticate with API key
3. Create secret rotation workflow
4. Set up backup verification

**Operations**:
- List all secrets
- Rotate specific secret
- Backup vault
- Audit access logs

## Workflow Building Best Practices

### Error Handling
- Add try/catch nodes
- Implement retry logic
- Set timeout limits
- Log all errors
- Send failure notifications

### Testing
- Use test data
- Enable debug mode
- Validate each node
- Test error paths
- Check webhook signatures

### Performance
- Limit concurrent executions
- Use batching for bulk operations
- Implement rate limiting
- Cache repeated requests
- Optimize data transformations

### Security
- Use environment variables for secrets
- Validate webhook signatures
- Implement authentication
- Log security events
- Rotate credentials regularly

## Common Node Types

### Triggers
- **Webhook**: HTTP endpoint for external events
- **Cron**: Scheduled execution
- **Polling**: Regular service checks
- **Email**: Incoming email triggers
- **File Watch**: File system events

### Actions
- **HTTP Request**: API calls
- **Execute Command**: SSH/shell commands
- **Database**: SQL operations
- **Email**: Send notifications
- **Slack/Discord**: Team notifications

### Logic
- **Filter**: Conditional routing
- **Set**: Data transformation
- **Function**: Custom JavaScript
- **Switch**: Multi-path routing
- **Merge**: Combine data streams

## Usage Examples

- "Create N8N workflow for Uptime Kuma alerts"
- "Build backup coordination workflow"
- "Set up GitHub deployment pipeline"
- "Create infrastructure monitoring dashboard"
- "Automate certificate renewal workflow"

## Testing Workflows

### Test Checklist
- [ ] All nodes configured correctly
- [ ] Credentials working
- [ ] Error handling in place
- [ ] Webhook authentication tested
- [ ] Success path validated
- [ ] Failure path validated
- [ ] Notifications working
- [ ] Logging enabled

### Test Commands
```bash
# Test webhook
curl -X POST https://n8n.harbor.fyi/webhook/test \
  -H "Content-Type: application/json" \
  -d '{"test": "data"}'

# Trigger workflow manually
# Use N8N UI: Execute Node

# Check workflow logs
# Use N8N UI: Executions tab
```

## Troubleshooting

### Common Issues
- **Webhook not receiving**: Check URL, authentication
- **Node timeout**: Increase timeout, optimize query
- **Data not passing**: Check node connections
- **Authentication failing**: Verify credentials
- **Rate limit hit**: Implement backoff, reduce frequency

### Debug Tools
- N8N execution logs
- Node debug output
- Webhook payload inspector
- API response viewer
- Error stack traces
