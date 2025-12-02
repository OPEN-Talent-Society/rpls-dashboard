# pattern-learn

Learn patterns from successful operations.

## Usage
```bash
pnpm dlx claude-flow training pattern-learn [options]
```

## Options
- `--source <type>` - Pattern source
- `--threshold <score>` - Success threshold
- `--save <name>` - Save pattern set

## Examples
```bash
# Learn from all ops
pnpm dlx claude-flow training pattern-learn

# High success only
pnpm dlx claude-flow training pattern-learn --threshold 0.9

# Save patterns
pnpm dlx claude-flow training pattern-learn --save optimal-patterns
```
