# parallel-execute

Execute tasks in parallel for maximum efficiency.

## Usage
```bash
/opt/homebrew/bin/claude-flow optimization parallel-execute [options]
```

## Options
- `--tasks <file>` - Task list file
- `--max-parallel <n>` - Maximum parallel tasks
- `--strategy <type>` - Execution strategy

## Examples
```bash
# Execute task list
/opt/homebrew/bin/claude-flow optimization parallel-execute --tasks tasks.json

# Limit parallelism
/opt/homebrew/bin/claude-flow optimization parallel-execute --tasks tasks.json --max-parallel 5

# Custom strategy
/opt/homebrew/bin/claude-flow optimization parallel-execute --strategy adaptive
```
