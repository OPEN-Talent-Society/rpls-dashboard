# performance-report

Generate comprehensive performance reports for swarm operations.

## Usage
```bash
/opt/homebrew/bin/claude-flow analysis performance-report [options]
```

## Options
- `--format <type>` - Report format (json, html, markdown)
- `--include-metrics` - Include detailed metrics
- `--compare <id>` - Compare with previous swarm

## Examples
```bash
# Generate HTML report
/opt/homebrew/bin/claude-flow analysis performance-report --format html

# Compare swarms
/opt/homebrew/bin/claude-flow analysis performance-report --compare swarm-123

# Full metrics report
/opt/homebrew/bin/claude-flow analysis performance-report --include-metrics --format markdown
```
