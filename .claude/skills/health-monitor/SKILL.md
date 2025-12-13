---
name: health-monitor
description: Comprehensive multi-service health monitoring including uptime checks, performance metrics, and automated alerting for the entire infrastructure stack
triggers:
  - run health check
  - monitor infrastructure
  - check service health
  - performance metrics
  - uptime monitoring
  - health status report
  - infrastructure monitoring
---

# Health Monitor Skill

This skill provides comprehensive health monitoring across all infrastructure services, including uptime checking, performance metrics collection, automated alerting, and detailed health status reporting.

## When to Use This Skill

Use this skill when you need to:
- Monitor health across all services simultaneously
- Generate comprehensive health status reports
- Identify performance bottlenecks or issues
- Validate system after changes or deployments
- Monitor service dependencies and interactions
- Create automated health monitoring workflows

## Monitored Services

This skill monitors the complete infrastructure stack:
- **Core Services**: Docmost, NocoDB, n8n, Dashboard
- **Infrastructure**: Caddy Proxy, Docker containers
- **Monitoring**: Uptime Kuma, Dozzle, Netdata
- **External Dependencies**: DNS, SSL certificates, network connectivity

## Monitoring Capabilities

### Health Checks
- Service endpoint availability (HTTP/HTTPS)
- Container health and status
- Database connectivity and performance
- SSL certificate validity
- DNS resolution
- Network connectivity and latency

### Performance Metrics
- Response times and latency
- Resource utilization (CPU, memory, disk)
- Database query performance
- Network I/O and throughput
- Container restart counts

### Automated Alerting
- Service downtime detection
- Performance threshold breaches
- SSL expiration warnings
- Resource capacity alerts
- Dependency failure notifications

## Available Scripts

- `scripts/full-health-check.sh` - Comprehensive health monitoring across all services
- `scripts/quick-status.sh` - Fast status overview of critical services
- `scripts/performance-check.sh` - Detailed performance metrics collection
- `scripts/ssl-check.sh` - SSL certificate validation and monitoring
- `scripts/dependency-check.sh` - Service dependency validation

## Templates

- `templates/health-dashboard.md` - Executive health status dashboard
- `templates/incident-report.md` - Incident documentation template
- `templates/performance-report.md` - Performance analysis report
- `templates/ssl-status.md` - SSL certificate status report

## Usage Examples

- "Run comprehensive health check across all services"
- "Generate daily health status report"
- "Check SSL certificate expiration status"
- "Monitor performance after deployment"
- "Investigate service dependency issues"

## Alert Thresholds

Default monitoring thresholds (configurable):
- **Response Time**: >5 seconds warning, >10 seconds critical
- **CPU Usage**: >80% warning, >95% critical
- **Memory Usage**: >85% warning, >95% critical
- **Disk Usage**: >80% warning, >90% critical
- **SSL Expiry**: <30 days warning, <7 days critical

## Integration Points

- **Uptime Kuma**: Leverages existing monitoring setup
- **Dashboard API**: Consumes status data for visualization
- **n8n Workflows**: Triggers automated alerting workflows
- **Cloudflare Access**: Validates protected endpoint access