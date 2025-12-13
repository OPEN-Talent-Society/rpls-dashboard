---
triggers:
  - store secret
  - retrieve secret
  - manage secrets
  - get api key
  - vaultwarden vault
  - secret rotation
  - generate env file
---

# Vaultwarden Secrets Manager

**Category:** Infrastructure Operations
**Description:** Store, retrieve, and manage secrets (API keys, passwords, tokens) using Vaultwarden for secure centralized secret management.

---

## Overview

This skill provides secure secret management using Vaultwarden at `bitwarden.harbor.fyi`. It handles:

- API key storage and retrieval
- Password management for services
- Environment variable generation
- Secret rotation tracking
- Secure sharing across team members

---

## Prerequisites

### Required Tools

```bash
# Bitwarden CLI
brew install bitwarden-cli

# jq for JSON processing
brew install jq

# Configure server
bw config server https://bitwarden.harbor.fyi
```

### Authentication

```bash
# Login with API key
bw login --apikey

# Unlock vault
export BW_SESSION=$(bw unlock --raw)
```

---

## Scripts Available

Located in `infrastructure-ops/scripts/vaultwarden/`:

1. **bw-secret-store.sh** - Store secrets in Vaultwarden
2. **bw-secret-get.sh** - Retrieve secrets from Vaultwarden

---

## Usage

### 1. Store a Secret

```bash
# Store API key
bash infrastructure-ops/scripts/vaultwarden/bw-secret-store.sh \
  "OpenAI API Key" \
  "sk-proj-xxxxxxxxxxxxxxxxxxxx" \
  "API Keys - AI Services"

# Store with custom fields
bash infrastructure-ops/scripts/vaultwarden/bw-secret-store.sh \
  "DigitalOcean Token" \
  "dop_v1_xxxxxxxxxxxx" \
  "API Keys - Cloud" \
  --field "environment:production" \
  --field "rotation_days:90"
```

### 2. Retrieve a Secret

```bash
# Get secret value
bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh "OpenAI API Key"

# Use in scripts
export OPENAI_API_KEY=$(bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh "OpenAI API Key")

# Get specific field
bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh "Database Password" --field "username"
```

### 3. Generate .env File

```bash
# Export secrets to .env format
bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh \
  --folder "Environment - Production" \
  --format env > .env

# Result:
# OPENAI_API_KEY=sk-proj-xxx
# DATABASE_URL=postgresql://user:pass@host/db
# STRIPE_SECRET_KEY=sk_test_xxx
```

---

## Secret Organization

### Recommended Folder Structure

```
Vaultwarden Vault
├── API Keys - AI Services
│   ├── OpenAI API Key
│   ├── Anthropic API Key
│   └── Gemini API Key
│
├── API Keys - Cloud
│   ├── DigitalOcean Token
│   ├── Oracle Cloud API Key
│   └── Cloudflare API Token
│
├── API Keys - Development
│   ├── GitHub Personal Access Token
│   ├── GitLab Deploy Token
│   └── NPM Auth Token
│
├── Database Credentials
│   ├── PostgreSQL Production
│   ├── MySQL Development
│   └── Redis Cache
│
├── Environment - Production
│   ├── App Environment Variables
│   └── Service Configuration
│
└── Service Passwords
    ├── Docker Registry
    ├── NocoDB Admin
    └── Vaultwarden Admin
```

---

## Secret Item Template

**Name Format:** `[Service Name] - [Type]`

**Example:** `OpenAI - API Key`

**Custom Fields:**
- `api_key` or `password`: The actual secret value
- `environment`: production, staging, development
- `service_url`: Where the secret is used
- `created_date`: When the secret was created
- `last_rotated`: Last rotation date
- `rotation_days`: Rotation frequency
- `owner`: Team or person responsible
- `scope`: What the key has access to

**Notes Section:**
```
Purpose: OpenAI API access for production AI features
Scope: Full API access (GPT-4, embeddings, fine-tuning)
Rate Limits: 10,000 requests/minute
Cost Limit: $1,000/month

Created: 2025-12-06
Last Rotated: 2025-12-06
Next Rotation: 2026-03-06 (90 days)

Emergency Contact: devops@aienablement.academy
```

---

## Common Use Cases

### 1. CI/CD Integration

```bash
# In GitHub Actions workflow
- name: Get secrets from Vaultwarden
  run: |
    export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASSWORD)
    export DEPLOY_TOKEN=$(bash scripts/bw-secret-get.sh "Deploy Token")
    # Use $DEPLOY_TOKEN in deployment
```

### 2. Docker Compose Secrets

```bash
# Generate .env for docker-compose
bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh \
  --folder "Environment - Docker Stack" \
  --format env > /opt/app/.env

# docker-compose.yml uses .env automatically
docker compose up -d
```

### 3. Script Automation

```bash
#!/usr/bin/env bash
# Get database credentials
DB_USER=$(bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh "PostgreSQL Production" --field username)
DB_PASS=$(bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh "PostgreSQL Production" --field password)

# Use credentials
psql -U "$DB_USER" -h db.harbor.fyi
```

---

## Secret Rotation

### Rotation Schedule

| Secret Type | Frequency | Automation |
|-------------|-----------|------------|
| Production API Keys | 90 days | Manual with reminders |
| Database Passwords | 90 days | Manual with reminders |
| Service Tokens | 180 days | Manual with reminders |
| Development Keys | 365 days | Manual |

### Rotation Workflow

```bash
# 1. Generate new secret
NEW_SECRET=$(openssl rand -base64 32)

# 2. Test new secret works
# (deploy to staging, verify functionality)

# 3. Update in Vaultwarden
bash infrastructure-ops/scripts/vaultwarden/bw-secret-store.sh \
  "Service Name" \
  "$NEW_SECRET" \
  "Folder Name" \
  --field "last_rotated:$(date +%Y-%m-%d)"

# 4. Deploy to production
# (update environment variables, restart services)

# 5. Archive old secret
# (keep in "Archived Secrets" folder for 30 days)
```

---

## Security Best Practices

### 1. Never Commit Secrets to Git

```bash
# Always use .env (gitignored)
echo ".env" >> .gitignore

# Use placeholders in .env.example
cat > .env.example <<EOF
OPENAI_API_KEY=sk-proj-your-key-here
DATABASE_URL=postgresql://user:pass@host/db
EOF
```

### 2. Limit Secret Scope

- Use separate keys for dev/staging/prod
- Grant minimum required permissions
- Use service-specific tokens (not personal)

### 3. Audit Secret Access

```bash
# Check who accessed secrets
bw list events --session "$BW_SESSION" | jq '.[] | select(.type == 1001)'

# Monitor for unusual access patterns
```

### 4. Encrypt Backups

```bash
# Never store secrets in plaintext backups
# Always use GPG encryption
gpg --symmetric --cipher-algo AES256 secrets-backup.json
```

---

## Environment Variable Management

### Export Secrets as Environment Variables

```bash
# Create shell script from Vaultwarden folder
bash infrastructure-ops/scripts/vaultwarden/bw-secret-get.sh \
  --folder "Environment - Production" \
  --format shell > ~/.secrets-production.sh

# Source in shell
source ~/.secrets-production.sh

# Now all secrets are available as environment variables
echo $OPENAI_API_KEY
```

### Secure Source File

```bash
# Make executable by owner only
chmod 700 ~/.secrets-production.sh

# Add to .gitignore globally
echo ".secrets-*.sh" >> ~/.gitignore_global
```

---

## Commands Available

- `/secret-get <name>` - Retrieve secret from vault
- `/vaultwarden-backup` - Backup vault including secrets

---

## Troubleshooting

### Secret Not Found

```bash
# List all secrets
bw list items --session "$BW_SESSION" | jq '.[] | .name'

# Search for secret
bw list items --search "partial name" --session "$BW_SESSION"
```

### Permission Denied

```bash
# Verify session is valid
bw status | jq .status

# Re-unlock if needed
export BW_SESSION=$(bw unlock --raw)
```

### Secret Value Corrupted

```bash
# Check item details
bw get item "Secret Name" --session "$BW_SESSION" | jq

# Restore from backup if needed
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --restore
```

---

## Integration Examples

### Terraform

```hcl
# Use Bitwarden provider
terraform {
  required_providers {
    bitwarden = {
      source  = "maxlaverse/bitwarden"
      version = "~> 0.7.0"
    }
  }
}

provider "bitwarden" {
  server   = "https://bitwarden.harbor.fyi"
  email    = var.bw_email
  password = var.bw_password
}

# Retrieve secret
data "bitwarden_item_login" "do_token" {
  search = "DigitalOcean Token"
}

resource "digitalocean_droplet" "web" {
  # Use secret
  # data.bitwarden_item_login.do_token.password
}
```

### Ansible

```yaml
# Retrieve secret from Vaultwarden
- name: Get database password from Vaultwarden
  shell: |
    export BW_SESSION=$(bw unlock --raw --passwordenv BW_PASSWORD)
    bw get password "PostgreSQL Production" --session "$BW_SESSION"
  register: db_password
  no_log: true

- name: Configure database
  postgresql_db:
    name: myapp
    password: "{{ db_password.stdout }}"
```

---

## Related Documentation

- Toolkit Guide: `.claude/VAULTWARDEN-TOOLKIT.md`
- Backup Skill: `.claude/skills/vaultwarden-backup/skill.md`
- Official Docs: https://bitwarden.com/help/cli/

---

**Version:** 1.0
**Last Updated:** 2025-12-06
**Maintainer:** AI Enablement Academy Infrastructure Team
