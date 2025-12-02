# model-update

Update neural models with new data.

## Usage
```bash
pnpm dlx claude-flow training model-update [options]
```

## Options
- `--model <name>` - Model to update
- `--incremental` - Incremental update
- `--validate` - Validate after update

## Examples
```bash
# Update all models
pnpm dlx claude-flow training model-update

# Specific model
pnpm dlx claude-flow training model-update --model agent-selector

# Incremental with validation
pnpm dlx claude-flow training model-update --incremental --validate
```
