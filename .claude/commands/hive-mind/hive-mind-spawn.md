# hive-mind-spawn

Spawn a Hive Mind swarm with queen-led coordination.

## Usage
```bash
/opt/homebrew/bin/claude-flow hive-mind spawn <objective> [options]
```

## Options
- `--queen-type <type>` - Queen type (strategic, tactical, adaptive)
- `--max-workers <n>` - Maximum worker agents
- `--consensus <type>` - Consensus algorithm
- `--claude` - Generate Claude Code spawn commands

## Examples
```bash
/opt/homebrew/bin/claude-flow hive-mind spawn "Build API"
/opt/homebrew/bin/claude-flow hive-mind spawn "Research patterns" --queen-type adaptive
/opt/homebrew/bin/claude-flow hive-mind spawn "Build service" --claude
```
