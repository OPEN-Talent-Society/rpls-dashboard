# Proxmox Backup & Restore Skill

Comprehensive backup and restore automation for Proxmox VE VMs and LXC containers.

## Environment

**Proxmox VE**: 192.168.50.10 (Tailscale: 100.103.83.62)
- 5 LXC containers to backup
- 4 VMs to backup
- Local storage: /var/lib/vz/dump
- Optional: Proxmox Backup Server (PBS) integration

## Core Capabilities

### 1. Manual Backups

#### Backup Single Container

```bash
# LXC container backup with snapshot mode
vzdump 100 \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --notes-template "{{guestname}} - Manual backup $(date +%Y-%m-%d)"

# VM backup with snapshot
vzdump 101 \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --notes-template "{{guestname}} - Manual backup $(date +%Y-%m-%d)"
```

#### Backup Multiple Containers/VMs

```bash
# Backup all LXC containers
vzdump 100 101 102 103 104 \
  --storage local \
  --mode snapshot \
  --compress zstd \
  --all 0

# Backup specific VMs
vzdump 201 202 203 204 \
  --storage local \
  --mode snapshot \
  --compress zstd
```

#### Backup with Metadata Change Detection (PBS)

```bash
# Optimize backups using metadata detection
vzdump 100 \
  --storage pbs-storage \
  --mode snapshot \
  --pbs-change-detection-mode metadata

# This reuses unchanged data chunks from previous backups
```

### 2. Automated Backup Jobs

#### Create Backup Job via CLI

```bash
# Create backup schedule (use web UI for easier configuration)
# Datacenter > Backup > Add

# Example configuration:
# - Schedule: Daily at 2:00 AM
# - Selection: All VMs/Containers
# - Storage: local
# - Mode: Snapshot
# - Compression: ZSTD
# - Retention: Keep last 7 daily, 4 weekly, 6 monthly
```

#### View Backup Jobs

```bash
# List backup jobs
pvesh get /cluster/backup

# Get specific job
pvesh get /cluster/backup/<jobid>

# View backup log
cat /var/log/pve/tasks/vzdump-*.log
```

### 3. Restore Operations

#### Restore LXC Container

```bash
# List available backups
ls -lh /var/lib/vz/dump/vzdump-lxc-*.tar.*

# Restore to new container ID
pct restore 600 /var/lib/vz/dump/vzdump-lxc-100-2025_12_06-02_00_00.tar.zst \
  --storage local-lvm

# Restore with different storage
pct restore 600 /backup.tar.zst \
  --storage nvme-storage \
  --rootfs nvme-storage:8

# Restore with different network config
pct restore 600 /backup.tar.zst \
  --storage local-lvm \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.50.200/24,gw=192.168.50.1
```

#### Restore VM

```bash
# List VM backups
ls -lh /var/lib/vz/dump/vzdump-qemu-*.vma.*

# Restore VM
qmrestore /var/lib/vz/dump/vzdump-qemu-101-2025_12_06-02_00_00.vma.zst 601 \
  --storage local-lvm

# Restore with custom configuration
qmrestore /backup.vma 601 \
  --storage local-lvm \
  --cores 4 \
  --memory 8192
```

#### Restore from Stdin (Pipe)

```bash
# Backup and restore in one operation (for migration)
vzdump 100 --stdout | ssh remote-host "pct restore 600 - --storage local-lvm"

# Restore from compressed archive
zcat /backup.tar.gz | pct restore 600 - --storage local-lvm
```

### 4. Backup to Remote Storage

#### NFS Mount for Backups

```bash
# Add NFS storage
pvesm add nfs backup-nas \
  --server 192.168.50.20 \
  --export /mnt/backups/proxmox \
  --content backup

# Backup to NFS
vzdump 100 --storage backup-nas --mode snapshot
```

#### SSH/SCP to Remote Server

```bash
# Backup and transfer to remote server
vzdump 100 --stdout | ssh user@backup-server "cat > /backups/container-100-$(date +%Y%m%d).tar"

# Compressed transfer
vzdump 100 --stdout | gzip | ssh user@backup-server "cat > /backups/container-100-$(date +%Y%m%d).tar.gz"
```

#### Proxmox Backup Server (PBS)

```bash
# Add PBS storage
pvesm add pbs pbs-storage \
  --server pbs.example.com \
  --datastore backups \
  --username admin@pbs \
  --password <token>

# Backup to PBS
vzdump 100 --storage pbs-storage --mode snapshot

# PBS provides deduplication and encryption
```

## Backup Strategies

### Daily Incremental Backups

```bash
# Automated daily backup script
#!/bin/bash
# /opt/scripts/daily-backup.sh

STORAGE="local"
MODE="snapshot"
COMPRESS="zstd"
DATE=$(date +%Y%m%d)

# Backup all containers
for CT in 100 101 102 103 104; do
  echo "Backing up container $CT..."
  vzdump "$CT" \
    --storage "$STORAGE" \
    --mode "$MODE" \
    --compress "$COMPRESS" \
    --notes-template "Daily backup $DATE"
done

# Backup all VMs
for VM in 201 202 203 204; do
  echo "Backing up VM $VM..."
  vzdump "$VM" \
    --storage "$STORAGE" \
    --mode "$MODE" \
    --compress "$COMPRESS" \
    --notes-template "Daily backup $DATE"
done

# Clean old backups (keep last 7 days)
find /var/lib/vz/dump/ -name "vzdump-*.tar.*" -mtime +7 -delete
find /var/lib/vz/dump/ -name "vzdump-*.vma.*" -mtime +7 -delete

echo "Backup completed at $(date)"
```

### Weekly Full Backups

```bash
#!/bin/bash
# /opt/scripts/weekly-backup.sh

# Run every Sunday at 1 AM
# 0 1 * * 0 /opt/scripts/weekly-backup.sh

STORAGE="backup-nas"  # Remote NFS storage
DATE=$(date +%Y%m%d)

# Full backup of all systems
vzdump --all 1 \
  --storage "$STORAGE" \
  --mode snapshot \
  --compress zstd \
  --notes-template "Weekly full backup $DATE"

# Verify backups
for backup in /mnt/pve/$STORAGE/dump/vzdump-*-$DATE-*.{tar,vma}.*; do
  if [ -f "$backup" ]; then
    echo "Verified: $backup ($(du -h "$backup" | cut -f1))"
  fi
done
```

### Pre-Update Snapshots

```bash
#!/bin/bash
# /opt/scripts/pre-update-snapshot.sh

CTID=$1
SNAPNAME="before-update-$(date +%Y%m%d-%H%M)"

if [ -z "$CTID" ]; then
  echo "Usage: $0 <container_id>"
  exit 1
fi

# Determine if VM or CT
if pct status "$CTID" &>/dev/null; then
  echo "Creating snapshot for LXC container $CTID..."
  pct snapshot "$CTID" "$SNAPNAME" --description "Snapshot before system update"
elif qm status "$CTID" &>/dev/null; then
  echo "Creating snapshot for VM $CTID..."
  qm snapshot "$CTID" "$SNAPNAME" --description "Snapshot before system update"
else
  echo "Error: Container/VM $CTID not found"
  exit 1
fi

echo "Snapshot created: $SNAPNAME"
echo "To rollback: pct rollback $CTID $SNAPNAME (or qm rollback $CTID $SNAPNAME)"
```

## Backup Retention Policy

### 3-2-1 Backup Strategy

1. **3 copies** of data: Production + 2 backups
2. **2 different media**: Local storage + NAS/PBS
3. **1 offsite copy**: Cloud or remote location

### Retention Schedule

```bash
# Daily backups: 7 days
# Weekly backups: 4 weeks
# Monthly backups: 6 months
# Yearly backups: 5 years

# Cleanup script
#!/bin/bash
BACKUP_DIR="/var/lib/vz/dump"

# Keep daily for 7 days
find "$BACKUP_DIR" -name "vzdump-*-daily-*" -mtime +7 -delete

# Keep weekly for 4 weeks
find "$BACKUP_DIR" -name "vzdump-*-weekly-*" -mtime +28 -delete

# Keep monthly for 6 months
find "$BACKUP_DIR" -name "vzdump-*-monthly-*" -mtime +180 -delete
```

## Harbor Homelab Backup Plan

### Critical Systems (Daily Backups)

```bash
# LXC Containers
100: Jellyfin      # Daily snapshot
101: qBittorrent   # Daily snapshot
102: Plex          # Daily snapshot
103: NPM           # Daily snapshot + config backup
104: Whisper       # Weekly snapshot

# VMs
201: Windows       # Weekly full backup
202: Docker VM     # Daily snapshot (critical!)
203: Home Assistant # Daily snapshot
204: Lubuntu       # Weekly snapshot
```

### Backup Schedule

```bash
# Cron jobs
# /etc/cron.d/proxmox-backups

# Daily backups at 2 AM
0 2 * * * root /opt/scripts/daily-backup.sh >> /var/log/proxmox-daily-backup.log 2>&1

# Weekly full backups Sunday 1 AM
0 1 * * 0 root /opt/scripts/weekly-backup.sh >> /var/log/proxmox-weekly-backup.log 2>&1

# Monthly cleanup first of month
0 3 1 * * root /opt/scripts/cleanup-old-backups.sh >> /var/log/proxmox-cleanup.log 2>&1
```

## Disaster Recovery Procedures

### Complete System Restore

```bash
# 1. Fresh Proxmox installation
# 2. Configure storage
# 3. Restore containers/VMs

# Restore Docker VM (most critical)
qmrestore /mnt/backup-nas/vzdump-qemu-202-*.vma.zst 202 --storage local-lvm

# Restore NPM (for network access)
pct restore 103 /mnt/backup-nas/vzdump-lxc-103-*.tar.zst --storage local-lvm

# Restore remaining systems
# ...
```

### Partial Restore (Single Service)

```bash
# Restore just configuration files from backup

# Mount backup
mkdir /mnt/restore
pct mount 100 /mnt/restore

# Copy specific files
cp -r /mnt/restore/etc/nginx /backup/nginx-config

# Unmount
pct unmount 100
```

## Backup Verification

```bash
#!/bin/bash
# /opt/scripts/verify-backups.sh

BACKUP_DIR="/var/lib/vz/dump"
TODAY=$(date +%Y_%m_%d)

# Check if today's backups exist
EXPECTED_BACKUPS=(100 101 102 103 202 203)

for ID in "${EXPECTED_BACKUPS[@]}"; do
  if ls "$BACKUP_DIR"/vzdump-*-"$ID"-"$TODAY"-* 1> /dev/null 2>&1; then
    echo "✓ Backup found for $ID"
  else
    echo "✗ MISSING backup for $ID"
    # Send alert
  fi
done

# Check backup sizes (detect corruption)
find "$BACKUP_DIR" -name "vzdump-*-$TODAY-*" -size -100M -exec echo "WARNING: Small backup: {}" \;
```

## Troubleshooting

### Backup Fails

```bash
# Check storage space
df -h /var/lib/vz

# Check vzdump log
tail -f /var/log/pve/tasks/vzdump-*.log

# Test snapshot capability
pct snapshot 100 test-snapshot
pct delsnapshot 100 test-snapshot

# Check permissions
ls -la /var/lib/vz/dump/
```

### Restore Fails

```bash
# Verify backup integrity
tar -tzf /backup.tar.zst > /dev/null

# Check available storage
pvesm status

# Manually extract and inspect
mkdir /tmp/restore-test
tar -xzf /backup.tar.zst -C /tmp/restore-test
ls -la /tmp/restore-test
```

## Integration Points

- **Cortex**: Log backup operations and restore procedures
- **NocoDB**: Track backup schedules and retention
- **AgentDB**: Store backup patterns and configurations
- **Monitoring**: Alert on backup failures

## Usage Examples

```bash
Skill({ skill: "proxmox-backup-restore" })

# Request: "Backup all containers to NAS"
# - Connects to NAS storage
# - Creates snapshots of all containers
# - Transfers to remote storage
# - Verifies backup integrity
# - Logs completion

# Request: "Restore Docker VM from yesterday's backup"
# - Finds most recent backup
# - Restores to new VM ID
# - Configures network
# - Starts VM
# - Verifies functionality

# Request: "Create pre-update snapshot of Jellyfin"
# - Creates named snapshot
# - Documents reason
# - Provides rollback command
```
