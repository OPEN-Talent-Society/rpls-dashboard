# GitHub Issue & Project Sync Skill

**Category:** DevOps
**Dependencies:** GitHub CLI (gh), NocoDB MCP
**Token Budget:** ~2800 tokens

## Purpose

Synchronize GitHub issues and projects with internal task tracking systems (NocoDB, Cortex), automate issue creation from errors/logs, and maintain bidirectional sync between development work and project management tools.

## When to Use

- Syncing GitHub issues with NocoDB task database
- Creating issues from application errors or alerts
- Tracking project progress across platforms
- Generating reports from issue metrics
- Automating issue lifecycle management
- Linking commits/PRs to issues

## Capabilities

### Issue Management
- Create issues from templates
- Bulk issue operations (label, assign, close)
- Link issues to commits and PRs
- Auto-close issues on merge
- Issue search and filtering

### Project Synchronization
- Sync GitHub Projects with NocoDB
- Two-way sync: GitHub ↔ NocoDB
- Status mapping and translation
- Priority and label synchronization
- Assignee mapping

### Automated Issue Creation
- Create issues from error logs
- Generate issues from monitoring alerts
- Template-based issue creation
- Attach relevant context automatically
- Link to related issues

### Reporting & Metrics
- Issue velocity tracking
- Time-to-close analytics
- Label distribution reports
- Contributor activity metrics
- Sprint burndown charts

## Usage Examples

### Create Issue from Template

```bash
# Interactive issue creation
gh issue create

# From template
gh issue create --template bug_report.md \
  --title "API timeout on user endpoint" \
  --label bug,high-priority \
  --assignee @me

# With body from file
gh issue create --title "Feature request" --body-file feature.md
```

### Sync GitHub Issues to NocoDB

```bash
# Fetch all open issues
gh issue list --state open --json number,title,state,labels,assignees,createdAt \
  | jq -r '.[] | [.number, .title, .state] | @tsv' \
  | while IFS=$'\t' read -r number title state; do
    # Create/update in NocoDB
    mcp__nocodb-base-ops__createRecord({
      tableId: "mmx3z4zxdj9ysfk",
      data: {
        "task name": "$title",
        "Status": "$state",
        "github_issue": "$number"
      }
    })
  done
```

### Auto-Create Issue from Error

```bash
# Monitor logs and create issues
tail -f /var/log/app.log | while read line; do
  if echo "$line" | grep -q "ERROR"; then
    ERROR_MSG=$(echo "$line" | jq -r '.message')
    STACK_TRACE=$(echo "$line" | jq -r '.stack')

    gh issue create \
      --title "Error: $ERROR_MSG" \
      --body "## Stack Trace\n\`\`\`\n$STACK_TRACE\n\`\`\`" \
      --label bug,automated
  fi
done
```

### Link Commit to Issue

```bash
# Commit with issue reference (auto-closes on merge to main)
git commit -m "fix(api): resolve timeout issue

Closes #123"

# Link PR to issue
gh pr create --fill --assignee @me --label bug
# In PR body: "Fixes #123"
```

### Project Board Automation

```bash
# Move issue to "In Progress" column
gh issue edit 123 --add-project "Development" --project-column "In Progress"

# Add issue to project
gh project item-add 1 --owner adamkovacs --url https://github.com/owner/repo/issues/123

# List project items
gh project item-list 1 --owner adamkovacs --format json
```

### Issue Metrics Report

```bash
# Issues created this week
gh issue list --created "$(date -d '7 days ago' +%Y-%m-%d).." --json number,title,createdAt

# Average time to close
gh issue list --state closed --json number,closedAt,createdAt \
  | jq -r '.[] | (.closedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)' \
  | awk '{sum+=$1; count++} END {print "Average time to close:", sum/count/86400, "days"}'

# Issues by label
gh issue list --json labels \
  | jq -r '.[].labels[].name' \
  | sort | uniq -c | sort -rn
```

### Bidirectional Sync Script

```bash
#!/bin/bash
# Sync NocoDB tasks to GitHub issues

# Get NocoDB tasks without GitHub issue
TASKS=$(mcp__nocodb-base-ops__queryRecords \
  --tableId mmx3z4zxdj9ysfk \
  --fields "Id,task name,Status,github_issue" \
  --where "(github_issue,is,null)")

echo "$TASKS" | jq -r '.[] | @base64' | while read -r task; do
  TASK_NAME=$(echo "$task" | base64 -d | jq -r '.["task name"]')
  TASK_ID=$(echo "$task" | base64 -d | jq -r '.Id')

  # Create GitHub issue
  ISSUE_URL=$(gh issue create --title "$TASK_NAME" --json url | jq -r '.url')
  ISSUE_NUMBER=$(basename "$ISSUE_URL")

  # Update NocoDB with issue number
  mcp__nocodb-base-ops__updateRecord \
    --tableId mmx3z4zxdj9ysfk \
    --recordId "$TASK_ID" \
    --data "{\"github_issue\": \"$ISSUE_NUMBER\"}"
done
```

## Configuration

### GitHub Issue Templates (.github/ISSUE_TEMPLATE/)

**Bug Report (bug_report.md)**
```markdown
---
name: Bug Report
about: Report a bug or unexpected behavior
title: '[BUG] '
labels: bug
assignees: ''
---

## Description
A clear description of the bug.

## Steps to Reproduce
1. Step one
2. Step two
3. See error

## Expected Behavior
What should happen.

## Actual Behavior
What actually happens.

## Environment
- OS: [e.g., macOS 14]
- Node Version: [e.g., 20.10.0]
- Browser: [e.g., Chrome 120]

## Additional Context
Any other relevant information.
```

**Feature Request (feature_request.md)**
```markdown
---
name: Feature Request
about: Suggest a new feature
title: '[FEATURE] '
labels: enhancement
assignees: ''
---

## Problem Statement
What problem does this feature solve?

## Proposed Solution
How should this feature work?

## Alternatives Considered
Other approaches you've thought about.

## Additional Context
Mockups, diagrams, or examples.
```

### Status Mapping (NocoDB ↔ GitHub)

```typescript
const statusMap = {
  // NocoDB → GitHub
  'To Do': 'open',
  'In Progress': 'open',
  'Review': 'open',
  'Done': 'closed',
  'Blocked': 'open',

  // GitHub → NocoDB
  'open': 'To Do',
  'closed': 'Done'
};
```

### Label Categories

```yaml
priority:
  - low-priority
  - medium-priority
  - high-priority
  - critical

type:
  - bug
  - enhancement
  - feature
  - documentation
  - refactor

status:
  - needs-triage
  - blocked
  - help-wanted
  - wontfix
  - duplicate

area:
  - frontend
  - backend
  - infrastructure
  - devops
```

## Integration Points

- **NocoDB**: Sync tasks with GitHub issues
- **Cortex**: Log issue lifecycle events
- **AgentDB**: Store issue resolution patterns
- **Monitoring**: Auto-create issues from alerts
- **CI/CD**: Link deployments to issues

## Automation Workflows

### GitHub Actions: Auto-Label Issues

```yaml
name: Auto Label Issues
on:
  issues:
    types: [opened]

jobs:
  label:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/labeler@v5
        with:
          repo-token: ${{ secrets.GITHUB_TOKEN }}
```

### GitHub Actions: Close Stale Issues

```yaml
name: Close Stale Issues
on:
  schedule:
    - cron: '0 0 * * *'

jobs:
  stale:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/stale@v9
        with:
          stale-issue-message: 'This issue is stale and will be closed soon.'
          days-before-stale: 30
          days-before-close: 7
```

## Error Handling

- Validates GitHub authentication before operations
- Handles rate limiting with exponential backoff
- Retries failed API calls automatically
- Logs sync errors to Cortex
- Creates alert issues for critical sync failures
- Validates issue references in commits

## Best Practices

1. **Issue Templates**: Use templates for consistency
2. **Labels**: Standardize labels across repositories
3. **Automation**: Automate repetitive tasks
4. **Linking**: Always link commits/PRs to issues
5. **Milestones**: Use milestones for sprint planning
6. **Projects**: Use GitHub Projects for visual tracking
7. **Search**: Use advanced search for filtering
8. **Metrics**: Track velocity and burn-down regularly

## Scripts Location

- **Sync Script**: `.claude/skills/github-issue-project-sync/scripts/sync-issues.sh`
- **Create Issue**: `.claude/skills/github-issue-project-sync/scripts/create-issue.sh`
- **Metrics**: `.claude/skills/github-issue-project-sync/scripts/issue-metrics.sh`

## Related Skills

- `github-repo-ops` - Repository management
- `git-workflow-automation` - Git workflows
- `github-devops-pipeline` - CI/CD integration

## References

- [GitHub Issues](https://docs.github.com/en/issues)
- [GitHub Projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [GitHub CLI Issues](https://cli.github.com/manual/gh_issue)
