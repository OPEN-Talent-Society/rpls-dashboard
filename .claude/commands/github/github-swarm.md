# github-swarm

Create a specialized swarm for GitHub repository management.

## Usage
```bash
/opt/homebrew/bin/claude-flow github swarm [options]
```

## Options
- `--repository <owner/repo>` - Target repository
- `--agents <n>` - Number of specialized agents
- `--focus <area>` - Focus area (maintenance, features, security)

## Examples
```bash
# Create GitHub swarm
/opt/homebrew/bin/claude-flow github swarm --repository myorg/myrepo

# With specific focus
/opt/homebrew/bin/claude-flow github swarm --repository myorg/myrepo --focus security

# Custom agent count
/opt/homebrew/bin/claude-flow github swarm --repository myorg/myrepo --agents 6
```
