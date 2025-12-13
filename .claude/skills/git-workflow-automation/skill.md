# Git Workflow Automation Skill

**Category:** DevOps
**Dependencies:** git, GitHub CLI (gh)
**Token Budget:** ~3200 tokens

## Purpose

Automate common git workflows including smart commits with conventional commit format, automated push workflows, PR creation, branch management, and integration with pre-commit hooks for quality enforcement.

## When to Use

- Committing code with consistent message format
- Creating pull requests from feature branches
- Managing branch lifecycle (create, merge, delete)
- Automating git operations in CI/CD pipelines
- Enforcing commit message conventions
- Synchronizing branches with remote

## Capabilities

### Smart Commits
- Conventional commit format enforcement
- Automatic scope detection from file paths
- AI-assisted commit message generation
- Multi-file staging with intelligent grouping
- Interactive commit selection

### Automated Push Workflows
- Push with automatic upstream branch creation
- Force push with lease (safe force push)
- Push tags automatically
- Sign commits with GPG
- Verify commits before push

### Pull Request Automation
- Create PR from current branch
- Auto-fill PR template from commits
- Link issues automatically
- Request reviewers based on CODEOWNERS
- Set labels and milestones

### Branch Management
- Create feature branches with naming conventions
- Clean up merged branches
- Sync with upstream (fork workflow)
- Rebase interactive workflows
- Cherry-pick commits across branches

### Commit Quality
- Lint commit messages
- Run pre-commit hooks
- Format code before commit
- Type-check TypeScript
- Run tests for changed files

## Usage Examples

### Smart Commit with Conventional Format

```bash
# Auto-detect type and scope
git add src/components/Button.tsx
git commit -m "Add primary button variant"
# Becomes: "feat(components): add primary button variant"

# Explicit type
git commit -m "fix: resolve memory leak in useEffect"

# Breaking change
git commit -m "feat!: migrate to new API endpoint"

# With body and footer
git commit -m "feat: add user authentication

Implements JWT-based authentication with refresh tokens.
Integrates with existing user management system.

Closes #123
BREAKING CHANGE: Auth API v1 is deprecated"
```

### Automated PR Creation

```bash
# Create PR from current branch
gh pr create --fill

# With template
gh pr create --title "Add feature X" --body-file .github/pull_request_template.md

# Draft PR
gh pr create --draft --title "WIP: Feature development"

# Auto-assign reviewers
gh pr create --fill --reviewer @me/team-leads

# Link to issue
gh pr create --fill --assignee @me --label enhancement --milestone v2.0
```

### Branch Workflow

```bash
# Create feature branch with convention
BRANCH_NAME="feature/user-auth-$(date +%Y%m%d)"
git checkout -b "$BRANCH_NAME"

# Sync with main before creating PR
git fetch origin main
git rebase origin/main

# Clean up merged branches
git branch --merged main | grep -v "^\*\|main\|develop" | xargs -r git branch -d

# Delete remote merged branches
gh pr list --state merged --json number,headRefName \
  | jq -r '.[].headRefName' \
  | xargs -I {} git push origin --delete {}
```

### Interactive Rebase Workflow

```bash
# Rebase last 5 commits
git rebase -i HEAD~5

# Squash commits for clean history
git rebase -i main

# Fixup commit (auto-squash)
git commit --fixup <commit-sha>
git rebase -i --autosquash main
```

### Automated Push with Validation

```bash
# Pre-push validation
if pnpm lint && pnpm type-check; then
  git push origin $(git branch --show-current)
else
  echo "Pre-push checks failed. Fix issues before pushing."
  exit 1
fi

# Push with lease (safe force push)
git push --force-with-lease origin feature-branch

# Push tags
git push --follow-tags
```

### Commit Message Generation

```bash
# Generate commit message from diff
git diff --cached | ai-commit-message

# Interactive commit with AI suggestions
git add .
ai-commit --interactive
```

## Configuration

### Git Configuration

```bash
# Conventional commit template
git config --global commit.template ~/.gitmessage

# Auto-setup upstream on push
git config --global push.autoSetupRemote true

# Rebase on pull
git config --global pull.rebase true

# GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey <KEY_ID>

# Default branch
git config --global init.defaultBranch main
```

### Conventional Commit Template (~/.gitmessage)

```
# <type>(<scope>): <subject>
#
# <body>
#
# <footer>
#
# Type: feat, fix, docs, style, refactor, test, chore
# Scope: component, file, or module name
# Subject: imperative, lowercase, no period
# Body: motivation for change (optional)
# Footer: breaking changes, issue references (optional)
#
# Examples:
# feat(auth): add JWT token refresh
# fix(api): handle null response from server
# docs(readme): update installation instructions
# BREAKING CHANGE: API endpoint /v1/users is removed
```

### Pre-commit Configuration (.pre-commit-config.yaml)

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-merge-conflict

  - repo: local
    hooks:
      - id: lint
        name: ESLint
        entry: pnpm lint
        language: system
        pass_filenames: false

      - id: type-check
        name: TypeScript Type Check
        entry: pnpm type-check
        language: system
        pass_filenames: false
```

## Commit Message Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(auth): add OAuth login` |
| `fix` | Bug fix | `fix(api): handle timeout errors` |
| `docs` | Documentation | `docs(readme): update setup guide` |
| `style` | Code style (formatting) | `style(components): fix indentation` |
| `refactor` | Code refactoring | `refactor(utils): simplify date formatting` |
| `perf` | Performance improvement | `perf(query): optimize database query` |
| `test` | Add or update tests | `test(auth): add login edge cases` |
| `chore` | Maintenance tasks | `chore(deps): update dependencies` |
| `ci` | CI/CD changes | `ci(github): add deploy workflow` |
| `build` | Build system changes | `build(webpack): optimize bundle size` |

## Integration Points

- **Pre-commit Hooks**: Automatic quality checks before commit
- **GitHub Actions**: Trigger CI/CD on commit/PR events
- **Cortex**: Log git operations and decisions
- **AgentDB**: Store commit patterns and best practices
- **NocoDB**: Track PR metrics and velocity

## Error Handling

- Validates commit message format before commit
- Checks for uncommitted changes before branch operations
- Prevents force push to protected branches
- Validates GitHub CLI authentication
- Handles merge conflicts with clear instructions
- Rollback on failed operations

## Best Practices

1. **Atomic Commits**: One logical change per commit
2. **Descriptive Messages**: Clear, concise commit messages
3. **Branch Naming**: `<type>/<description>-<date>` format
4. **Regular Syncing**: Pull/rebase frequently to avoid conflicts
5. **Feature Branches**: Never commit directly to main
6. **PR Reviews**: Require at least one approval
7. **Clean History**: Squash/rebase before merging
8. **Sign Commits**: Use GPG for verified commits

## Scripts Location

- **Smart Commit**: `.claude/skills/git-workflow-automation/scripts/smart-commit.sh`
- **Auto PR**: `.claude/skills/git-workflow-automation/scripts/auto-pr.sh`
- **Branch Cleanup**: `.claude/skills/git-workflow-automation/scripts/cleanup-branches.sh`
- **Sync Upstream**: `.claude/skills/git-workflow-automation/scripts/sync-upstream.sh`

## Related Skills

- `github-repo-ops` - Repository management
- `github-issue-project-sync` - Issue tracking integration
- `github-devops-pipeline` - CI/CD automation

## References

- [Conventional Commits](https://www.conventionalcommits.org/)
- [Git Best Practices](https://git-scm.com/book/en/v2)
- [GitHub Flow](https://docs.github.com/en/get-started/quickstart/github-flow)
