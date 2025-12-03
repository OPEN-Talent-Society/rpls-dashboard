# workflow-export

Export workflows for sharing.

## Usage
```bash
/opt/homebrew/bin/claude-flow workflow export [options]
```

## Options
- `--name <name>` - Workflow to export
- `--format <type>` - Export format
- `--include-history` - Include execution history

## Examples
```bash
# Export workflow
/opt/homebrew/bin/claude-flow workflow export --name "deploy-api"

# As YAML
/opt/homebrew/bin/claude-flow workflow export --name "test-suite" --format yaml

# With history
/opt/homebrew/bin/claude-flow workflow export --name "deploy-api" --include-history
```
