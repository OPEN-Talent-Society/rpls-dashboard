# agent-metrics

View agent performance metrics.

## Usage
```bash
pnpm dlx claude-flow agent metrics [options]
```

## Options
- `--agent-id <id>` - Specific agent
- `--period <time>` - Time period
- `--format <type>` - Output format

## Examples
```bash
# All agents metrics
pnpm dlx claude-flow agent metrics

# Specific agent
pnpm dlx claude-flow agent metrics --agent-id agent-001

# Last hour
pnpm dlx claude-flow agent metrics --period 1h
```
