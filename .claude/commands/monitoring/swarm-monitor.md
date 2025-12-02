# swarm-monitor

Real-time swarm monitoring.

## Usage
```bash
pnpm dlx claude-flow swarm monitor [options]
```

## Options
- `--interval <ms>` - Update interval
- `--metrics` - Show detailed metrics
- `--export` - Export monitoring data

## Examples
```bash
# Start monitoring
pnpm dlx claude-flow swarm monitor

# Custom interval
pnpm dlx claude-flow swarm monitor --interval 5000

# With metrics
pnpm dlx claude-flow swarm monitor --metrics
```
