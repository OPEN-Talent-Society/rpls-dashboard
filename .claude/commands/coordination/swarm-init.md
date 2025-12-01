# swarm-init

Initialize a new agent swarm with specified topology.

## Usage
```bash
npx claude-flow swarm init [options]
```

## Options
- `--topology <type>` - Swarm topology (mesh, hierarchical, ring, star)
- `--max-agents <n>` - Maximum number of agents
- `--strategy <type>` - Execution strategy (parallel, sequential, adaptive)

## Examples
```bash
# Initialize hierarchical swarm
npx claude-flow swarm init --topology hierarchical

# With agent limit
npx claude-flow swarm init --topology mesh --max-agents 8

# Parallel execution
npx claude-flow swarm init --strategy parallel
```
