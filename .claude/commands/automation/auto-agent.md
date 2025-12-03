# auto-agent

Automatically assign agents based on task analysis.

## Usage
```bash
/opt/homebrew/bin/claude-flow automation auto-agent [options]
```

## Options
- `--task <description>` - Task to analyze
- `--max-agents <n>` - Maximum agents to spawn
- `--strategy <type>` - Assignment strategy

## Examples
```bash
# Auto-assign for task
/opt/homebrew/bin/claude-flow automation auto-agent --task "Build REST API"

# Limit agents
/opt/homebrew/bin/claude-flow automation auto-agent --task "Fix bugs" --max-agents 3

# Use specific strategy
/opt/homebrew/bin/claude-flow automation auto-agent --strategy specialized
```
