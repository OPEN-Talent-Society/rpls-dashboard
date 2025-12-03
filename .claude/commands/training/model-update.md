# model-update

Update neural models with new data.

## Usage
```bash
/opt/homebrew/bin/claude-flow training model-update [options]
```

## Options
- `--model <name>` - Model to update
- `--incremental` - Incremental update
- `--validate` - Validate after update

## Examples
```bash
# Update all models
/opt/homebrew/bin/claude-flow training model-update

# Specific model
/opt/homebrew/bin/claude-flow training model-update --model agent-selector

# Incremental with validation
/opt/homebrew/bin/claude-flow training model-update --incremental --validate
```
