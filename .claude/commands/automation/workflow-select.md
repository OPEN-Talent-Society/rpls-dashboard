# workflow-select

Automatically select optimal workflow based on task type.

## Usage
```bash
/opt/homebrew/bin/claude-flow automation workflow-select [options]
```

## Options
- `--task <description>` - Task description
- `--constraints <list>` - Workflow constraints
- `--preview` - Preview without executing

## Examples
```bash
# Select workflow for task
/opt/homebrew/bin/claude-flow automation workflow-select --task "Deploy to production"

# With constraints
/opt/homebrew/bin/claude-flow automation workflow-select --constraints "no-downtime,rollback"

# Preview mode
/opt/homebrew/bin/claude-flow automation workflow-select --task "Database migration" --preview
```
