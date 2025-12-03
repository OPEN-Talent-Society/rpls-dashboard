# agent-metrics

View agent performance metrics.

## Usage
```bash
/opt/homebrew/bin/claude-flow agent metrics [options]
```

## Options
- `--agent-id <id>` - Specific agent
- `--period <time>` - Time period
- `--format <type>` - Output format

## Examples
```bash
# All agents metrics
/opt/homebrew/bin/claude-flow agent metrics

# Specific agent
/opt/homebrew/bin/claude-flow agent metrics --agent-id agent-001

# Last hour
/opt/homebrew/bin/claude-flow agent metrics --period 1h
```
