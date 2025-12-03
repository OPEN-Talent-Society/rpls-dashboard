# workflow-execute

Execute saved workflows.

## Usage
```bash
/opt/homebrew/bin/claude-flow workflow execute [options]
```

## Options
- `--name <name>` - Workflow name
- `--params <json>` - Workflow parameters
- `--dry-run` - Preview execution

## Examples
```bash
# Execute workflow
/opt/homebrew/bin/claude-flow workflow execute --name "deploy-api"

# With parameters
/opt/homebrew/bin/claude-flow workflow execute --name "test-suite" --params '{"env": "staging"}'

# Dry run
/opt/homebrew/bin/claude-flow workflow execute --name "deploy-api" --dry-run
```
