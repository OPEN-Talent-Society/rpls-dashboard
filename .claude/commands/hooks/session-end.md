# session-end

Hook executed at session end.

## Usage
```bash
/opt/homebrew/bin/claude-flow hook session-end [options]
```

## Options
- `--export-metrics` - Export session metrics
- `--generate-summary` - Generate session summary
- `--persist-state` - Save session state

## Examples
```bash
# End session
/opt/homebrew/bin/claude-flow hook session-end

# Export metrics
/opt/homebrew/bin/claude-flow hook session-end --export-metrics

# Full closure
/opt/homebrew/bin/claude-flow hook session-end --export-metrics --generate-summary --persist-state
```
