# QNAP NAS Access Guide
**Created:** 2025-12-05
**NAS Model:** QNAP (TBD)
**IP Address:** 192.168.50.251
**Status:** SSH Enabled, Web UI accessible locally

---

## Network Configuration

### IP Addresses
- **Local IP:** 192.168.50.251
- **Network:** 192.168.50.0/24 (homelab)
- **Gateway:** 192.168.50.1 (likely ASUS router)

### Ports
- **SSH:** 22 (OpenSSH 10.0)
- **HTTP:** 80 (redirects to HTTPS)
- **HTTPS:** 8081 (Web UI)
- **SMB/CIFS:** 445 (file sharing)
- **AFP:** 548 (if enabled)

### DNS Configuration
- **Domain:** nas.harbor.fyi
- **Public IP:** 50.47.205.173 (homelab WAN)
- **NPM Proxy:** LXC 106 (192.168.50.45)
- **Status:** ⚠️ External access not working - likely router port forwarding issue

---

## Access Methods

### 1. SSH Access (Recommended for CLI)

**From Local Network:**
```bash
ssh admin@192.168.50.251
# OR
ssh -i ~/.ssh/id_qnap admin@192.168.50.251
```

**From Proxmox:**
```bash
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62
ssh admin@192.168.50.251
```

**Available Commands:**
- System status: `uname -a; df -h; free -h`
- Docker containers: `docker ps`
- Network config: `ifconfig; route -n`
- Service status: `systemctl status <service>`
- Package management: `qpkg_cli` or `opkg`

### 2. Web UI Access

**From Local Network:**
```
https://192.168.50.251:8081
# OR
http://192.168.50.251 (redirects to HTTPS:8081)
```

**Via NPM Proxy (when working):**
```
https://nas.harbor.fyi
```

**Credentials:** (Check password manager)

### 3. API Access

**QNAP provides REST API endpoints:**

**Authentication:**
```bash
# Get SID (session ID)
curl -k "https://192.168.50.251:8081/cgi-bin/authLogin.cgi?user=admin&pwd=PASSWORD"
# Returns: <QDocRoot><authPassed>1</authPassed><authSid>SID_HERE</authSid></QDocRoot>
```

**System Info:**
```bash
curl -k "https://192.168.50.251:8081/cgi-bin/management/mReq.cgi?sid=SID&subfunc=sysinfo&func=extra_get"
```

**Storage Info:**
```bash
curl -k "https://192.168.50.251:8081/cgi-bin/disk/disk_manage.cgi?store=volume_get&sid=SID"
```

**File Station API:**
```bash
# Requires QNAP File Station app
curl -k "https://192.168.50.251:8081/cgi-bin/filemanager/utilRequest.cgi?func=stat&sid=SID"
```

### 4. SMB/CIFS Access

**From macOS:**
```bash
# Finder > Go > Connect to Server
smb://192.168.50.251/share-name

# OR command line
mount -t smbfs //admin@192.168.50.251/share-name /mnt/qnap
```

**From Linux:**
```bash
mount -t cifs //192.168.50.251/share-name /mnt/qnap -o username=admin,password=XXX
```

### 5. QNAP CLI Tools (If Installed)

QNAP NAS devices come with built-in CLI tools accessible via SSH:

**Package Management:**
```bash
qpkg_cli -l              # List installed packages
qpkg_cli -m <package>    # Get package info
```

**System Commands:**
```bash
getsysinfo               # System information
getconf                  # Get configuration
setconf                  # Set configuration
```

**Volume/Storage:**
```bash
lvscan                   # Scan logical volumes
pvdisplay                # Physical volume info
vgdisplay                # Volume group info
```

---

## Current Issues

### 1. External Access Not Working

**Problem:** `nas.harbor.fyi` times out from external network

**Diagnosis:**
- DNS resolves to 50.47.205.173 (correct public IP)
- NPM configuration fixed (http://192.168.50.251:80)
- Connection times out = port not forwarded

**Root Cause:**
- Router (ASUS) likely not forwarding port 443 to NPM (192.168.50.45:443)
- OR firewall blocking incoming HTTPS

**Fix Required:**
1. Access ASUS router admin panel
2. Add port forwarding rule: WAN:443 → 192.168.50.45:443
3. Test external access

**Workaround:**
- Use Tailscale: Access via `https://100.85.205.49` with `Host: nas.harbor.fyi` header
- OR direct local access: `https://192.168.50.251:8081`

### 2. QNAP SSL Certificate

**Current:** Self-signed certificate on port 8081

**Options:**
- Use existing Let's Encrypt cert from NPM (reverse proxy handles SSL)
- Install Let's Encrypt directly on QNAP (requires DNS challenge or port 80/443 access)
- Keep self-signed for local access (NPM terminates SSL externally)

**Recommendation:** Let NPM handle SSL termination (current setup)

---

## Router Configuration (ASUS)

**Router Access:** (TBD - need credentials and IP)

**Required Port Forwards:**
| Service | External Port | Internal IP | Internal Port | Protocol |
|---------|---------------|-------------|---------------|----------|
| NPM HTTPS | 443 | 192.168.50.45 | 443 | TCP |
| NPM HTTP | 80 | 192.168.50.45 | 80 | TCP |

**Static IP Assignments (Recommended):**
| Device | MAC Address | IP | Hostname |
|--------|-------------|-----|----------|
| QNAP NAS | TBD | 192.168.50.251 | nas |
| Proxmox | TBD | 192.168.50.10 | proxmox |
| NPM LXC | TBD | 192.168.50.45 | npm |

---

## QNAP Management Tasks

### Check Disk Space
```bash
ssh admin@192.168.50.251 "df -h"
```

### Check Running Services
```bash
ssh admin@192.168.50.251 "systemctl list-units --type=service --state=running"
```

### Check Docker Containers (if Docker enabled)
```bash
ssh admin@192.168.50.251 "docker ps -a"
```

### Backup Configuration
```bash
# Export system config (Web UI: Control Panel > Backup/Restore)
# OR via API
curl -k "https://192.168.50.251:8081/cgi-bin/sys/sysRequest.cgi?subfunc=config_export&sid=SID" -o qnap-config.tar
```

### Update Firmware
```bash
# Web UI: Control Panel > System > Firmware Update
# OR CLI (if available)
ssh admin@192.168.50.251 "update_sys"
```

---

## Security Recommendations

1. **Change Default Admin Password** (if still default)
2. **Enable 2FA** (Web UI: Control Panel > Security > 2-Step Verification)
3. **Disable UPnP** on router (prevents auto port forwarding)
4. **Enable Firewall** (Web UI: Control Panel > Security > Firewall)
5. **Keep Firmware Updated**
6. **Use SSH Keys** instead of passwords for SSH access
7. **Limit SSH Access** to specific IPs via firewall

---

## Monitoring Integration

**Add to Uptime Kuma:**
- [ ] nas.harbor.fyi (HTTPS) - when external access fixed
- [ ] 192.168.50.251:8081 (HTTPS) - local access
- [ ] SMB port 445 (TCP check)

**Add to Netdata:**
- [ ] Install Netdata on QNAP (if supported) OR
- [ ] Monitor via SNMP from existing Netdata instance

**Alerts:**
- Disk space > 80%
- Service down > 2 minutes
- SSH login failures > 5 in 10 minutes

---

## Next Steps

1. **Get QNAP SSH access** - Try default credentials or check password manager
2. **Access ASUS router** - Configure port forwarding for external access
3. **Document QNAP model and firmware version**
4. **Set up static IP reservations** on router
5. **Test external access** after router configuration
6. **Add monitoring** as listed above
