---
triggers:
  - manage proxmox
  - create vm
  - create lxc container
  - proxmox backup
  - vm snapshot
  - container lifecycle
  - proxmox operations
---

# Proxmox VM & LXC Operations Skill

Comprehensive Proxmox VE management for VMs and LXC containers in the Harbor Homelab.

## Environment

**Proxmox VE**: 192.168.50.10 (Tailscale: 100.103.83.62)
- Hardware: AMD Ryzen 9 8945HS (16 cores), 64GB RAM
- **5 LXC Containers**: Jellyfin, qBittorrent, Plex, NPM, Whisper
- **4 VMs**: Windows, Docker Debian (192.168.50.149), Home Assistant, Lubuntu

## Core Capabilities

### 1. LXC Container Management

#### List Containers

```bash
# List all containers
pct list

# Get container status
pct status 100

# Show container config
pct config 100
```

#### Container Lifecycle

```bash
# Start container
pct start 100

# Stop container gracefully
pct stop 100

# Force stop container
pct stop 100 --timeout 10

# Restart container
pct reboot 100

# Enter container namespace
pct enter 100
```

#### Container Creation

```bash
# Create Ubuntu LXC container
pct create 200 local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst \
  --hostname new-container \
  --memory 2048 \
  --cores 2 \
  --net0 name=eth0,bridge=vmbr0,ip=192.168.50.200/24,gw=192.168.50.1 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --unprivileged 1 \
  --features nesting=1

# Start container
pct start 200
```

### 2. VM Management

#### List VMs

```bash
# List all VMs
qm list

# Get VM status
qm status 101

# Show VM config
qm config 101
```

#### VM Lifecycle

```bash
# Start VM
qm start 101

# Stop VM gracefully
qm stop 101

# Force stop VM
qm stop 101 --skiplock

# Restart VM
qm reboot 101

# Reset VM (hard reset)
qm reset 101

# Suspend VM
qm suspend 101

# Resume VM
qm resume 101
```

#### VM Console Access

```bash
# Open console
qm terminal 101

# Monitor console
qm monitor 101

# VNC access (from web UI)
# https://192.168.50.10:8006/?console=kvm&vmid=101&node=harbor
```

### 3. Backup & Restore

#### Manual Backups

```bash
# Backup LXC container
vzdump 100 --storage local --mode snapshot --compress zstd

# Backup VM with snapshot
vzdump 101 --storage local --mode snapshot --compress zstd

# Backup multiple containers/VMs
vzdump 100 101 102 --storage local

# Backup to remote storage
vzdump 100 --storage pbs-storage --mode snapshot
```

#### Scheduled Backups

```bash
# View backup jobs
pvesh get /cluster/backup

# Create backup job (via web UI recommended)
# Datacenter > Backup > Add
# - Schedule: Daily at 2 AM
# - Selection: All containers/VMs
# - Storage: local or PBS
# - Mode: Snapshot
# - Compression: ZSTD
# - Retention: 7 daily, 4 weekly
```

#### Restore Operations

```bash
# List available backups
pvesh get /nodes/harbor/storage/local/content --content backup

# Restore LXC container
pct restore 600 /mnt/backup/vzdump-lxc-100-2025_12_06-02_00_00.tar.zst --storage local-lvm

# Restore VM
qmrestore /mnt/backup/vzdump-qemu-101-2025_12_06-02_00_00.vma 601 --storage local-lvm

# Restore with different storage
qmrestore /backup.vma 601 --storage nvme-storage
```

### 4. Snapshot Management

#### LXC Snapshots

```bash
# Create snapshot
pct snapshot 100 before-update

# List snapshots
pct listsnapshot 100

# Rollback to snapshot
pct rollback 100 before-update

# Delete snapshot
pct delsnapshot 100 before-update
```

#### VM Snapshots

```bash
# Create snapshot
qm snapshot 101 before-update --description "Before system update"

# List snapshots
qm listsnapshot 101

# Rollback to snapshot
qm rollback 101 before-update

# Delete snapshot
qm delsnapshot 101 before-update
```

### 5. Resource Management

#### Container Resources

```bash
# Resize container disk
pct resize 100 rootfs +5G

# Update CPU allocation
pct set 100 --cores 4

# Update memory
pct set 100 --memory 4096

# Update swap
pct set 100 --swap 1024
```

#### VM Resources

```bash
# Resize VM disk
qm resize 101 scsi0 +10G

# Update CPU
qm set 101 --cores 4 --sockets 1

# Update memory
qm set 101 --memory 8192

# Add network interface
qm set 101 --net1 virtio,bridge=vmbr0
```

### 6. Mount Points & Storage

#### Add Mount Point to Container

```bash
# Create and mount directory
pct set 100 --mp0 /mnt/data,mp=/data,size=50G,backup=1

# Mount existing storage
pct set 100 --mp1 local-lvm:vm-100-disk-1,mp=/mnt/storage

# Enable backup for mount point
pct set 100 --mp0 local-lvm:vm-100-disk-0,mp=/data,backup=1
```

#### Manage VM Disks

```bash
# Add disk to VM
qm set 101 --scsi1 local-lvm:32

# Import external disk
qm importdisk 101 /path/to/disk.qcow2 local-lvm

# Attach imported disk
qm set 101 --scsi2 local-lvm:vm-101-disk-1
```

## Harbor Homelab Inventory

### LXC Containers

```bash
# 100: Jellyfin (Media Server)
pct status 100
pct config 100 | grep -E "memory|cores|rootfs"

# 101: qBittorrent (Download Manager)
pct status 101

# 102: Plex (Media Server)
pct status 102

# 103: NPM (Nginx Proxy Manager)
pct status 103

# 104: Whisper (Speech-to-Text)
pct status 104
```

### VMs

```bash
# 201: Windows VM
qm status 201
qm config 201

# 202: Docker Debian (192.168.50.149)
qm status 202
qm config 202 | grep -E "memory|cores|net"

# 203: Home Assistant
qm status 203

# 204: Lubuntu Desktop
qm status 204
```

## Proxmox API Usage

### Authentication

```bash
# Get ticket
pvesh create /access/ticket --username root@pam --password <password>

# Store token
export PVE_TICKET="PVE:root@pam:..."
export PVE_CSRF="..."
```

### API Examples

```bash
# List all nodes
pvesh get /nodes

# Get node status
pvesh get /nodes/harbor/status

# List VMs
pvesh get /nodes/harbor/qemu

# List containers
pvesh get /nodes/harbor/lxc

# Get container config
pvesh get /nodes/harbor/lxc/100/config

# Start container via API
pvesh create /nodes/harbor/lxc/100/status/start

# Create snapshot via API
pvesh create /nodes/harbor/lxc/100/snapshot --snapname backup-$(date +%Y%m%d)
```

## Best Practices (2025)

### Pre-Operation Snapshots

Always create snapshots before major changes:

```bash
# Before updates
pct snapshot 100 before-update-$(date +%Y%m%d)
qm snapshot 101 before-update-$(date +%Y%m%d)

# Perform operation
pct exec 100 -- apt update && apt upgrade -y

# Test and verify
# If successful, delete snapshot after 7 days
# If failed, rollback immediately
pct rollback 100 before-update-$(date +%Y%m%d)
```

### Resource Quotas for LXC

Enable quotas for disk usage tracking:

```bash
# Enter container
pct enter 100

# Initialize quotas
quotacheck -cmug /
quotaon /

# Check quota usage
repquota -a
```

### Backup Strategy

1. **Daily**: Snapshots of critical containers (retained 7 days)
2. **Weekly**: Full backups to local storage (retained 4 weeks)
3. **Monthly**: Full backups to remote PBS (retained 6 months)

### Network Configuration

```bash
# Static IP for container
pct set 100 --net0 name=eth0,bridge=vmbr0,ip=192.168.50.100/24,gw=192.168.50.1

# DHCP for container
pct set 100 --net0 name=eth0,bridge=vmbr0,ip=dhcp

# Multiple networks
pct set 100 --net1 name=eth1,bridge=vmbr1,ip=10.0.0.100/24
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
pct status 100
journalctl -u pve-container@100

# Check configuration
pct config 100

# Try starting in debug mode
pct start 100 --debug

# Check mount points
pct mount 100
ls /rpool/data/subvol-100-disk-0
pct unmount 100
```

### VM Won't Boot

```bash
# Check VM status
qm status 101

# Check logs
qm showcmd 101

# Reset VM
qm reset 101

# Start in debug mode
qm start 101 --debug

# Check BIOS/UEFI settings
qm set 101 --bios ovmf
```

### Storage Issues

```bash
# Check storage status
pvesm status

# Scan for volumes
pvesm scan lvm local-lvm

# Check disk usage
df -h
zfs list  # if using ZFS

# Clean old backups
find /var/lib/vz/dump/ -name "*.tar.*" -mtime +30 -delete
```

### Network Connectivity

```bash
# Check bridge status
ip link show vmbr0

# Check container network
pct exec 100 -- ip addr
pct exec 100 -- ping 8.8.8.8

# Restart networking
systemctl restart networking

# Check firewall rules
pve-firewall status
pve-firewall compile
```

## Integration Points

- **Memory System**: Store common configurations and patterns
- **Cortex**: Document infrastructure changes
- **NocoDB**: Track maintenance tasks
- **Monitoring**: Netdata for resource monitoring

## Environment Variables

Store in `/Users/adamkovacs/Documents/codebuild/.env`:

```bash
PROXMOX_HOST=192.168.50.10
PROXMOX_USER=root@pam
PROXMOX_PASSWORD=<secure_password>
PROXMOX_NODE=harbor
```

## Usage Examples

### Create New LXC Container

```bash
Skill({ skill: "proxmox-vm-lxc-ops" })

# Request: "Create a new Ubuntu container for testing"
# - Downloads latest Ubuntu template
# - Creates container with sensible defaults
# - Starts container
# - Documents in Cortex
```

### Backup All Containers

```bash
# Request: "Backup all LXC containers to local storage"
# - Creates snapshots of all containers
# - Compresses with ZSTD
# - Stores in /var/lib/vz/dump
# - Logs results
```

### Update Container Resources

```bash
# Request: "Increase Jellyfin container memory to 8GB"
# - Creates snapshot before change
# - Updates memory allocation
# - Restarts container if needed
# - Verifies change
```
