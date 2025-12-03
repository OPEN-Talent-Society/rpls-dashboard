# swarm-init

Initialize a new swarm with specified topology.

## Usage
```bash
/opt/homebrew/bin/claude-flow swarm init [options]
```

## Options
- `--topology <type>` - Swarm topology (mesh, hierarchical, ring, star)
- `--max-agents <n>` - Maximum agents
- `--strategy <type>` - Distribution strategy

## Examples
```bash
/opt/homebrew/bin/claude-flow swarm init --topology mesh
/opt/homebrew/bin/claude-flow swarm init --topology hierarchical --max-agents 8
```
