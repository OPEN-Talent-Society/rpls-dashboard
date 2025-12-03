# issue-triage

Intelligent issue classification and triage.

## Usage
```bash
/opt/homebrew/bin/claude-flow github issue-triage [options]
```

## Options
- `--repository <owner/repo>` - Target repository
- `--auto-label` - Automatically apply labels
- `--assign` - Auto-assign to team members

## Examples
```bash
# Triage issues
/opt/homebrew/bin/claude-flow github issue-triage --repository myorg/myrepo

# With auto-labeling
/opt/homebrew/bin/claude-flow github issue-triage --repository myorg/myrepo --auto-label

# Full automation
/opt/homebrew/bin/claude-flow github issue-triage --repository myorg/myrepo --auto-label --assign
```
