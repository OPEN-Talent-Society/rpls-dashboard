# real-time-view

Real-time view of swarm activity.

## Usage
```bash
pnpm dlx claude-flow monitoring real-time-view [options]
```

## Options
- `--filter <type>` - Filter view
- `--highlight <pattern>` - Highlight pattern
- `--tail <n>` - Show last N events

## Examples
```bash
# Start real-time view
pnpm dlx claude-flow monitoring real-time-view

# Filter errors
pnpm dlx claude-flow monitoring real-time-view --filter errors

# Highlight pattern
pnpm dlx claude-flow monitoring real-time-view --highlight "API"
```
