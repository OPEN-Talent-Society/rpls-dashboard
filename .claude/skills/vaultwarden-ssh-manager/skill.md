---
triggers:
  - manage ssh keys
  - import ssh keys
  - load ssh keys
  - rotate ssh keys
  - vaultwarden ssh
  - ssh key lifecycle
  - ssh agent management
---

# Vaultwarden SSH Manager

**Category:** Infrastructure Operations
**Description:** Complete SSH key lifecycle management via Vaultwarden - import, load, rotate, and manage SSH keys stored in the self-hosted Bitwarden instance.

---

## Overview

This skill provides comprehensive SSH key management using Vaultwarden at `bitwarden.harbor.fyi`. It handles:

- SSH key import from `~/.ssh/` to Vaultwarden
- Automated key loading into ssh-agent
- Key rotation with automated deployment
- Key metadata tracking and organization
- Emergency backup and recovery

---

## Prerequisites

### Required Tools

```bash
# Bitwarden CLI
brew install bitwarden-cli

# Verify installation
bw --version

# Configure server
bw config server https://bitwarden.harbor.fyi
```

### Environment Setup

```bash
# Required environment variables (store in ~/.zshrc.local or .env)
export BW_CLIENTID="user.xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export BW_CLIENTSECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**To generate API credentials:**
1. Visit `https://bitwarden.harbor.fyi/#/settings/security/security-keys`
2. Create new API key
3. Store securely in environment variables

### Authentication

```bash
# Login with API key
bw login --apikey

# Unlock vault and get session token
export BW_SESSION=$(bw unlock --raw)

# Verify session
bw status | jq .status
```

---

## Scripts Available

All scripts are located in `infrastructure-ops/scripts/vaultwarden/`:

1. **bw-ssh-import-all.sh** - Import all SSH keys from `~/.ssh/`
2. **bw-ssh-load.sh** - Load keys into ssh-agent from Vaultwarden
3. **bw-ssh-rotate.sh** - Rotate SSH keys automatically

---

## Usage

### 1. Initial Import of SSH Keys

```bash
# Import all SSH keys from ~/.ssh/ to Vaultwarden
bash infrastructure-ops/scripts/vaultwarden/bw-ssh-import-all.sh

# This creates the folder structure:
# - SSH Keys - Infrastructure
# - SSH Keys - Network Devices
# - SSH Keys - Cloud Services
# - SSH Keys - Archived
```

### 2. Daily Key Loading

```bash
# Load infrastructure keys into ssh-agent
bash infrastructure-ops/scripts/vaultwarden/bw-ssh-load.sh "SSH Keys - Infrastructure"

# Load cloud service keys
bash infrastructure-ops/scripts/vaultwarden/bw-ssh-load.sh "SSH Keys - Cloud Services"

# Load all keys
bash infrastructure-ops/scripts/vaultwarden/bw-ssh-load.sh

# Verify loaded keys
ssh-add -l
```

### 3. Key Rotation

```bash
# Rotate a specific key
bash infrastructure-ops/scripts/vaultwarden/bw-ssh-rotate.sh \
  "SSH - Proxmox Host" \
  root@proxmox.harbor.fyi \
  root@proxmox-backup.harbor.fyi

# This will:
# 1. Generate new Ed25519 key
# 2. Deploy to all specified servers
# 3. Test new key works
# 4. Archive old key in Vaultwarden
# 5. Create new item with updated key
```

---

## Folder Organization

Vaultwarden folders created:

| Folder | Purpose | Keys |
|--------|---------|------|
| **SSH Keys - Infrastructure** | Homelab servers, VMs, containers | Proxmox, Docker, LXC, Homelab |
| **SSH Keys - Network Devices** | Routers, switches, firewalls | ASUS Router |
| **SSH Keys - Cloud Services** | Cloud providers, SaaS platforms | Oracle Cloud, AI Enablement Academy |
| **SSH Keys - Archived** | Rotated/deprecated keys | Old router key, legacy RSA, test keys |

---

## Key Metadata Template

Each SSH key item includes:

**Name Format:** `SSH - [Service/Host] ([Algorithm])`

**Custom Fields:**
- `hostname`: Server FQDN or IP
- `username`: SSH username
- `port`: SSH port (default: 22)
- `key_type`: Ed25519, RSA 4096, etc.
- `created_date`: ISO format (YYYY-MM-DD)
- `last_rotated`: ISO format (YYYY-MM-DD)
- `rotation_schedule`: Days between rotations (90, 180, 365)
- `fingerprint_sha256`: SSH fingerprint
- `purpose`: Description of access
- `authorized_on`: Servers where key is deployed

**Notes Section:**
```
Purpose: Access to Proxmox VE hypervisor
Authorized Servers:
  - proxmox.harbor.fyi (192.168.1.100)

Rotation Schedule: Every 90 days
Last Rotated: 2025-12-06
Next Rotation: 2026-03-06
```

---

## Security Best Practices

### Key Types
- **Preferred:** Ed25519 (modern, secure, fast)
- **Acceptable:** RSA 4096+
- **Avoid:** RSA 2048 or lower, DSA, ECDSA

### Rotation Schedule
| Key Type | Frequency | Rationale |
|----------|-----------|-----------|
| Production Infrastructure | 90 days | High security |
| Cloud Automation | 180 days | Moderate risk |
| Network Devices | 180 days | Isolated network |
| Personal/Dev | 365 days | Low risk |

### SSH Agent Security
- Keys loaded with 8-hour timeout: `ssh-add -t 28800`
- Clear agent on logout: `ssh-add -D`
- Never forward agent to untrusted hosts

---

## Commands Available

Use these slash commands for quick access:

- `/vaultwarden-ssh-load` - Load SSH keys from Vaultwarden
- `/vaultwarden-backup` - Backup vault to NAS
- `/secret-get <name>` - Retrieve secret from vault

---

## Troubleshooting

### Session Expired

```bash
# Re-unlock vault
export BW_SESSION=$(bw unlock --raw)

# Or re-login
bw login --apikey
export BW_SESSION=$(bw unlock --raw)
```

### Key Not Loading

```bash
# Check key format (must be OpenSSH format)
head -n 1 ~/.ssh/keyname
# Should show: -----BEGIN OPENSSH PRIVATE KEY-----

# Convert legacy PEM format if needed
ssh-keygen -p -m RFC4716 -f ~/.ssh/keyname
```

### Cannot Connect to Vaultwarden

```bash
# Verify server configuration
bw config server https://bitwarden.harbor.fyi

# Test connectivity
curl -I https://bitwarden.harbor.fyi

# Check Docker container status
ssh admin@bitwarden.harbor.fyi "docker ps | grep vaultwarden"
```

---

## Emergency Recovery

### Restore from Encrypted Backup

```bash
# Navigate to backup location
cd ~/Documents/backups/ssh-keys

# Decrypt and extract
gpg --decrypt ssh-keys-backup-YYYYMMDD.tar.gz.gpg | tar xzf - -C /tmp/restore

# Copy keys to ~/.ssh/
cp /tmp/restore/*.key ~/.ssh/
chmod 600 ~/.ssh/*.key

# Load into ssh-agent
for key in ~/.ssh/*.key; do ssh-add "$key"; done
```

---

## Integration

### Shell Aliases

Add to `~/.zshrc`:

```bash
# Vaultwarden SSH shortcuts
alias bw-unlock='export BW_SESSION=$(bw unlock --raw)'
alias bw-lock='bw lock && unset BW_SESSION'
alias bw-ssh-infra='bash infrastructure-ops/scripts/vaultwarden/bw-ssh-load.sh "SSH Keys - Infrastructure"'
alias bw-ssh-cloud='bash infrastructure-ops/scripts/vaultwarden/bw-ssh-load.sh "SSH Keys - Cloud Services"'
alias bw-ssh-list='ssh-add -l'
alias bw-ssh-clear='ssh-add -D'
```

---

## Related Documentation

- Design Document: `infrastructure-ops/homelab/VAULTWARDEN-SSH-KEY-MANAGEMENT.md`
- Toolkit Guide: `.claude/VAULTWARDEN-TOOLKIT.md`
- Official Docs: https://bitwarden.com/help/ssh-agent/

---

**Version:** 1.0
**Last Updated:** 2025-12-06
**Maintainer:** AI Enablement Academy Infrastructure Team
