# workflow-select

Automatically select optimal workflow based on task type.

## Usage
```bash
pnpm dlx claude-flow automation workflow-select [options]
```

## Options
- `--task <description>` - Task description
- `--constraints <list>` - Workflow constraints
- `--preview` - Preview without executing

## Examples
```bash
# Select workflow for task
pnpm dlx claude-flow automation workflow-select --task "Deploy to production"

# With constraints
pnpm dlx claude-flow automation workflow-select --constraints "no-downtime,rollback"

# Preview mode
pnpm dlx claude-flow automation workflow-select --task "Database migration" --preview
```
