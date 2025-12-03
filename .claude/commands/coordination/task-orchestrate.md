# task-orchestrate

Orchestrate complex tasks across the swarm.

## Usage
```bash
/opt/homebrew/bin/claude-flow task orchestrate [options]
```

## Options
- `--task <description>` - Task description
- `--strategy <type>` - Orchestration strategy
- `--priority <level>` - Task priority (low, medium, high, critical)

## Examples
```bash
# Orchestrate development task
/opt/homebrew/bin/claude-flow task orchestrate --task "Implement user authentication"

# High priority task
/opt/homebrew/bin/claude-flow task orchestrate --task "Fix production bug" --priority critical

# With specific strategy
/opt/homebrew/bin/claude-flow task orchestrate --task "Refactor codebase" --strategy parallel
```
