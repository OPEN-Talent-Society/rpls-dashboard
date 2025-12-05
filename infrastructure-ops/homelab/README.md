# Homelab Infrastructure Documentation
**Last Updated:** 2025-12-05
**Status:** Comprehensive documentation complete

---

## Overview

Complete documentation for the homelab network infrastructure, including router configuration, NAS access, network device inventory, and operational procedures.

### Infrastructure Summary
- **Router:** ASUS GT-AX11000 (192.168.50.1)
- **Hypervisor:** Proxmox VE (192.168.50.10 / Tailscale: 100.103.83.62)
- **NAS:** QNAP "Natasha" (192.168.50.251) - 26.7TB, 32% used
- **Reverse Proxy:** Nginx Proxy Manager LXC 106 (192.168.50.45 / Tailscale: 100.85.205.49)
- **Docker Host:** VM 101 via Proxmox (192.168.50.149) - 34+ containers
- **Total Network Devices:** 47+ (Infrastructure, IoT, Smart Home, Mobile)

---

## Documentation Index

### 1. Router Configuration
**File:** `ROUTER-PORT-FORWARDING-GUIDE.md` (14 KB)

Complete ASUS GT-AX11000 router configuration including:
- ✅ SSH access (sysadmin@192.168.50.1:5855 with key auth)
- ✅ Port forwarding (80, 443 → NPM 192.168.50.45)
- ✅ Network configuration (WAN, LAN, DHCP, WiFi)
- ✅ Static DHCP reservations
- ✅ Security considerations

**Quick Access:**
```bash
# SSH to router
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1

# Web UI
https://192.168.50.1:8443
# Username: sysadmin
# Password: swipe4DILEMMA7helpmate@theatre
```

---

### 2. Network Device Inventory
**File:** `NETWORK-DEVICE-INVENTORY.md` (30 KB)

Comprehensive inventory of all 47+ network devices:
- **Infrastructure:** 5 devices (Router, Proxmox, NPM, Docker VM, NAS)
- **Mobile Devices:** 4 devices (phones, tablets, laptops)
- **Smart Home (Google/Nest):** 6 devices (Home, Mini, Max, Nest Hello)
- **Smart Switches (TP-Link Kasa):** 9 devices (HS200, HS100, HS220, HS105)
- **IoT Appliances:** 4 devices (refrigerator, humidifier, purifier, garage)
- **Roomba Vacuums:** 2 devices
- **Printers:** 3 devices
- **Unknown/Unidentified:** 13 devices (need investigation)

**Includes:**
- Complete IP/MAC/hostname mappings
- Device categories and purposes
- QNAP NAS details (storage, packages, Docker containers)
- Security recommendations
- Monitoring integration checklist

---

### 3. NAS Access & Management
**File:** `NAS-ACCESS-GUIDE.md` (7 KB)

QNAP NAS (Natasha) access methods and management:
- ✅ SSH access: `ssh admin@192.168.50.251` (port 22)
- ✅ Web UI: `https://192.168.50.251:8081`
- ✅ External: `https://nas.harbor.fyi` (via NPM, requires port forwarding)
- System: Linux 5.10.60-qnap, 26.7TB (8.4TB used = 32%)
- Packages: Plex, Container Station, Resource Monitor, Security Center
- Credentials: admin / NEMSZERETEMnarancssarga1963takacs

**Common Tasks:**
```bash
# Check disk space
ssh admin@192.168.50.251 "df -h"

# Check running services
ssh admin@192.168.50.251 "systemctl list-units --type=service --state=running"

# Check Docker containers (if Container Station enabled)
ssh admin@192.168.50.251 "docker ps -a"
```

---

### 4. Local DNS Configuration
**File:** `LOCAL-DNS-CONFIGURATION.md` (12 KB)

Solutions for nas.harbor.fyi local network access (hairpin NAT issue):

**Problem:** nas.harbor.fyi times out from local network due to hairpin NAT

**Workarounds:**
1. **Current (Quick):** Use local IP `https://192.168.50.45` or Tailscale
2. **Per-Device:** Add to /etc/hosts: `192.168.50.45 nas.harbor.fyi`
3. **Router-Wide (Recommended):** Configure DNS Director/DNSFilter via Web UI
4. **Advanced:** Enable NAT Loopback (if supported)

**Files Created on Router (not yet active):**
- `/jffs/configs/dnsmasq.conf.add` - address=/nas.harbor.fyi/192.168.50.45
- `/jffs/configs/hosts.add` - 192.168.50.45 nas.harbor.fyi

**Status:** Workarounds documented, Web UI configuration pending

---

## Network Topology

```
INTERNET (Ziply Fiber)
  │
  ├─► WAN: 50.35.84.22 (DYNAMIC IP)
  │
ASUS GT-AX11000 Router (192.168.50.1)
  │
  ├─► WiFi: Zinternet_2.4g / Zinternet_5g / Zinternet_backhaul
  ├─► Port Forwarding: 80, 443 → 192.168.50.45 (NPM)
  │
LAN: 192.168.50.0/24 (DHCP .11-.254)
  │
  ├─► Proxmox (192.168.50.10 / TS: 100.103.83.62)
  │   ├─ LXC 104: Supabase
  │   ├─ LXC 105: n8n
  │   ├─ LXC 106: NPM (192.168.50.45 / TS: 100.85.205.49)
  │   └─ VM 101: Docker Debian (192.168.50.149) - 34+ containers
  │
  ├─► QNAP NAS "Natasha" (192.168.50.251)
  │   ├─ Storage: 26.7TB (32% used)
  │   ├─ Plex Media Server
  │   └─ Container Station (Docker)
  │
  └─► 40+ IoT/Smart Home Devices
       ├─ 6 Google Home/Nest devices
       ├─ 9 TP-Link Kasa switches
       ├─ 2 iRobot Roomba vacuums
       ├─ 4 Smart appliances
       └─ 4 Mobile devices + 13 unidentified
```

---

## Access Credentials

### Router (ASUS GT-AX11000)
- **Web UI:** https://192.168.50.1:8443
- **Username:** sysadmin
- **Password:** swipe4DILEMMA7helpmate@theatre
- **SSH:** Port 5855, key-based (`~/.ssh/id_ed25519_asus_router_new`)

### QNAP NAS (Natasha)
- **Web UI:** https://192.168.50.251:8081
- **Username:** admin
- **Password:** NEMSZERETEMnarancssarga1963takacs
- **SSH:** Port 22, password auth
- **SMB:** `smb://192.168.50.251/share-name`

### Proxmox
- **Web UI:** https://192.168.50.10:8006 OR https://100.103.83.62:8006 (Tailscale)
- **SSH:** `ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62`

### Nginx Proxy Manager
- **Web UI:** https://nginx.harbor.fyi OR https://192.168.50.45:81
- **SSH:** Via Proxmox: `pct enter 106`
- **Tailscale:** https://100.85.205.49

---

## Quick Commands

### Network Discovery
```bash
# Scan network devices
nmap -sn 192.168.50.0/24

# Check active DHCP leases (from router)
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 "cat /var/lib/misc/dnsmasq.leases"

# Check ARP table
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 "arp -a"

# Check wireless clients
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 "wl -i eth6 assoclist && wl -i eth7 assoclist"
```

### Service Checks
```bash
# Test NPM from local network
curl -I http://192.168.50.45 -H "Host: nas.harbor.fyi"

# Test NAS SSH
ssh admin@192.168.50.251 "hostname && uptime"

# Test port forwarding (from router)
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 "iptables -t nat -L VSERVER"
```

---

## Monitoring Integration

### Devices to Add to Uptime Kuma
- [ ] Router (192.168.50.1) - Ping + SSH check
- [ ] Proxmox (192.168.50.10) - Ping + HTTPS:8006
- [ ] NPM (192.168.50.45) - HTTPS:81
- [ ] Docker VM (192.168.50.149) - Ping + SSH
- [ ] QNAP NAS (192.168.50.251) - Ping + HTTPS:8081 + SSH
- [ ] nas.harbor.fyi (external) - HTTPS
- [ ] Critical smart home devices - Ping

### Alerts to Configure
- Router offline > 1 minute (CRITICAL)
- NAS offline > 2 minutes (HIGH)
- Proxmox offline > 2 minutes (HIGH)
- QNAP storage > 90% (HIGH)
- QNAP root filesystem > 90% (HIGH - currently at 85%)
- Unknown device connected (MEDIUM)

---

## Security Considerations

### Current Security Posture
✅ **Strengths:**
- SSH key-based authentication (router, Proxmox)
- Port forwarding limited to NPM only (80, 443)
- NPM handles SSL termination with Let's Encrypt
- QNAP running security packages
- Password authentication requires strong passwords

⚠️ **Areas for Improvement:**
1. **13 unidentified devices** - identify all devices or remove
2. **Many IoT devices** - potential security vulnerabilities
3. **Dynamic WAN IP** - consider DDNS or static IP
4. **Smart home devices** - typically lack security updates
5. **QNAP root filesystem 85%** - needs cleanup
6. **WAN admin access** - router accessible from internet

### Recommended Actions
1. Enable QVPN or Tailscale for all remote access
2. Identify all unknown devices
3. Consider VLAN segmentation for IoT devices
4. Regular firmware updates for all devices
5. Disable WAN admin access to router
6. QNAP storage cleanup and monitoring

---

## Next Steps

### Immediate (This Week)
1. ⏳ Configure local DNS override via router Web UI (DNS Director/DNSFilter)
2. ⏳ Add static DHCP reservations for NPM (192.168.50.45) and NAS (192.168.50.251)
3. ⏳ Identify all 13 unknown devices
4. ⏳ Add all infrastructure devices to Uptime Kuma
5. ⏳ Set up push notifications (Ntfy) for critical alerts

### Short-term (This Month)
6. ⏳ Install Netdata on Proxmox and LXCs for metrics
7. ⏳ Configure alert channels (Email via Brevo, Push via Ntfy, SMS for critical)
8. ⏳ QNAP root filesystem cleanup (target <70%)
9. ⏳ Review and disable QNAP packages not in use
10. ⏳ Disable router WAN admin access (use Tailscale instead)

### Long-term (Next Quarter)
11. ⏳ VLAN segmentation (Infrastructure / IoT / Guest)
12. ⏳ Static IP from ISP or reliable DDNS setup
13. ⏳ Automated firmware update monitoring
14. ⏳ Comprehensive backup strategy for NAS
15. ⏳ Regular security audits

---

## Documentation History

| Date | Document | Status | Notes |
|------|----------|--------|-------|
| 2025-12-05 | ROUTER-PORT-FORWARDING-GUIDE.md | ✅ Complete | Full router config, SSH working, port forwarding active |
| 2025-12-05 | NETWORK-DEVICE-INVENTORY.md | ✅ Complete | 47+ devices mapped, full details, MAC/IP/hostname |
| 2025-12-05 | NAS-ACCESS-GUIDE.md | ✅ Complete | SSH/Web UI access verified, 26.7TB storage documented |
| 2025-12-05 | LOCAL-DNS-CONFIGURATION.md | ✅ Complete | Hairpin NAT issue documented with 4 solution options |
| 2025-12-05 | README.md | ✅ Complete | This file - comprehensive index and quick reference |

---

## Support & References

- **ASUS Router Support:** https://www.asus.com/support/
- **QNAP Support:** https://www.qnap.com/support/
- **Proxmox Documentation:** https://pve.proxmox.com/wiki/Main_Page
- **Nginx Proxy Manager:** https://nginxproxymanager.com/
- **Tailscale:** https://tailscale.com/kb/

---

**Maintained By:** Claude Code
**Last Network Scan:** 2025-12-05 13:30 PST
**Total Documentation Size:** ~75 KB across 5 files
