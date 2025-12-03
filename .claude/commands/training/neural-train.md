# neural-train

Train neural patterns from operations.

## Usage
```bash
/opt/homebrew/bin/claude-flow training neural-train [options]
```

## Options
- `--data <source>` - Training data source
- `--model <name>` - Target model
- `--epochs <n>` - Training epochs

## Examples
```bash
# Train from recent ops
/opt/homebrew/bin/claude-flow training neural-train --data recent

# Specific model
/opt/homebrew/bin/claude-flow training neural-train --model task-predictor

# Custom epochs
/opt/homebrew/bin/claude-flow training neural-train --epochs 100
```
