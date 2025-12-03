# workflow-create

Create reusable workflow templates.

## Usage
```bash
/opt/homebrew/bin/claude-flow workflow create [options]
```

## Options
- `--name <name>` - Workflow name
- `--from-history` - Create from history
- `--interactive` - Interactive creation

## Examples
```bash
# Create workflow
/opt/homebrew/bin/claude-flow workflow create --name "deploy-api"

# From history
/opt/homebrew/bin/claude-flow workflow create --name "test-suite" --from-history

# Interactive mode
/opt/homebrew/bin/claude-flow workflow create --interactive
```
