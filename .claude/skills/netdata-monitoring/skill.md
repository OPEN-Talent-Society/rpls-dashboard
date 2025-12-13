# Netdata Monitoring Skill

Real-time system metrics collection, visualization, and alerting using Netdata.

## Mission

Deploy and manage Netdata agents across all infrastructure for comprehensive system monitoring, performance tracking, and proactive alerting.

## Capabilities

1. **System Metrics**
   - CPU, memory, disk, network utilization
   - Process monitoring and resource tracking
   - Container metrics (Docker, LXC)
   - Service health monitoring

2. **Performance Tracking**
   - Per-second granularity metrics
   - Historical data retention
   - Anomaly detection
   - Baseline comparisons

3. **Alerting**
   - Threshold-based alerts
   - Anomaly-based alerts
   - Custom alert rules
   - Multi-channel notifications

4. **Visualization**
   - Real-time dashboards
   - Custom metric charts
   - Infrastructure topology
   - Trend analysis

## Usage

### Install Netdata on All Hosts

```bash
Skill({ skill: "netdata-monitoring" })

# In skill context:
"Install Netdata on all infrastructure hosts with centralized streaming"
```

### Configure Custom Alerts

```bash
Skill({ skill: "netdata-monitoring" })

# In skill context:
"Configure alerts for high CPU (>80%), low disk space (<10%), and high memory (>90%)"
```

### View System Metrics

```bash
Skill({ skill: "netdata-monitoring" })

# In skill context:
"Show current CPU and memory usage across all hosts"
```

## Configuration

**Netdata Details:**
- Dashboard: `https://monitor.aienablement.academy`
- Agent Port: 19999
- Streaming Port: 19998
- Config: `/etc/netdata/netdata.conf`

**Deployment Targets:**

1. **Proxmox Hosts** (3):
   - proxmox-01.internal
   - proxmox-02.internal
   - proxmox-03.internal

2. **Docker Host**:
   - docker-vm.internal

3. **TrueNAS**:
   - nas.harbor.fyi

4. **Parent/Cloud**:
   - monitor.aienablement.academy (centralized)

**Metrics to Monitor:**

- **System**: CPU, RAM, disk I/O, network traffic
- **Containers**: Docker container stats, resource limits
- **Services**: Web servers, databases, application processes
- **Storage**: Disk usage, IOPS, ZFS metrics (TrueNAS)
- **Network**: Bandwidth, connections, errors

## Implementation

When this skill is invoked:

1. **Install Netdata** on all target hosts
2. **Configure streaming** to central parent node
3. **Set up alerts** for critical thresholds
4. **Configure retention** based on storage capacity
5. **Enable plugins** for Docker, ZFS, etc.
6. **Test alerts** to verify notification delivery

## Scripts

- `install-netdata.sh` - Install Netdata on target host
- `configure-streaming.sh` - Set up parent-child streaming
- `setup-alerts.sh` - Configure alert rules
- `health-check.sh` - Verify Netdata is running on all hosts
- `export-metrics.sh` - Export metrics for analysis
- `backup-config.sh` - Backup Netdata configurations

## Alert Rules

**Critical Alerts (immediate notification):**
- CPU usage > 95% for 5 minutes
- Memory usage > 95%
- Disk space < 5%
- System load > CPU cores × 2
- Service/container down

**Warning Alerts (batched notification):**
- CPU usage > 80% for 10 minutes
- Memory usage > 85%
- Disk space < 10%
- High network errors (>1%)
- Elevated response times

**Info Alerts (daily digest):**
- Disk space trends
- Memory usage patterns
- CPU usage baselines
- Network traffic patterns

## Integration

**Works with:**
- `uptime-kuma-manager` - Service uptime monitoring
- `dozzle-log-manager` - Log correlation during incidents
- `monitoring-alerting` - Unified alert management
- `docker-deploy` - Container metrics validation

**Triggers:**
- Session start: Check Netdata agents are streaming
- Pre-deployment: Baseline current metrics
- Post-deployment: Compare performance impact
- Incident: Correlate metrics with alerts

## Best Practices

1. **Retention**: Keep 1 day locally, 30 days on parent
2. **Streaming**: All agents stream to central parent
3. **Alerts**: Set thresholds based on baseline + 20%
4. **Updates**: Auto-update Netdata agents weekly
5. **Security**: Use SSL for streaming, restrict dashboard access

## Troubleshooting

**Agent not streaming to parent:**
- Check parent API key in `/etc/netdata/stream.conf`
- Verify network connectivity on port 19998
- Check parent logs: `journalctl -u netdata`
- Validate agent config: `netdata -W buildinfo`

**High CPU usage by Netdata:**
- Reduce metric retention period
- Disable unused plugins
- Increase update interval for expensive checks
- Review custom collectors

**Missing metrics:**
- Check plugin is enabled: `/etc/netdata/netdata.conf`
- Verify plugin dependencies are installed
- Review plugin logs: `/var/log/netdata/`
- Test plugin manually: `/usr/libexec/netdata/plugins.d/`

**Alerts not firing:**
- Check alert config: `/etc/netdata/health.d/`
- Verify notification method: `/etc/netdata/health_alarm_notify.conf`
- Test notification: `netdatacli ping`
- Review alert log: `/var/log/netdata/health.log`

## API Reference

```bash
# Netdata REST API (authentication required)
GET /api/v1/info - Agent information
GET /api/v1/charts - Available charts
GET /api/v1/data?chart=system.cpu - Chart data
GET /api/v1/alarms - Current alarms
GET /api/v1/alarm_log - Alarm history
```

## Performance Tuning

**Low-resource hosts:**
```conf
[global]
    update every = 5
    memory mode = ram
    history = 3600
```

**High-performance hosts:**
```conf
[global]
    update every = 1
    memory mode = dbengine
    page cache size = 128
    dbengine disk space = 2048
```

## Custom Dashboards

**Infrastructure Overview:**
- All hosts CPU/memory/disk summary
- Active alerts across infrastructure
- Network traffic trends
- Container resource usage

**Service-specific:**
- Database performance (queries, connections)
- Web server metrics (requests, response times)
- Docker metrics (container count, resource limits)
- Storage metrics (ZFS ARC, disk I/O)

## Related

- Skill: `uptime-kuma-manager` - Service monitoring
- Skill: `dozzle-log-manager` - Log analysis
- Skill: `monitoring-alerting` - Alert orchestration
- Command: `/metrics <host>` - View host metrics
- Script: `infrastructure-ops/scripts/monitoring/netdata-install.sh`

---

**Last Updated:** 2025-12-06
**Category:** Infrastructure, Monitoring, Performance
**Priority:** High
