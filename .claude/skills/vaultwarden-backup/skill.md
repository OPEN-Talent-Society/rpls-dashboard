---
triggers:
  - backup vaultwarden
  - vault backup
  - backup secrets
  - vaultwarden restore
  - encrypted backup
  - disaster recovery
  - vault export
---

# Vaultwarden Backup

**Category:** Infrastructure Operations
**Description:** Backup Vaultwarden vault data with encryption, compression, and automated scheduling for disaster recovery.

---

## Overview

This skill provides comprehensive backup and recovery for Vaultwarden vault at `bitwarden.harbor.fyi`. It handles:

- Encrypted vault exports (JSON)
- Database backup (SQLite)
- Attachments and file backup
- Automated daily backups
- Offsite storage to NAS
- Recovery and restoration procedures

---

## Prerequisites

### Required Tools

```bash
# Bitwarden CLI
brew install bitwarden-cli

# GPG for encryption
brew install gnupg

# rsync for offsite backups
brew install rsync

# Configure server
bw config server https://bitwarden.harbor.fyi
```

### Backup Locations

```bash
# Local backup directory
mkdir -p ~/Documents/backups/vaultwarden

# NAS backup location (configure in script)
# /Volumes/NAS/backups/vaultwarden/
# or
# rsync://nas.harbor.fyi/backups/vaultwarden/
```

---

## Scripts Available

Located in `infrastructure-ops/scripts/vaultwarden/`:

1. **bw-vault-backup.sh** - Backup Vaultwarden database and vault

---

## Usage

### Manual Backup

```bash
# Basic backup (encrypted JSON export)
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh

# Full backup (database + attachments + vault)
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --full

# Backup to specific location
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --output ~/custom/path

# Backup and sync to NAS
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --full --sync-nas
```

### Automated Daily Backup

The daily backup hook runs automatically:

```bash
# Check hook status
ls -l /Users/adamkovacs/Documents/codebuild/.claude/hooks/vaultwarden-backup-daily.sh

# Manually trigger daily backup
bash /Users/adamkovacs/Documents/codebuild/.claude/hooks/vaultwarden-backup-daily.sh

# View backup history
ls -lh ~/Documents/backups/vaultwarden/
```

---

## Backup Types

### 1. Vault Export (JSON)

**What it includes:**
- All vault items (logins, notes, cards, identities)
- Folders and collections
- Item metadata and custom fields
- **Does NOT include:** Attachments, file uploads

**Format:** Encrypted JSON

```bash
# Create vault export
export BW_SESSION=$(bw unlock --raw)
bw export --format json --session "$BW_SESSION" > vault-export.json

# Encrypt immediately
gpg --symmetric --cipher-algo AES256 vault-export.json
rm vault-export.json
```

### 2. Database Backup (SQLite)

**What it includes:**
- Complete Vaultwarden database
- User accounts, ciphers, attachments metadata
- All configuration and settings

**Location:** `/opt/vaultwarden/data/db.sqlite3` (on server)

```bash
# SSH to Vaultwarden server
ssh admin@bitwarden.harbor.fyi

# Create database backup
docker exec vaultwarden sqlite3 /data/db.sqlite3 ".backup /data/backup-$(date +%Y%m%d).sqlite3"

# Download backup
scp admin@bitwarden.harbor.fyi:/opt/vaultwarden/data/backup-*.sqlite3 ~/Documents/backups/vaultwarden/
```

### 3. Attachments Backup

**What it includes:**
- File attachments uploaded to vault items
- Images, documents, archives

**Location:** `/opt/vaultwarden/data/attachments/` (on server)

```bash
# Sync attachments to local
rsync -avz --progress \
  admin@bitwarden.harbor.fyi:/opt/vaultwarden/data/attachments/ \
  ~/Documents/backups/vaultwarden/attachments/
```

---

## Backup Schedule

### Automated Backups

| Frequency | Type | Retention | Location |
|-----------|------|-----------|----------|
| **Daily** | Vault JSON | 30 days | Local + NAS |
| **Weekly** | Full (DB + attachments) | 12 weeks | NAS |
| **Monthly** | Full + offsite | 12 months | NAS + Cloud |

### Retention Policy

```bash
# Daily backups: Keep 30 days
find ~/Documents/backups/vaultwarden/ -name "vault-*.json.gpg" -mtime +30 -delete

# Weekly backups: Keep 12 weeks
find ~/Documents/backups/vaultwarden/ -name "full-*.tar.gz.gpg" -mtime +84 -delete

# Monthly backups: Keep 12 months
# Manual cleanup after 1 year
```

---

## Restoration Procedures

### Restore Vault Items

```bash
# 1. Decrypt backup
cd ~/Documents/backups/vaultwarden
gpg --decrypt vault-backup-20251206.json.gpg > vault-restore.json

# 2. Import to Vaultwarden
export BW_SESSION=$(bw unlock --raw)
bw import bitwardenjson vault-restore.json --session "$BW_SESSION"

# 3. Sync
bw sync --session "$BW_SESSION"

# 4. Verify
bw list items --session "$BW_SESSION" | jq length

# 5. Cleanup
rm vault-restore.json
```

### Restore Full Database

```bash
# 1. Stop Vaultwarden container
ssh admin@bitwarden.harbor.fyi "cd /opt/vaultwarden && docker compose down"

# 2. Backup current database (safety)
ssh admin@bitwarden.harbor.fyi "cp /opt/vaultwarden/data/db.sqlite3 /opt/vaultwarden/data/db.sqlite3.old"

# 3. Upload backup database
scp ~/Documents/backups/vaultwarden/backup-20251206.sqlite3 \
  admin@bitwarden.harbor.fyi:/opt/vaultwarden/data/db.sqlite3

# 4. Restore ownership and permissions
ssh admin@bitwarden.harbor.fyi "chown vaultwarden:vaultwarden /opt/vaultwarden/data/db.sqlite3"

# 5. Start Vaultwarden
ssh admin@bitwarden.harbor.fyi "cd /opt/vaultwarden && docker compose up -d"

# 6. Verify service
curl -I https://bitwarden.harbor.fyi
```

### Restore Attachments

```bash
# 1. Stop Vaultwarden
ssh admin@bitwarden.harbor.fyi "cd /opt/vaultwarden && docker compose down"

# 2. Sync attachments from backup
rsync -avz --progress \
  ~/Documents/backups/vaultwarden/attachments/ \
  admin@bitwarden.harbor.fyi:/opt/vaultwarden/data/attachments/

# 3. Fix permissions
ssh admin@bitwarden.harbor.fyi "chown -R vaultwarden:vaultwarden /opt/vaultwarden/data/attachments/"

# 4. Start Vaultwarden
ssh admin@bitwarden.harbor.fyi "cd /opt/vaultwarden && docker compose up -d"
```

---

## Disaster Recovery

### Complete System Restore

**Scenario:** Vaultwarden server completely lost

```bash
# 1. Deploy new Vaultwarden instance
# (Follow infrastructure-ops/homelab setup)

# 2. Restore database
scp ~/Documents/backups/vaultwarden/backup-latest.sqlite3 \
  admin@new-bitwarden.harbor.fyi:/opt/vaultwarden/data/db.sqlite3

# 3. Restore attachments
rsync -avz ~/Documents/backups/vaultwarden/attachments/ \
  admin@new-bitwarden.harbor.fyi:/opt/vaultwarden/data/attachments/

# 4. Configure environment
ssh admin@new-bitwarden.harbor.fyi
cd /opt/vaultwarden
nano docker-compose.yml
# Set DOMAIN, ADMIN_TOKEN, etc.

# 5. Start service
docker compose up -d

# 6. Verify and test
curl -I https://bitwarden.harbor.fyi
bw login --apikey
export BW_SESSION=$(bw unlock --raw)
bw list items --session "$BW_SESSION"
```

---

## Backup Verification

### Weekly Verification

```bash
# Test backup integrity
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --verify

# This checks:
# 1. Backup file exists and is recent
# 2. GPG decryption works
# 3. JSON is valid and parseable
# 4. Expected item count matches
```

### Manual Verification

```bash
# 1. Decrypt test
gpg --decrypt vault-backup-latest.json.gpg > /tmp/test.json

# 2. Validate JSON
jq . /tmp/test.json > /dev/null && echo "Valid JSON" || echo "Invalid JSON"

# 3. Check item count
jq '.items | length' /tmp/test.json

# 4. Cleanup
rm /tmp/test.json
```

---

## Encryption Details

### GPG Symmetric Encryption

```bash
# Encryption (AES-256)
gpg --symmetric --cipher-algo AES256 \
  --compress-algo zlib \
  --output vault-backup.json.gpg \
  vault-backup.json

# Decryption
gpg --decrypt vault-backup.json.gpg > vault-backup.json
```

### Passphrase Management

**Store GPG passphrase securely:**

```bash
# Option 1: In macOS Keychain
security add-generic-password \
  -s "Vaultwarden Backup" \
  -a "$USER" \
  -w "your-strong-passphrase"

# Retrieve in script
PASSPHRASE=$(security find-generic-password -s "Vaultwarden Backup" -w)

# Option 2: In separate password manager (1Password, etc.)

# Option 3: Physical safe (for long-term storage)
```

---

## Offsite Backup

### NAS Sync

```bash
# Automated sync to NAS
bash infrastructure-ops/scripts/vaultwarden/bw-vault-backup.sh --sync-nas

# This runs:
# rsync -avz --delete \
#   ~/Documents/backups/vaultwarden/ \
#   /Volumes/NAS/backups/vaultwarden/
```

### Cloud Storage (Optional)

```bash
# Sync to cloud (encrypted backups only)
rclone sync \
  ~/Documents/backups/vaultwarden/ \
  remote:backups/vaultwarden/ \
  --include "*.gpg" \
  --transfers 4 \
  --checkers 8
```

---

## Monitoring and Alerts

### Backup Health Check

```bash
# Check last backup age
LAST_BACKUP=$(ls -t ~/Documents/backups/vaultwarden/vault-*.json.gpg | head -1)
BACKUP_AGE=$(( ($(date +%s) - $(stat -f %m "$LAST_BACKUP")) / 86400 ))

if [ $BACKUP_AGE -gt 1 ]; then
  echo "Warning: Last backup is $BACKUP_AGE days old"
  # Send alert via Brevo or Slack
fi
```

### Storage Usage

```bash
# Check backup directory size
du -sh ~/Documents/backups/vaultwarden/

# Check NAS storage
du -sh /Volumes/NAS/backups/vaultwarden/

# Alert if over threshold (e.g., 10GB)
SIZE=$(du -s ~/Documents/backups/vaultwarden/ | awk '{print $1}')
if [ $SIZE -gt 10485760 ]; then
  echo "Warning: Backup directory exceeds 10GB"
fi
```

---

## Commands Available

- `/vaultwarden-backup` - Run manual backup with options
- `/vaultwarden-backup --verify` - Test backup integrity

---

## Troubleshooting

### Backup Fails

```bash
# Check session is valid
bw status | jq .status

# Re-unlock
export BW_SESSION=$(bw unlock --raw)

# Check disk space
df -h ~/Documents/backups/

# Check permissions
ls -la ~/Documents/backups/vaultwarden/
```

### GPG Decryption Fails

```bash
# Verify GPG is installed
gpg --version

# Test decryption with verbose output
gpg --decrypt --verbose vault-backup.json.gpg

# Check passphrase is correct
# Try manual decryption
```

### NAS Sync Fails

```bash
# Check NAS is mounted
mount | grep NAS

# Test connectivity
ping nas.harbor.fyi

# Check rsync permissions
ssh admin@nas.harbor.fyi "ls -la /backups/vaultwarden/"
```

---

## Security Best Practices

1. **Always encrypt backups** - Never store vault data in plaintext
2. **Use strong passphrase** - 20+ characters, mixed case, symbols
3. **Store passphrase separately** - Not in Vaultwarden itself
4. **Test restores regularly** - Monthly disaster recovery drills
5. **Offsite backups** - 3-2-1 rule (3 copies, 2 media, 1 offsite)
6. **Audit access** - Review who can access backup storage

---

## Related Documentation

- SSH Manager Skill: `.claude/skills/vaultwarden-ssh-manager/skill.md`
- Secrets Manager Skill: `.claude/skills/vaultwarden-secrets-manager/skill.md`
- Toolkit Guide: `.claude/VAULTWARDEN-TOOLKIT.md`

---

**Version:** 1.0
**Last Updated:** 2025-12-06
**Maintainer:** AI Enablement Academy Infrastructure Team
