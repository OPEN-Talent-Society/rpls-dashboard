# ASUS Router Manager Skill

**Purpose:** Manage ASUS GT-AX11000 router via SSH and web UI for configuration, monitoring, and automation.

**Router Details:**
- Model: ASUS GT-AX11000
- IP: 192.168.50.1
- SSH Port: 5855
- Firmware: 3.0.0.4.388_24394

---

## Prerequisites

**Required Environment Variables:**
```bash
ASUS_ROUTER_IP=192.168.50.1
ASUS_ROUTER_SSH_PORT=5855
ASUS_ROUTER_SSH_KEY=~/.ssh/id_ed25519_asus_router_new
ASUS_ROUTER_USER=sysadmin
ASUS_ROUTER_WEB_USER=sysadmin
ASUS_ROUTER_WEB_PASS=swipe4DILEMMA7helpmate@theatre
```

**Add to `.env`:**
```bash
echo "ASUS_ROUTER_IP=192.168.50.1" >> .env
echo "ASUS_ROUTER_SSH_PORT=5855" >> .env
echo "ASUS_ROUTER_SSH_KEY=~/.ssh/id_ed25519_asus_router_new" >> .env
echo "ASUS_ROUTER_USER=sysadmin" >> .env
```

---

## Core Capabilities

### 1. Router Information
- Get router model, firmware version, uptime
- Monitor WAN/LAN status, IP addresses
- Check WiFi networks and connected clients
- View system resources (CPU, memory, temperature)

### 2. Port Forwarding Management
- List all configured port forwards
- Add new port forward rules
- Remove existing port forwards
- Export/import port forward configurations

### 3. Configuration Backup
- Backup router configuration (nvram settings)
- Save to local storage with timestamp
- Restore configuration from backup
- Automated weekly backup hook

### 4. Network Management
- DHCP lease management
- Static IP reservations
- DNS configuration
- WiFi client management

### 5. Security Operations
- View firewall rules
- Monitor failed login attempts
- SSH key management
- WAN access control

---

## Usage Examples

### Get Router Status
```bash
bash infrastructure-ops/scripts/hardware/asus-router-info.sh
```

**Output:**
```
Router Model: GT-AX11000
Firmware: 3.0.0.4.388_24394
Uptime: 15 days, 3 hours
WAN IP: 50.35.84.22
LAN IP: 192.168.50.1
WiFi Clients: 19 connected
CPU Load: 0.45
Memory: 512MB / 1024MB (50%)
```

### List Port Forwards
```bash
bash infrastructure-ops/scripts/hardware/asus-router-port-forwards.sh list
```

**Output:**
```
Port Forwards (Active):
1. NPM-HTTPS: 443 → 192.168.50.45:443 (TCP)
2. NPM-HTTP: 80 → 192.168.50.45:80 (TCP)
```

### Add Port Forward
```bash
bash infrastructure-ops/scripts/hardware/asus-router-port-forwards.sh add \
  --name "SSH-Server" \
  --port 2222 \
  --local-ip 192.168.50.149 \
  --local-port 22 \
  --protocol TCP
```

### Backup Configuration
```bash
bash infrastructure-ops/scripts/hardware/asus-router-backup-config.sh
```

**Output:**
```
Backing up ASUS router configuration...
Saved to: /Users/adamkovacs/Documents/codebuild/infrastructure-ops/backups/router/asus-router-config-20251206.tar.gz
Size: 2.4MB
```

---

## NVRAM Commands Reference

ASUS routers use `nvram` for persistent storage of settings.

### Core NVRAM Commands
```bash
# Get single value
nvram get <key>

# Set value (requires commit + reboot)
nvram set <key>=<value>
nvram commit
reboot

# List all values (large output)
nvram show

# Get specific configuration
nvram show | grep <pattern>
```

### Common NVRAM Keys

**System Info:**
```bash
nvram get model                # Router model
nvram get firmver              # Firmware version
nvram get buildno              # Build number
nvram get lan_ipaddr           # LAN IP
nvram get wan0_ipaddr          # WAN IP
```

**WiFi:**
```bash
nvram get wl0_ssid             # 2.4GHz SSID
nvram get wl1_ssid             # 5GHz SSID
nvram get wl0_closed           # Hide 2.4GHz SSID (0=visible, 1=hidden)
```

**DHCP:**
```bash
nvram get dhcp_start           # DHCP range start
nvram get dhcp_end             # DHCP range end
nvram get dhcp_staticlist      # Static IP reservations
nvram get dhcpd_lmax           # Max DHCP leases
```

**Port Forwarding:**
```bash
nvram get vts_rulelist         # Virtual server rules (port forwards)
```

**SSH:**
```bash
nvram get sshd_enable          # SSH enabled (0=off, 1=LAN, 2=WAN, 3=Both)
nvram get sshd_port            # SSH port
nvram get sshd_pass            # Allow password login (0=no, 1=yes)
```

---

## Web UI API Access

ASUS routers provide HTTP-based API for configuration.

### Authentication
```bash
# Login and get auth token
curl -k "https://192.168.50.1:8443/login.cgi" \
  -d "login_username=sysadmin&login_passwd=$(echo -n 'PASSWORD' | base64)"

# Returns: asus_token cookie
```

### API Endpoints
```bash
# Get system status
curl -k "https://192.168.50.1:8443/appGet.cgi?hook=get_wan_info"

# Get client list
curl -k "https://192.168.50.1:8443/appGet.cgi?hook=get_clientlist"

# Get port forwards
curl -k "https://192.168.50.1:8443/appGet.cgi?hook=get_vts_rulelist"
```

---

## Security Best Practices

### SSH Access
- ✅ Always use SSH keys (password auth disabled)
- ✅ Non-standard SSH port (5855)
- ✅ LAN-only access (disable WAN SSH unless needed)
- ✅ Timeout: 20 minutes idle

### Web UI Access
- ⚠️ WAN access currently enabled on port 8443
- **Recommendation:** Disable WAN access after setup
- Use Tailscale for remote management instead

### Firewall
- ✅ Only forward ports 80, 443 to NPM
- ❌ Do NOT use UPnP (auto port forwarding)
- ✅ Review port forwards quarterly

---

## Monitoring Integration

### Uptime Kuma Checks
```bash
# Add router monitoring
Monitor Name: ASUS Router
Type: Ping
Hostname: 192.168.50.1
Interval: 60 seconds
Alert: >2 minutes down
```

### Netdata Integration
```bash
# Router metrics (if Netdata SNMP module enabled)
# TBD - ASUS router SNMP configuration
```

---

## Troubleshooting

### SSH Connection Issues
```bash
# Test SSH connectivity
ssh -v -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1

# Check SSH key permissions
chmod 600 ~/.ssh/id_ed25519_asus_router_new

# Verify key is added
ssh-add -l | grep asus-router
```

### Web UI Not Loading
```bash
# Test HTTPS connectivity
curl -Ik https://192.168.50.1:8443

# Check if router is responding
ping -c 3 192.168.50.1
```

### NVRAM Changes Not Persisting
```bash
# Always commit after set
nvram set <key>=<value>
nvram commit

# Reboot required for some changes
reboot
```

---

## Related Skills

- **qnap-nas-manager** - NAS management
- **router-firewall-manager** - Advanced firewall rules
- **docker-network-manager** - Container networking

---

## Scripts Location

All router management scripts are in:
```
infrastructure-ops/scripts/hardware/
├── asus-router-info.sh            # Get router status
├── asus-router-port-forwards.sh   # Manage port forwards
├── asus-router-backup-config.sh   # Backup configuration
└── asus-router-reboot.sh          # Safe router reboot
```

---

## Automation Hooks

### Weekly Backup
```bash
# Hook: .claude/hooks/router-backup-weekly.sh
# Runs: Every Monday 2 AM
# Action: Backup router config to NAS
```

---

**Status:** Ready for production use
**Last Updated:** 2025-12-06
**Maintainer:** Claude Code Infrastructure Team
