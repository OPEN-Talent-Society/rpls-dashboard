# real-time-view

Real-time view of swarm activity.

## Usage
```bash
/opt/homebrew/bin/claude-flow monitoring real-time-view [options]
```

## Options
- `--filter <type>` - Filter view
- `--highlight <pattern>` - Highlight pattern
- `--tail <n>` - Show last N events

## Examples
```bash
# Start real-time view
/opt/homebrew/bin/claude-flow monitoring real-time-view

# Filter errors
/opt/homebrew/bin/claude-flow monitoring real-time-view --filter errors

# Highlight pattern
/opt/homebrew/bin/claude-flow monitoring real-time-view --highlight "API"
```
