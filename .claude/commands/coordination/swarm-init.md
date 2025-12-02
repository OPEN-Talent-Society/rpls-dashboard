# swarm-init

Initialize a new agent swarm with specified topology.

## Usage
```bash
pnpm dlx claude-flow swarm init [options]
```

## Options
- `--topology <type>` - Swarm topology (mesh, hierarchical, ring, star)
- `--max-agents <n>` - Maximum number of agents
- `--strategy <type>` - Execution strategy (parallel, sequential, adaptive)

## Examples
```bash
# Initialize hierarchical swarm
pnpm dlx claude-flow swarm init --topology hierarchical

# With agent limit
pnpm dlx claude-flow swarm init --topology mesh --max-agents 8

# Parallel execution
pnpm dlx claude-flow swarm init --strategy parallel
```
