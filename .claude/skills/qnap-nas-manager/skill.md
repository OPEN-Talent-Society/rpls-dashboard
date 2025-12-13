# QNAP NAS Manager Skill

**Purpose:** Manage QNAP NAS (Natasha) for storage, backups, snapshots, and system health monitoring.

**NAS Details:**
- Hostname: Natasha
- IP: 192.168.50.251
- OS: QTS (Linux 5.10.60-qnap)
- Storage: 26.7TB total, 8.4TB used (32%)
- Root FS: 400MB (85% full - needs cleanup)

---

## Prerequisites

**Required Environment Variables:**
```bash
QNAP_NAS_IP=192.168.50.251
QNAP_NAS_SSH_PORT=22
QNAP_NAS_USER=admin
QNAP_NAS_PASSWORD=NEMSZERETEMnarancssarga1963takacs
QNAP_NAS_WEB_PORT=8081
QNAP_NAS_BACKUP_PATH=/mnt/harbor-nas/
```

**Add to `.env`:**
```bash
echo "QNAP_NAS_IP=192.168.50.251" >> .env
echo "QNAP_NAS_SSH_PORT=22" >> .env
echo "QNAP_NAS_USER=admin" >> .env
```

**Note:** Password stored in `.env` (gitignored). Consider SSH key authentication for production.

---

## Core Capabilities

### 1. Storage Management
- Check disk usage and health
- Monitor volume status
- List large files and directories
- Clean old backups and temp files

### 2. Backup Operations
- Coordinate backups from Docker VM, Proxmox
- Verify backup integrity
- Clean old backups (retention policy)
- Monitor backup success/failure

### 3. Snapshot Management
- Create NAS snapshots for data protection
- List existing snapshots
- Restore from snapshot
- Automated snapshot scheduling

### 4. System Health
- Monitor disk SMART status
- Check CPU, memory, temperature
- Review system logs
- Monitor QPKG (app) status

### 5. Docker Container Management
- List running containers (Container Station)
- Monitor Plex Media Server
- Container resource usage
- Container logs

---

## Usage Examples

### Check Storage Health
```bash
bash infrastructure-ops/scripts/hardware/qnap-storage-check.sh
```

**Output:**
```
QNAP NAS Storage Report (Natasha)
=================================
Hostname: Natasha
Uptime: 45 days, 12 hours

Storage:
  Total: 26.7 TB
  Used: 8.4 TB (32%)
  Available: 18.3 TB

Root Filesystem:
  Total: 400 MB
  Used: 338.6 MB (85%) ⚠️ WARNING: High usage
  Available: 61.4 MB

Disk Health:
  /dev/sda: PASSED (SMART status: OK)
  /dev/sdb: PASSED (SMART status: OK)
  /dev/sdc: PASSED (SMART status: OK)
  /dev/sdd: PASSED (SMART status: OK)

Recommendations:
  - Clean root filesystem (85% full)
  - Review /tmp for large temp files
  - Check Container Station overlay filesystems
```

### Clean NAS Storage
```bash
bash infrastructure-ops/scripts/hardware/qnap-cleanup.sh --dry-run
```

**Actions:**
- Clean `/tmp` directory (temp files)
- Remove old Docker overlay layers
- Clean QPKG logs older than 30 days
- Remove old backup files based on retention policy
- Clean browser cache and system temp files

**Retention Policy:**
- Daily backups: Keep 7 days
- Weekly backups: Keep 4 weeks
- Monthly backups: Keep 12 months

### Create Snapshot
```bash
bash infrastructure-ops/scripts/hardware/qnap-snapshot-create.sh \
  --name "pre-cleanup-$(date +%Y%m%d)" \
  --volume DataVol1
```

**Output:**
```
Creating snapshot: pre-cleanup-20251206
Volume: DataVol1
Time: 2025-12-06 14:30:00

Snapshot created successfully.
Snapshot ID: snap_20251206_143000
Size: 8.4 TB (snapshot diff: 0 MB)
```

### Verify Backup Integrity
```bash
bash infrastructure-ops/scripts/hardware/qnap-backup-verify.sh \
  --path /mnt/harbor-nas/docker-backups/
```

**Output:**
```
Verifying backups in: /mnt/harbor-nas/docker-backups/

docker-backup-20251206.tar.gz ... OK (md5 verified)
docker-backup-20251205.tar.gz ... OK (md5 verified)
docker-backup-20251204.tar.gz ... OK (md5 verified)

Total: 3 backups
Verified: 3
Failed: 0
```

---

## QNAP CLI Commands Reference

### System Information
```bash
# Get system info
ssh admin@192.168.50.251 "uname -a"
ssh admin@192.168.50.251 "cat /etc/platform"

# Uptime
ssh admin@192.168.50.251 "uptime"

# System resources
ssh admin@192.168.50.251 "free -h"
ssh admin@192.168.50.251 "df -h"
```

### Storage & Volumes
```bash
# List volumes
ssh admin@192.168.50.251 "lvscan"
ssh admin@192.168.50.251 "vgdisplay"
ssh admin@192.168.50.251 "pvdisplay"

# Disk health (SMART)
ssh admin@192.168.50.251 "smartctl -a /dev/sda"

# Large files (top 20)
ssh admin@192.168.50.251 "du -ah /share | sort -rh | head -20"
```

### QPKG Management
```bash
# List installed packages
ssh admin@192.168.50.251 "qpkg_cli -l"

# Get package info
ssh admin@192.168.50.251 "qpkg_cli -m Plex"

# Enable/disable package
ssh admin@192.168.50.251 "qpkg_service enable Plex"
ssh admin@192.168.50.251 "qpkg_service disable Plex"
```

### Docker Commands
```bash
# List containers (if Docker in PATH)
ssh admin@192.168.50.251 "docker ps -a"

# Container stats
ssh admin@192.168.50.251 "docker stats --no-stream"

# Container logs
ssh admin@192.168.50.251 "docker logs <container_id>"
```

**Note:** Docker may not be in default SSH PATH. Add to PATH or use full path:
```bash
export PATH=$PATH:/share/CACHEDEV1_DATA/.qpkg/container-station/bin
```

### Snapshot Commands
```bash
# List snapshots (via QNAP CLI)
ssh admin@192.168.50.251 "/sbin/getcfg SNAPSHOT"

# Create snapshot (Web UI recommended, or API)
# CLI snapshot management is limited - use API instead
```

---

## QNAP API Access

QNAP provides REST API for advanced operations.

### Authentication
```bash
# Get session ID (SID)
curl -k "https://192.168.50.251:8081/cgi-bin/authLogin.cgi?user=admin&pwd=PASSWORD"

# Returns: <QDocRoot><authPassed>1</authPassed><authSid>SID_HERE</authSid></QDocRoot>
```

### Storage Info API
```bash
# Get volume info
curl -k "https://192.168.50.251:8081/cgi-bin/disk/disk_manage.cgi?store=volume_get&sid=SID"

# Get disk SMART status
curl -k "https://192.168.50.251:8081/cgi-bin/disk/disk_manage.cgi?func=get_smart_status&sid=SID"

# Get folder size
curl -k "https://192.168.50.251:8081/cgi-bin/filemanager/utilRequest.cgi?func=stat&path=/share/backups&sid=SID"
```

### Snapshot API
```bash
# List snapshots
curl -k "https://192.168.50.251:8081/cgi-bin/snapshot/snapshot.cgi?func=get_snapshot_list&sid=SID"

# Create snapshot
curl -k "https://192.168.50.251:8081/cgi-bin/snapshot/snapshot.cgi?func=create_snapshot&volume=DataVol1&name=backup_20251206&sid=SID"

# Delete snapshot
curl -k "https://192.168.50.251:8081/cgi-bin/snapshot/snapshot.cgi?func=delete_snapshot&snapshot_id=SNAPSHOT_ID&sid=SID"
```

---

## Backup Coordination

### Docker VM → NAS Backup Flow
```bash
# 1. Docker VM creates backup
ssh root@192.168.50.149 "docker-compose down && tar -czf /tmp/docker-backup.tar.gz /var/lib/docker"

# 2. Transfer to NAS
scp root@192.168.50.149:/tmp/docker-backup.tar.gz admin@192.168.50.251:/share/backups/docker/

# 3. Verify on NAS
ssh admin@192.168.50.251 "ls -lh /share/backups/docker/docker-backup.tar.gz"
```

### Proxmox → NAS Backup Flow
```bash
# Proxmox VZDump to NAS (NFS/SMB mount)
pveum user list
vzdump <vmid> --storage nas-backup --mode snapshot
```

---

## Storage Cleanup Strategy

### Root Filesystem (85% full)
**Target:** Reduce to <70%

**Cleanup Actions:**
1. `/tmp` - Remove temp files older than 7 days
2. `/var/log` - Rotate logs, compress old logs
3. Container Station overlays - Prune unused Docker layers
4. QPKG logs - Remove logs older than 30 days
5. Browser cache - Clear web UI cache

```bash
# Safe cleanup script
bash infrastructure-ops/scripts/hardware/qnap-cleanup.sh --root-fs
```

### Data Volume (32% full)
**Target:** Maintain <80%

**Cleanup Actions:**
1. Old backups - Apply retention policy
2. Plex cache - Clear old thumbnails, transcodes
3. Duplicate files - Scan for duplicates
4. Temp downloads - Remove incomplete downloads

```bash
# Data volume cleanup
bash infrastructure-ops/scripts/hardware/qnap-cleanup.sh --data-volume
```

---

## Monitoring Integration

### Uptime Kuma Checks
```bash
Monitor Name: QNAP NAS (Local)
Type: HTTP(s)
URL: https://192.168.50.251:8081
Interval: 120 seconds

Monitor Name: QNAP NAS (External)
Type: HTTP(s)
URL: https://nas.harbor.fyi
Interval: 300 seconds
```

### Alerts
- Disk usage > 80% (WARNING)
- Disk usage > 90% (CRITICAL)
- Root FS > 90% (CRITICAL)
- SMART status failed (CRITICAL)
- NAS offline > 5 minutes (CRITICAL)

---

## Security Best Practices

### Access Control
- ✅ Change default admin password (DONE)
- ⚠️ Enable SSH key authentication (TODO)
- ✅ Firewall: Block external access except via NPM
- ⚠️ Enable 2FA for admin account (RECOMMENDED)

### Backup Security
- ✅ Encrypt backups at rest (use QNAP encryption)
- ✅ Off-site backup copy (cloud or secondary NAS)
- ✅ Test restore quarterly

### Updates
- Check firmware updates monthly
- Enable auto-security updates
- Test updates on snapshot before applying

---

## Troubleshooting

### High Root Filesystem Usage
```bash
# Find large files in root
ssh admin@192.168.50.251 "du -ah / --max-depth=3 | sort -rh | head -20"

# Check tmp directory
ssh admin@192.168.50.251 "du -sh /tmp/*"

# Container overlays
ssh admin@192.168.50.251 "du -sh /share/CACHEDEV1_DATA/.qpkg/container-station/container/overlay2/*"
```

### NAS Not Responding
```bash
# Ping test
ping -c 5 192.168.50.251

# Check if SSH is up
nc -zv 192.168.50.251 22

# Check web UI
curl -Ik https://192.168.50.251:8081
```

### Backup Failures
```bash
# Check NAS logs
ssh admin@192.168.50.251 "tail -100 /var/log/messages"

# Check disk space
ssh admin@192.168.50.251 "df -h"

# Verify permissions
ssh admin@192.168.50.251 "ls -la /share/backups/"
```

---

## Related Skills

- **asus-router-manager** - Router configuration
- **nas-backup-coordinator** - Backup orchestration
- **docker-health-monitor** - Docker container monitoring

---

## Scripts Location

All NAS management scripts are in:
```
infrastructure-ops/scripts/hardware/
├── qnap-storage-check.sh       # Check storage health
├── qnap-cleanup.sh             # Clean old files
├── qnap-snapshot-create.sh     # Create snapshots
└── qnap-backup-verify.sh       # Verify backup integrity
```

---

## Automation Hooks

### Daily Health Check
```bash
# Hook: .claude/hooks/nas-health-check-daily.sh
# Runs: Every day 6 AM
# Action: Check storage, SMART status, alert if issues
```

### Monthly Cleanup
```bash
# Hook: .claude/hooks/nas-cleanup-monthly.sh
# Runs: First day of month, 2 AM
# Action: Clean old backups, logs, temp files
```

---

**Status:** Ready for production use
**Last Updated:** 2025-12-06
**Maintainer:** Claude Code Infrastructure Team
