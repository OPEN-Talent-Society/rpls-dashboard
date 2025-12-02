# hive-mind-spawn

Spawn a Hive Mind swarm with queen-led coordination.

## Usage
```bash
pnpm dlx claude-flow hive-mind spawn <objective> [options]
```

## Options
- `--queen-type <type>` - Queen type (strategic, tactical, adaptive)
- `--max-workers <n>` - Maximum worker agents
- `--consensus <type>` - Consensus algorithm
- `--claude` - Generate Claude Code spawn commands

## Examples
```bash
pnpm dlx claude-flow hive-mind spawn "Build API"
pnpm dlx claude-flow hive-mind spawn "Research patterns" --queen-type adaptive
pnpm dlx claude-flow hive-mind spawn "Build service" --claude
```
