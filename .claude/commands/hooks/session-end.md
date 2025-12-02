# session-end

Hook executed at session end.

## Usage
```bash
pnpm dlx claude-flow hook session-end [options]
```

## Options
- `--export-metrics` - Export session metrics
- `--generate-summary` - Generate session summary
- `--persist-state` - Save session state

## Examples
```bash
# End session
pnpm dlx claude-flow hook session-end

# Export metrics
pnpm dlx claude-flow hook session-end --export-metrics

# Full closure
pnpm dlx claude-flow hook session-end --export-metrics --generate-summary --persist-state
```
