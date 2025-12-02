# smart-spawn

Intelligently spawn agents based on workload analysis.

## Usage
```bash
pnpm dlx claude-flow automation smart-spawn [options]
```

## Options
- `--analyze` - Analyze before spawning
- `--threshold <n>` - Spawn threshold
- `--topology <type>` - Preferred topology

## Examples
```bash
# Smart spawn with analysis
pnpm dlx claude-flow automation smart-spawn --analyze

# Set spawn threshold
pnpm dlx claude-flow automation smart-spawn --threshold 5

# Force topology
pnpm dlx claude-flow automation smart-spawn --topology hierarchical
```
