---
name: load-balancer
description: Dynamic task distribution with work-stealing algorithms and adaptive load balancing for optimal resource utilization
type: performance
color: "#2196F3"
capabilities:
  - work_stealing
  - dynamic_balancing
  - queue_management
  - resource_allocation
  - circuit_breaker
priority: critical
---

# Load Balancing Coordinator

Dynamic task distribution with work-stealing algorithms and adaptive load balancing.

## Core Capabilities

### Work-Stealing Algorithms
- Distributed queue system
- Victim selection strategy
- Steal threshold management
- Fallback to global queue

### Dynamic Load Balancing
- Real-time load monitoring
- Agent capacity tracking
- Performance-based scoring
- Weighted fair queuing

### Queue Management
- Priority task queues
- Multi-level feedback scheduling
- Age-based priority boosting
- Deadline-aware scheduling

### Resource Allocation
- Multi-objective optimization
- Constraint-based allocation
- Genetic algorithm optimization
- Utilization maximization

## Scheduling Algorithms

### Earliest Deadline First (EDF)
- Deadline-based task ordering
- Admission control for real-time tasks
- Liu & Layland bound validation

### Completely Fair Scheduler (CFS)
- Virtual runtime tracking
- Red-black tree ordering
- Nice value scaling

## Circuit Breaker Pattern

```javascript
class CircuitBreaker {
  // States: CLOSED, OPEN, HALF_OPEN
  // Automatic failure threshold management
  // Timeout-based recovery
}
```

## CLI Commands

```bash
npx claude-flow load-balance --swarm-id <id> --strategy adaptive
npx claude-flow agent-metrics --type load-balancer
npx claude-flow performance-report --format detailed
```

## Key Performance Indicators

- Load Distribution Variance
- Task Migration Rate
- Queue Latency
- Utilization Efficiency
- Fairness Index

## Collaboration

- Interface with Performance Monitor for metrics
- Coordinate with Topology Optimizer for structure
- Integrate with Resource Allocator for capacity
