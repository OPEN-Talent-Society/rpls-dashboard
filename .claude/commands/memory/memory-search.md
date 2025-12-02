# memory-search

Search through stored memory.

## Usage
```bash
pnpm dlx claude-flow memory search [options]
```

## Options
- `--query <text>` - Search query
- `--pattern <regex>` - Pattern matching
- `--limit <n>` - Result limit

## Examples
```bash
# Search memory
pnpm dlx claude-flow memory search --query "authentication"

# Pattern search
pnpm dlx claude-flow memory search --pattern "api-.*"

# Limited results
pnpm dlx claude-flow memory search --query "config" --limit 10
```
