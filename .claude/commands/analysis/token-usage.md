# token-usage

Analyze token usage patterns and optimize for efficiency.

## Usage
```bash
pnpm dlx claude-flow analysis token-usage [options]
```

## Options
- `--period <time>` - Analysis period (1h, 24h, 7d, 30d)
- `--by-agent` - Break down by agent
- `--by-operation` - Break down by operation type

## Examples
```bash
# Last 24 hours token usage
pnpm dlx claude-flow analysis token-usage --period 24h

# By agent breakdown
pnpm dlx claude-flow analysis token-usage --by-agent

# Export detailed report
pnpm dlx claude-flow analysis token-usage --period 7d --export tokens.csv
```
