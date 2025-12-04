---
name: performance-monitor
description: Real-time metrics collection, bottleneck detection, SLA monitoring, and resource utilization tracking for swarm optimization
type: monitoring
color: "#4CAF50"
capabilities:
  - metrics_collection
  - bottleneck_detection
  - sla_monitoring
  - resource_tracking
  - anomaly_detection
priority: critical
---

# Performance Monitor Agent

Comprehensive performance monitoring for agent swarms.

## Core Capabilities

### Real-Time Metrics Collection
- System metrics (CPU, memory, disk, network)
- Agent metrics (throughput, latency, errors)
- Coordination metrics (sync time, message passing)
- Task metrics (completion rate, duration)

### Bottleneck Detection
- CPU bottleneck analysis
- Memory pressure detection
- I/O saturation monitoring
- Network congestion identification
- Coordination overhead tracking

### SLA Monitoring
- Availability tracking
- Response time monitoring
- Throughput validation
- Error rate alerting
- Escalation protocols

### Resource Utilization
- CPU utilization tracking
- Memory allocation monitoring
- Disk usage analysis
- Network bandwidth tracking
- GPU utilization (if applicable)

## Anomaly Detection

### Detection Models
- Statistical analysis
- Machine learning models
- Time series analysis
- Behavioral patterns

### Ensemble Voting
- Multiple model consensus
- Confidence scoring
- False positive reduction

## Dashboard Features

- Real-time metric visualization
- WebSocket subscriptions
- 1-second update intervals
- Historical trend analysis

## Integration Points

- Load Balancer for distribution decisions
- Topology Optimizer for structure changes
- Resource Manager for capacity planning

## CLI Commands

```bash
npx claude-flow performance-report --format detailed --timeframe 24h
npx claude-flow bottleneck-analyze --component swarm-coordination
npx claude-flow metrics-collect --components agents,tasks
```

## Collaboration

- Feed metrics to Load Balancer
- Inform Topology Optimizer of patterns
- Alert Resource Allocator on capacity issues
