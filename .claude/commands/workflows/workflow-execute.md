# workflow-execute

Execute saved workflows.

## Usage
```bash
pnpm dlx claude-flow workflow execute [options]
```

## Options
- `--name <name>` - Workflow name
- `--params <json>` - Workflow parameters
- `--dry-run` - Preview execution

## Examples
```bash
# Execute workflow
pnpm dlx claude-flow workflow execute --name "deploy-api"

# With parameters
pnpm dlx claude-flow workflow execute --name "test-suite" --params '{"env": "staging"}'

# Dry run
pnpm dlx claude-flow workflow execute --name "deploy-api" --dry-run
```
