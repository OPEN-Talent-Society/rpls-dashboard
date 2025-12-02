# repo-analyze

Deep analysis of GitHub repository with AI insights.

## Usage
```bash
pnpm dlx claude-flow github repo-analyze [options]
```

## Options
- `--repository <owner/repo>` - Repository to analyze
- `--deep` - Enable deep analysis
- `--include <areas>` - Include specific areas (issues, prs, code, commits)

## Examples
```bash
# Basic analysis
pnpm dlx claude-flow github repo-analyze --repository myorg/myrepo

# Deep analysis
pnpm dlx claude-flow github repo-analyze --repository myorg/myrepo --deep

# Specific areas
pnpm dlx claude-flow github repo-analyze --repository myorg/myrepo --include issues,prs
```
