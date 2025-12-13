# GitHub Repository Operations Skill

**Category:** DevOps
**Dependencies:** GitHub CLI (gh), git
**Token Budget:** ~3500 tokens

## Purpose

Comprehensive GitHub repository management including creation, cloning, synchronization, backup, and lifecycle operations. Integrates with Harbor Homelab infrastructure for automated backups to NAS/OCI.

## When to Use

- Creating new repositories locally or on GitHub
- Cloning repositories with consistent directory structure
- Syncing multiple repositories with remotes
- Backing up repositories to NAS or cloud storage
- Managing repository settings and metadata
- Archiving or deleting repositories

## Capabilities

### Repository Creation
- Create local repositories with proper initialization
- Create GitHub repositories with templates
- Set up default branch protection rules
- Configure repository settings (visibility, features)

### Repository Cloning
- Clone repositories to standardized locations
- Batch clone organization repositories
- Clone with submodules and LFS support
- Shallow cloning for large repositories

### Repository Synchronization
- Sync all local repositories with remotes
- Detect diverged branches
- Handle merge conflicts gracefully
- Update submodules automatically

### Repository Backup
- Backup to Harbor NAS (`/mnt/harbor-nas/backups/git`)
- Backup to OCI Object Storage
- Create compressed archives with metadata
- Incremental backup support
- Restore from backups

### Repository Management
- List all repositories in codebuild directory
- Check repository health (uncommitted changes, unpushed commits)
- Archive inactive repositories
- Delete repositories with safety checks

## Usage Examples

### Create New Repository

```bash
# Interactive creation
gh repo create my-project --public --clone

# With template
gh repo create my-app --template adamkovacs/nodejs-template --private

# Local only
git init /Users/adamkovacs/Documents/codebuild/new-project
```

### Clone Organization Repositories

```bash
# Clone all repos from organization
gh repo list aienablement-academy --limit 100 --json name,sshUrl \
  | jq -r '.[] | .sshUrl' \
  | xargs -I {} git clone {} /Users/adamkovacs/Documents/codebuild/

# Clone specific repos
gh repo clone adamkovacs/project-name /Users/adamkovacs/Documents/codebuild/project-name
```

### Sync All Repositories

```bash
# Status check for all repos
find /Users/adamkovacs/Documents/codebuild -maxdepth 1 -type d -name ".git" -execdir bash -c '
  echo "=== $(basename $(pwd)) ==="
  git status --short
  git fetch --dry-run
' \;

# Pull updates for all repos
find /Users/adamkovacs/Documents/codebuild -maxdepth 1 -type d -name ".git" -execdir bash -c '
  echo "=== $(basename $(pwd)) ==="
  git pull --rebase
' \;
```

### Backup Repositories

```bash
# Backup single repository
REPO_NAME=$(basename $(pwd))
DATE=$(date +%Y%m%d-%H%M%S)
tar -czf "/mnt/harbor-nas/backups/git/${REPO_NAME}-${DATE}.tar.gz" \
  --exclude='.git' \
  --exclude='node_modules' \
  --exclude='dist' \
  .

# Backup all repositories
for repo in /Users/adamkovacs/Documents/codebuild/*/; do
  REPO_NAME=$(basename "$repo")
  tar -czf "/mnt/harbor-nas/backups/git/${REPO_NAME}-${DATE}.tar.gz" \
    -C "$repo" .
done
```

### Repository Health Check

```bash
# Check for uncommitted changes
find /Users/adamkovacs/Documents/codebuild -maxdepth 1 -type d -name ".git" -execdir bash -c '
  if [[ -n $(git status --porcelain) ]]; then
    echo "⚠️  $(basename $(pwd)): Has uncommitted changes"
  fi
' \;

# Check for unpushed commits
find /Users/adamkovacs/Documents/codebuild -maxdepth 1 -type d -name ".git" -execdir bash -c '
  UNPUSHED=$(git log @{u}.. --oneline 2>/dev/null | wc -l)
  if [[ $UNPUSHED -gt 0 ]]; then
    echo "⚠️  $(basename $(pwd)): $UNPUSHED unpushed commits"
  fi
' \;
```

## Configuration

### Environment Variables

```bash
# Default clone location
export CODEBUILD_DIR="/Users/adamkovacs/Documents/codebuild"

# Backup location
export GIT_BACKUP_DIR="/mnt/harbor-nas/backups/git"

# GitHub organization
export GITHUB_ORG="aienablement-academy"
```

### GitHub CLI Configuration

```bash
# Authenticate
gh auth login

# Set default protocol
gh config set git_protocol ssh

# Set default editor
gh config set editor "code --wait"
```

## Integration Points

- **NAS Backup**: Automated backups to `/mnt/harbor-nas/backups/git`
- **OCI Object Storage**: Cloud backup with lifecycle policies
- **Cortex**: Log repository operations to knowledge base
- **NocoDB**: Track repository metadata and health metrics
- **AgentDB**: Store repository patterns and best practices

## Error Handling

- Validates GitHub CLI installation and authentication
- Checks for sufficient disk space before operations
- Handles network failures with retry logic
- Validates SSH keys for GitHub access
- Creates backup directories if missing
- Logs all operations for audit trail

## Best Practices

1. **Clone Organization**: Group repositories by organization/team
2. **Consistent Naming**: Use kebab-case for repository names
3. **Regular Backups**: Schedule daily backups via cron
4. **Health Checks**: Run weekly repository health checks
5. **Branch Protection**: Enable branch protection for main/develop
6. **SSH Keys**: Use SSH protocol for authentication
7. **LFS Support**: Enable Git LFS for large file repositories
8. **Submodules**: Track submodule updates carefully

## Scripts Location

- **Main Script**: `.claude/skills/github-repo-ops/scripts/repo-manager.sh`
- **Backup Script**: `.claude/skills/github-repo-ops/scripts/backup-repos.sh`
- **Sync Script**: `.claude/skills/github-repo-ops/scripts/sync-repos.sh`
- **Health Check**: `.claude/skills/github-repo-ops/scripts/health-check.sh`

## Related Skills

- `git-workflow-automation` - Automated commit and push workflows
- `github-issue-project-sync` - Issue and project management
- `infrastructure-git-ops` - GitOps for infrastructure
- `github-devops-pipeline` - CI/CD pipeline automation

## References

- [GitHub CLI Manual](https://cli.github.com/manual/)
- [Git Documentation](https://git-scm.com/doc)
- [GitHub API](https://docs.github.com/en/rest)
