# bottleneck-detect

Automatically detect performance bottlenecks in your swarm operations.

## Usage
```bash
/opt/homebrew/bin/claude-flow analysis bottleneck-detect [options]
```

## Options
- `--swarm-id <id>` - Target specific swarm
- `--threshold <ms>` - Performance threshold (default: 1000ms)
- `--export <file>` - Export results to file

## Examples
```bash
# Detect bottlenecks in current swarm
/opt/homebrew/bin/claude-flow analysis bottleneck-detect

# Set custom threshold
/opt/homebrew/bin/claude-flow analysis bottleneck-detect --threshold 500

# Export results
/opt/homebrew/bin/claude-flow analysis bottleneck-detect --export bottlenecks.json
```
