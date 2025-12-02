# issue-triage

Intelligent issue classification and triage.

## Usage
```bash
pnpm dlx claude-flow github issue-triage [options]
```

## Options
- `--repository <owner/repo>` - Target repository
- `--auto-label` - Automatically apply labels
- `--assign` - Auto-assign to team members

## Examples
```bash
# Triage issues
pnpm dlx claude-flow github issue-triage --repository myorg/myrepo

# With auto-labeling
pnpm dlx claude-flow github issue-triage --repository myorg/myrepo --auto-label

# Full automation
pnpm dlx claude-flow github issue-triage --repository myorg/myrepo --auto-label --assign
```
