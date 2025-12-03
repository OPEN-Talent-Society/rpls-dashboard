# swarm-spawn

Spawn agents in the swarm.

## Usage
```bash
/opt/homebrew/bin/claude-flow swarm spawn [options]
```

## Options
- `--type <type>` - Agent type
- `--count <n>` - Number to spawn
- `--capabilities <list>` - Agent capabilities

## Examples
```bash
/opt/homebrew/bin/claude-flow swarm spawn --type coder --count 3
/opt/homebrew/bin/claude-flow swarm spawn --type researcher --capabilities "web-search,analysis"
```
