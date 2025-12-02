# workflow-export

Export workflows for sharing.

## Usage
```bash
pnpm dlx claude-flow workflow export [options]
```

## Options
- `--name <name>` - Workflow to export
- `--format <type>` - Export format
- `--include-history` - Include execution history

## Examples
```bash
# Export workflow
pnpm dlx claude-flow workflow export --name "deploy-api"

# As YAML
pnpm dlx claude-flow workflow export --name "test-suite" --format yaml

# With history
pnpm dlx claude-flow workflow export --name "deploy-api" --include-history
```
