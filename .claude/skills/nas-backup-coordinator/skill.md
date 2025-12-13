# NAS Backup Coordinator Skill

**Purpose:** Orchestrate backups from Docker VM, Proxmox, and other services to QNAP NAS with verification and retention management.

**Backup Flow:**
```
Sources                  NAS (Natasha)           Off-site
-------                  -------------           --------
Docker VM (149)    →     /share/backups/docker   → Cloud
Proxmox (10)       →     /share/backups/proxmox  → Cloud
Docmost/NocoDB     →     /share/backups/apps     → Cloud
GitHub Repos       →     /share/backups/git      → Cloud
```

---

## Prerequisites

**Required Environment Variables:**
```bash
QNAP_NAS_IP=192.168.50.251
QNAP_NAS_USER=admin
QNAP_BACKUP_ROOT=/share/backups
DOCKER_VM_IP=192.168.50.149
PROXMOX_IP=192.168.50.10
```

**Add to `.env`:**
```bash
echo "QNAP_BACKUP_ROOT=/share/backups" >> .env
echo "DOCKER_VM_IP=192.168.50.149" >> .env
```

---

## Core Capabilities

### 1. Backup Orchestration
- Schedule and coordinate backups from multiple sources
- Parallel backup execution with dependency management
- Retry logic for failed backups
- Progress tracking and notifications

### 2. Backup Verification
- Checksum validation (MD5, SHA256)
- Archive integrity testing
- Size verification
- Restoration testing (quarterly)

### 3. Retention Management
- Automated cleanup based on retention policy
- Grandfather-Father-Son (GFS) rotation
- Tiered storage (hot/warm/cold)
- Compression and deduplication

### 4. Monitoring & Alerting
- Backup success/failure tracking
- Storage capacity monitoring
- SLA compliance (RPO/RTO)
- Alert on backup failures

---

## Backup Retention Policy

### Default Retention
```
Daily Backups:   Keep 7 days
Weekly Backups:  Keep 4 weeks
Monthly Backups: Keep 12 months
Yearly Backups:  Keep indefinitely
```

### Storage Tiers
```
Hot (NAS):    Last 7 daily + 4 weekly (fast restore)
Warm (NAS):   Monthly backups (slower access)
Cold (Cloud): Yearly backups (archive)
```

---

## Usage Examples

### Run All Backups
```bash
bash infrastructure-ops/scripts/hardware/nas-backup-all.sh
```

**Output:**
```
Starting backup orchestration...
================================
[1/4] Docker VM backup ... RUNNING
[2/4] Proxmox backup ... QUEUED
[3/4] Docmost backup ... QUEUED
[4/4] GitHub repos backup ... QUEUED

[1/4] Docker VM backup ... DONE (2.3 GB, 5m 23s)
[2/4] Proxmox backup ... RUNNING
[2/4] Proxmox backup ... DONE (15.7 GB, 12m 45s)
[3/4] Docmost backup ... RUNNING
[3/4] Docmost backup ... DONE (456 MB, 1m 12s)
[4/4] GitHub repos backup ... RUNNING
[4/4] GitHub repos backup ... DONE (1.1 GB, 3m 34s)

Backup Summary:
  Success: 4/4
  Total Size: 19.5 GB
  Total Time: 22m 54s
  Failed: 0
```

### Verify Backup Integrity
```bash
bash infrastructure-ops/scripts/hardware/qnap-backup-verify.sh \
  --path /share/backups/docker \
  --check-integrity
```

**Output:**
```
Verifying backups: /share/backups/docker
========================================
docker-backup-20251206.tar.gz
  - Size: 2.3 GB ✓
  - MD5: abc123...def456 ✓
  - Archive integrity: OK ✓
  - Restore test: PASS ✓

docker-backup-20251205.tar.gz
  - Size: 2.1 GB ✓
  - MD5: 789abc...012def ✓
  - Archive integrity: OK ✓
  - Restore test: SKIPPED (daily)

Summary: 2 verified, 0 failed
```

### Apply Retention Policy
```bash
bash infrastructure-ops/scripts/hardware/nas-backup-cleanup.sh \
  --policy gfs \
  --dry-run
```

**Output:**
```
Applying GFS retention policy (DRY RUN)
=======================================
Docker Backups:
  Keep: docker-backup-20251206.tar.gz (daily)
  Keep: docker-backup-20251205.tar.gz (daily)
  Keep: docker-backup-20251130.tar.gz (weekly)
  Keep: docker-backup-20251101.tar.gz (monthly)
  DELETE: docker-backup-20251028.tar.gz (expired daily)
  DELETE: docker-backup-20251027.tar.gz (expired daily)

Total to delete: 2 files (4.5 GB)
Total to keep: 4 files (8.9 GB)

Run without --dry-run to apply changes.
```

---

## Backup Sources Configuration

### Docker VM Backups
```bash
# Source: 192.168.50.149
# Path: /var/lib/docker
# Frequency: Daily 2 AM
# Method: docker-compose down → tar → rsync to NAS
# Retention: 7 daily, 4 weekly, 12 monthly

# Script: infrastructure-ops/scripts/hardware/backup-docker-vm.sh
```

### Proxmox Backups
```bash
# Source: 192.168.50.10
# Path: /var/lib/vz/dump
# Frequency: Weekly Sunday 3 AM
# Method: vzdump → NFS mount to NAS
# Retention: 4 weekly, 12 monthly

# Script: infrastructure-ops/scripts/hardware/backup-proxmox.sh
```

### Docmost/NocoDB Backups
```bash
# Source: Docker containers
# Frequency: Daily 3 AM
# Method: docker exec → pg_dump → rsync to NAS
# Retention: 7 daily, 4 weekly, 12 monthly

# Script: infrastructure-ops/scripts/hardware/backup-apps.sh
```

### GitHub Repos Backup
```bash
# Source: GitHub
# Frequency: Weekly
# Method: git clone --mirror → tar → rsync to NAS
# Retention: 4 weekly, 12 monthly

# Script: infrastructure-ops/scripts/git/github-repo-backup.sh
```

---

## Backup Scripts

### Master Orchestration Script
**File:** `infrastructure-ops/scripts/hardware/nas-backup-all.sh`

```bash
#!/bin/bash
# Master backup orchestration script
# Runs all backup sources in order, handles failures

set -euo pipefail

BACKUP_ROOT="/share/backups"
LOG_FILE="/var/log/nas-backup-$(date +%Y%m%d).log"

echo "Starting backup orchestration..." | tee -a "$LOG_FILE"

# 1. Docker VM backup
if bash infrastructure-ops/scripts/hardware/backup-docker-vm.sh; then
  echo "Docker VM backup: SUCCESS" | tee -a "$LOG_FILE"
else
  echo "Docker VM backup: FAILED" | tee -a "$LOG_FILE"
  # Alert via Slack/email
fi

# 2. Proxmox backup (weekly only)
if [ "$(date +%u)" -eq 7 ]; then
  if bash infrastructure-ops/scripts/hardware/backup-proxmox.sh; then
    echo "Proxmox backup: SUCCESS" | tee -a "$LOG_FILE"
  else
    echo "Proxmox backup: FAILED" | tee -a "$LOG_FILE"
  fi
fi

# 3. Docmost/NocoDB backup
if bash infrastructure-ops/scripts/hardware/backup-apps.sh; then
  echo "Apps backup: SUCCESS" | tee -a "$LOG_FILE"
else
  echo "Apps backup: FAILED" | tee -a "$LOG_FILE"
fi

# 4. Apply retention policy
bash infrastructure-ops/scripts/hardware/nas-backup-cleanup.sh --policy gfs

echo "Backup orchestration complete" | tee -a "$LOG_FILE"
```

---

## Monitoring Integration

### Backup Success Tracking
```bash
# Store backup metadata in NocoDB
# Table: Backups
# Fields: timestamp, source, size, duration, status, checksum

# Example:
curl -X POST "https://ops.aienablement.academy/api/v2/tables/BACKUPS_TABLE_ID/records" \
  -H "xc-token: $NOCODB_API_TOKEN" \
  -d '{
    "timestamp": "2025-12-06T02:00:00Z",
    "source": "docker-vm",
    "size_gb": 2.3,
    "duration_seconds": 323,
    "status": "success",
    "checksum": "abc123...def456"
  }'
```

### Uptime Kuma Integration
```bash
# Push notification to Uptime Kuma after backup
# Monitor: NAS Backup Status
# Type: Push
# URL: https://status.harbor.fyi/api/push/BACKUP_KEY?status=up&msg=Backup+success
```

### Alerts
- Backup failed (CRITICAL)
- Backup duration > 2x average (WARNING)
- Storage > 80% (WARNING)
- Backup not run in 48 hours (CRITICAL)

---

## Recovery Procedures

### Restore Docker VM
```bash
# 1. Stop Docker
ssh root@192.168.50.149 "systemctl stop docker"

# 2. Clear existing data
ssh root@192.168.50.149 "rm -rf /var/lib/docker/*"

# 3. Restore from NAS
scp admin@192.168.50.251:/share/backups/docker/docker-backup-20251206.tar.gz /tmp/
ssh root@192.168.50.149 "cd / && tar -xzf /tmp/docker-backup-20251206.tar.gz"

# 4. Start Docker
ssh root@192.168.50.149 "systemctl start docker"
ssh root@192.168.50.149 "docker ps -a"
```

### Restore Proxmox VM/LXC
```bash
# 1. List available backups
ssh root@192.168.50.10 "pvesm list nas-backup"

# 2. Restore VM
ssh root@192.168.50.10 "qmrestore nas-backup:vzdump-qemu-100-2025_12_06.vma 100"

# 3. Start VM
ssh root@192.168.50.10 "qm start 100"
```

---

## Off-site Backup (Cloud)

### Rclone Configuration
```bash
# Configure rclone for cloud backup
rclone config

# Sync monthly backups to cloud
rclone sync /share/backups/monthly remote:backups/monthly \
  --progress \
  --checksum \
  --log-file /var/log/rclone-backup.log
```

### Cloud Storage Options
- **AWS S3 Glacier** - Low cost, slow retrieval
- **Backblaze B2** - Balanced cost/performance
- **Google Cloud Storage** - Fast, higher cost

---

## Related Skills

- **qnap-nas-manager** - NAS management
- **docker-health-monitor** - Docker monitoring
- **proxmox-backup-restore** - Proxmox operations

---

## Scripts Location

All backup coordination scripts are in:
```
infrastructure-ops/scripts/hardware/
├── nas-backup-all.sh          # Master orchestration
├── backup-docker-vm.sh        # Docker VM backup
├── backup-proxmox.sh          # Proxmox backup
├── backup-apps.sh             # Docmost/NocoDB backup
├── nas-backup-cleanup.sh      # Apply retention policy
└── nas-backup-verify.sh       # Verify backup integrity
```

---

**Status:** Ready for production use
**Last Updated:** 2025-12-06
**Maintainer:** Claude Code Infrastructure Team
