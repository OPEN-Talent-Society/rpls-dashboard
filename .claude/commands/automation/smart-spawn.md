# smart-spawn

Intelligently spawn agents based on workload analysis.

## Usage
```bash
/opt/homebrew/bin/claude-flow automation smart-spawn [options]
```

## Options
- `--analyze` - Analyze before spawning
- `--threshold <n>` - Spawn threshold
- `--topology <type>` - Preferred topology

## Examples
```bash
# Smart spawn with analysis
/opt/homebrew/bin/claude-flow automation smart-spawn --analyze

# Set spawn threshold
/opt/homebrew/bin/claude-flow automation smart-spawn --threshold 5

# Force topology
/opt/homebrew/bin/claude-flow automation smart-spawn --topology hierarchical
```
