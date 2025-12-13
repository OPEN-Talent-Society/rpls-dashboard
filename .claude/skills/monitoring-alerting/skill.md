---
triggers:
  - configure alerts
  - setup monitoring alerts
  - alert routing
  - escalation policy
  - notification channels
  - alert fatigue
  - monitoring orchestration
---

# Monitoring Alerting Skill

Unified alerting orchestration across Uptime Kuma, Netdata, and custom monitoring systems.

## Mission

Coordinate alerts from multiple monitoring systems, manage notification channels, implement escalation policies, and prevent alert fatigue.

## Capabilities

1. **Alert Aggregation**
   - Collect alerts from Uptime Kuma, Netdata, custom checks
   - Deduplicate alerts from multiple sources
   - Correlate related alerts
   - Priority-based routing

2. **Notification Management**
   - Email (Brevo), Slack, Discord, PagerDuty
   - On-call rotation scheduling
   - Quiet hours and maintenance windows
   - Notification grouping and batching

3. **Escalation Policies**
   - Tier-based escalation
   - Auto-escalation on timeout
   - Escalation chains
   - Override mechanisms

4. **Alert Intelligence**
   - Alert deduplication
   - Anomaly detection
   - Pattern recognition
   - Root cause analysis hints

## Usage

### Configure Alert Routing

```bash
Skill({ skill: "monitoring-alerting" })

# In skill context:
"Configure alert routing: CRITICAL -> PagerDuty, WARNING -> Slack, INFO -> Email digest"
```

### Set Up Escalation

```bash
Skill({ skill: "monitoring-alerting" })

# In skill context:
"Create escalation policy: L1 team -> 15 min -> L2 team -> 30 min -> Manager"
```

### Analyze Alert Patterns

```bash
Skill({ skill: "monitoring-alerting" })

# In skill context:
"Analyze last 7 days of alerts and identify patterns causing alert fatigue"
```

## Configuration

**Alert Sources:**

1. **Uptime Kuma**: Service availability alerts
2. **Netdata**: System performance alerts
3. **Docker**: Container health alerts
4. **Custom**: Application-specific alerts

**Notification Channels:**

1. **Email (Brevo)**:
   - Critical alerts: Immediate
   - Warning alerts: 15-minute batch
   - Info alerts: Daily digest

2. **Slack (#infrastructure-alerts)**:
   - All CRITICAL alerts
   - WARNING during business hours
   - Summary threads

3. **PagerDuty** (optional):
   - CRITICAL alerts only
   - 24/7 on-call rotation
   - Escalation after 5 minutes

**Alert Severity Levels:**

- **CRITICAL**: Service down, data loss risk, security breach
- **WARNING**: High resource usage, degraded performance
- **INFO**: Routine events, successful deploys, backups

## Implementation

When this skill is invoked:

1. **Configure alert router** to receive from all sources
2. **Set up notification channels** with credentials
3. **Define routing rules** based on severity and source
4. **Implement escalation policies** with timeouts
5. **Configure quiet hours** and maintenance windows
6. **Test alert flow** end-to-end

## Scripts

- `setup-alerting.sh` - Configure alert router and channels
- `route-alert.sh` - Process and route individual alert
- `test-alerts.sh` - Send test alerts to all channels
- `escalate-alert.sh` - Trigger escalation for unacknowledged alert
- `alert-stats.sh` - Generate alert statistics and patterns
- `maintenance-mode.sh` - Enable/disable maintenance window

## Alert Routing Rules

```yaml
rules:
  # Critical service down
  - match:
      severity: CRITICAL
      source: uptime-kuma
    route:
      - channel: pagerduty
        priority: high
      - channel: slack
        priority: high
      - channel: email
        priority: high

  # Performance degradation
  - match:
      severity: WARNING
      source: netdata
      metric: cpu|memory|disk
    route:
      - channel: slack
        conditions:
          time: business_hours
      - channel: email
        batch_window: 15m

  # Info/routine events
  - match:
      severity: INFO
    route:
      - channel: email
        batch_window: 24h
        template: daily_digest
```

## Escalation Policy

```yaml
policies:
  production_services:
    stages:
      - name: L1 Team
        targets:
          - slack: "#infrastructure-alerts"
          - email: "l1-oncall@aienablement.academy"
        timeout: 15m

      - name: L2 Team
        targets:
          - pagerduty: "l2-oncall"
          - email: "l2-oncall@aienablement.academy"
        timeout: 30m

      - name: Management
        targets:
          - email: "ops-manager@aienablement.academy"
          - sms: "+1-xxx-xxx-xxxx"
        timeout: 60m

  non_production:
    stages:
      - name: Team Slack
        targets:
          - slack: "#dev-alerts"
        timeout: 60m
```

## Alert Templates

**Email Template (Critical):**
```
Subject: [CRITICAL] {service_name} is DOWN

Alert: {alert_name}
Severity: {severity}
Service: {service_name}
Started: {start_time}
Duration: {duration}

Description:
{description}

Troubleshooting:
- Check logs: https://logs.aienablement.academy/?container={container}
- View metrics: https://monitor.aienablement.academy/#{service}
- Service status: https://uptime.aienablement.academy

Actions:
- Acknowledge: {ack_url}
- Escalate: {escalate_url}
- Snooze: {snooze_url}
```

**Slack Template:**
```
:rotating_light: *CRITICAL ALERT*

*Service*: {service_name}
*Status*: DOWN
*Duration*: {duration}
*Impact*: {estimated_impact}

<{logs_url}|View Logs> | <{metrics_url}|View Metrics> | <{status_url}|Status Page>

_Escalating to {next_team} in {timeout}_
```

## Alert Deduplication

**Dedup Logic:**

1. **Fingerprint**: `{source}:{service}:{metric}:{severity}`
2. **Window**: 5 minutes
3. **Action**: Merge alerts with same fingerprint
4. **Notification**: Send once, update with count

**Example:**
```
Input:
  - uptime-kuma: cortex DOWN (00:01)
  - uptime-kuma: cortex DOWN (00:02)
  - uptime-kuma: cortex DOWN (00:03)

Output:
  - uptime-kuma: cortex DOWN (3 occurrences in 5 minutes)
```

## Quiet Hours

**Configuration:**
```yaml
quiet_hours:
  # Suppress non-critical alerts during off-hours
  - name: Nights
    schedule: "0-7 * * *"  # Midnight to 7am
    suppress: [WARNING, INFO]
    allow: [CRITICAL]

  - name: Weekends
    schedule: "* * * * 0,6"  # Saturday, Sunday
    suppress: [WARNING, INFO]
    allow: [CRITICAL]

  # Batch alerts during quiet hours
  batching:
    enabled: true
    window: 12h
    send_at: "08:00"
```

## Maintenance Windows

**Scheduled Maintenance:**
```bash
# Start maintenance window
bash scripts/maintenance-mode.sh start "Database upgrade" "2h"

# Suppresses alerts for specified services
# Adds banner to status page
# Sends notification to team

# End maintenance window
bash scripts/maintenance-mode.sh end
```

## Integration

**Works with:**
- `uptime-kuma-manager` - Service uptime alerts
- `netdata-monitoring` - Performance alerts
- `dozzle-log-manager` - Log-based alerts
- `health-monitor` - Health check alerts

**Triggers:**
- Alert received: Route and notify
- Alert acknowledged: Stop escalation
- Alert resolved: Send resolution notification
- Pattern detected: Trigger root cause analysis

## Best Practices

1. **Alert Tuning**: Review and adjust thresholds monthly
2. **On-call Rotation**: 7-day rotations with handoff checklist
3. **Runbooks**: Link alerts to troubleshooting guides
4. **Post-mortems**: Document and learn from incidents
5. **Alert Budget**: Target < 5 alerts per day per team

## Alert Metrics

**Track these KPIs:**

- **Alert Volume**: Total alerts per day/week
- **Alert Response Time**: Time to acknowledge
- **Resolution Time**: Time to resolve
- **False Positive Rate**: Alerts that weren't real issues
- **Escalation Rate**: % of alerts that escalated
- **On-call Load**: Alerts per on-call shift

## Troubleshooting

**Too many alerts:**
- Increase alert thresholds
- Implement alert grouping
- Add quiet hours for non-critical
- Review and remove noisy alerts

**Missing alerts:**
- Check notification channel configs
- Verify alert routing rules
- Test alert pipeline end-to-end
- Review alert source configurations

**Delayed alerts:**
- Check alert processing queue
- Verify network connectivity
- Review notification channel rate limits
- Check system resource usage

**Alert fatigue:**
- Implement alert deduplication
- Use escalation policies
- Batch low-priority alerts
- Regular alert tuning sessions

## Advanced Features

**Auto-remediation:**
```yaml
auto_remediation:
  - match:
      alert: container_down
    actions:
      - restart_container
      - wait: 30s
      - check_health
      - notify_if_failed

  - match:
      alert: disk_full
    actions:
      - clean_logs
      - clean_temp_files
      - notify_if_not_resolved
```

**Alert Correlation:**
```yaml
correlation:
  - name: Cascading Failure
    trigger:
      - database_down
      - api_down
      - frontend_down
    within: 5m
    action: create_incident
    title: "Cascading Failure Detected"
```

## API Reference

```bash
# Send custom alert
curl -X POST http://localhost:9090/api/v1/alerts \
  -H "Content-Type: application/json" \
  -d '{
    "severity": "WARNING",
    "service": "custom-app",
    "message": "Custom alert message",
    "source": "custom-script"
  }'

# Acknowledge alert
curl -X POST http://localhost:9090/api/v1/alerts/{id}/ack

# Escalate alert
curl -X POST http://localhost:9090/api/v1/alerts/{id}/escalate

# Get alert stats
curl http://localhost:9090/api/v1/stats
```

## Related

- Skill: `uptime-kuma-manager` - Service monitoring
- Skill: `netdata-monitoring` - System metrics
- Skill: `dozzle-log-manager` - Log aggregation
- Skill: `brevo-email` - Email notifications
- Command: `/uptime-status` - Quick status check
- Script: `infrastructure-ops/scripts/monitoring/alert-test.sh`

---

**Last Updated:** 2025-12-06
**Category:** Infrastructure, Monitoring, Alerting
**Priority:** Critical
