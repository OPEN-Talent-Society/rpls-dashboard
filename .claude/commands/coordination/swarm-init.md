# swarm-init

Initialize a new agent swarm with specified topology.

## Usage
```bash
/opt/homebrew/bin/claude-flow swarm init [options]
```

## Options
- `--topology <type>` - Swarm topology (mesh, hierarchical, ring, star)
- `--max-agents <n>` - Maximum number of agents
- `--strategy <type>` - Execution strategy (parallel, sequential, adaptive)

## Examples
```bash
# Initialize hierarchical swarm
/opt/homebrew/bin/claude-flow swarm init --topology hierarchical

# With agent limit
/opt/homebrew/bin/claude-flow swarm init --topology mesh --max-agents 8

# Parallel execution
/opt/homebrew/bin/claude-flow swarm init --strategy parallel
```
