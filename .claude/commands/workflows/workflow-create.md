# workflow-create

Create reusable workflow templates.

## Usage
```bash
pnpm dlx claude-flow workflow create [options]
```

## Options
- `--name <name>` - Workflow name
- `--from-history` - Create from history
- `--interactive` - Interactive creation

## Examples
```bash
# Create workflow
pnpm dlx claude-flow workflow create --name "deploy-api"

# From history
pnpm dlx claude-flow workflow create --name "test-suite" --from-history

# Interactive mode
pnpm dlx claude-flow workflow create --interactive
```
