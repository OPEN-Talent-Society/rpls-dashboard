# Complete Homelab Network Device Inventory
**Last Updated:** 2025-12-05
**Router:** ASUS GT-AX11000 (192.168.50.1)
**Network:** 192.168.50.0/24
**DHCP Range:** 192.168.50.11 - 192.168.50.254

---

## Network Configuration Summary

### WAN Configuration
- **Public IP:** 50.35.84.22 (Dynamic - Ziply Fiber)
- **Gateway:** 50.35.80.1
- **DNS Servers:** 192.152.0.1, 192.152.0.2
- **ISP:** Ziply Fiber (evrt.wa.ptr.ziplyfiber.com)

### LAN Configuration
- **Router IP:** 192.168.50.1
- **Subnet Mask:** 255.255.255.0 (/24)
- **DHCP Start:** 192.168.50.11
- **DHCP End:** 192.168.50.254

### WiFi Networks
- **2.4GHz SSID:** Zinternet_2.4g
- **5GHz SSID:** Zinternet_5g
- **Backhaul SSID:** Zinternet_backhaul

### Port Forwarding (Active)
| External Port | Internal IP | Internal Port | Service | Protocol |
|---------------|-------------|---------------|---------|----------|
| 80 | 192.168.50.45 | 80 | NPM HTTP | TCP |
| 443 | 192.168.50.45 | 443 | NPM HTTPS | TCP |

---

## Infrastructure Devices (Static IPs)

### Core Infrastructure

| Device | IP | MAC | Hostname | Type | Notes |
|--------|-----|-----|----------|------|-------|
| **ASUS Router** | 192.168.50.1 | - | GT-AX11000 | Router | Firmware 3.0.0.4.388_24394 |
| **Proxmox** | 192.168.50.10 | 58:47:CA:79:55:97 | proxmox | Hypervisor | Static DHCP, Tailscale: 100.103.83.62 |
| **NPM LXC 106** | 192.168.50.45 | BC:24:11:56:C8:09 | npm | Reverse Proxy | Nginx Proxy Manager, Tailscale: 100.85.205.49 |
| **Docker VM** | 192.168.50.149 | BC:24:11:D8:AB:86 | dockerhost | Docker Host | Static DHCP, 34+ containers |
| **QNAP NAS** | 192.168.50.251 | 24:5E:BE:16:49:2A | Natasha | NAS | 26.7TB storage (32% used = 8.4TB) |

### Proxmox LXCs (Additional)
- **LXC 104:** Supabase (IP TBD)
- **LXC 105:** n8n (IP TBD)
- **LXC 106:** NPM (192.168.50.45)

---

## Mobile Devices

| Device | IP | MAC | Hostname | Connection | Notes |
|--------|-----|-----|----------|------------|-------|
| Adam's Phone | 192.168.50.146 | 0A:77:3B:0C:C2:8B | Adam-s-phone | WiFi | Active |
| iPhone | 192.168.50.194 | 9C:DA:A8:DB:C6:6C | iPhone | WiFi | Active |
| Pixel 7 | 192.168.50.33 | 86:87:1C:63:1D:E7 | Pixel-7 | WiFi | Active |
| Mac | 192.168.50.245 | 52:43:55:93:61:D3 | Mac | WiFi | Active |

---

## Smart Home Devices

### Google/Nest Ecosystem

| Device | IP | MAC | Hostname | Type | Location |
|--------|-----|-----|----------|------|----------|
| Google Home | 192.168.50.235 | 48:D6:D5:70:D6:25 | Google-Home | Smart Speaker | - |
| Google Home Mini | 192.168.50.51 | D4:F5:47:68:BB:71 | Google-Home-Mini | Smart Speaker | - |
| Google Nest Mini | 192.168.50.90 | F8:0F:F9:8B:C8:1E | Google-Nest-Mini | Smart Speaker | - |
| Google Home Max | 192.168.50.176 | 48:D6:D5:86:4F:9D | Google-Home-Max | Smart Speaker | - |
| Nest Hello | 192.168.50.243 | 64:16:66:77:0E:EB | Nest-Hello-0eeb | Doorbell Camera | - |
| Chromecast Audio | 192.168.50.43 | 54:60:09:DB:D8:32 | Chromecast-Audio | Media Streamer | - |

### TP-Link Kasa Smart Switches

| Device | IP | MAC | Hostname | Model | Notes |
|--------|-----|-----|----------|-------|-------|
| Switch 1 | 192.168.50.179 | AC:84:C6:3C:33:B5 | HS200 | HS200 | WiFi Light Switch |
| Switch 2 | 192.168.50.157 | B0:4E:26:16:BF:AF | HS100 | HS100 | WiFi Smart Plug |
| Switch 3 | 192.168.50.180 | B0:BE:76:1A:DF:32 | HS220 | HS220 | WiFi Dimmer Switch |
| Switch 4 | 192.168.50.242 | AC:84:C6:61:B2:0E | HS105 | HS105 | WiFi Smart Plug |
| Switch 5 | 192.168.50.212 | AC:84:C6:3C:2B:A2 | - | TP-Link | - |
| Switch 6 | 192.168.50.192 | B0:BE:76:1A:D8:2F | - | TP-Link | - |
| Switch 7 | 192.168.50.12 | AC:84:C6:3C:22:75 | - | TP-Link | - |
| Switch 8 | 192.168.50.89 | C4:5B:BE:BD:84:F0 | - | TP-Link | - |
| Switch 9 | 192.168.50.147 | C4:5B:BE:AD:F2:E8 | - | TP-Link | - |

### Appliances & Smart Home

| Device | IP | MAC | Hostname | Type | Notes |
|--------|-----|-----|----------|------|-------|
| Refrigerator | 192.168.50.248 | 28:6B:B4:4F:16:49 | refrigerator | Smart Refrigerator | - |
| Levoit Humidifier | 192.168.50.188 | 84:CC:A8:D3:DA:F4 | Levoit-Humidifier | Humidifier | - |
| Levoit Purifier | 192.168.50.60 | 94:3C:C6:5B:A8:40 | Levoit-purifier | Air Purifier | - |
| MyQ Garage | 192.168.50.75 | 64:52:99:48:61:04 | MyQ-B29 | Garage Door Opener | Chamberlain MyQ |

### Roomba/iRobot Vacuums

| Device | IP | MAC | Hostname | Model | Notes |
|--------|-----|-----|----------|-------|-------|
| iRobot 1 | 192.168.50.131 | 50:14:79:52:B7:BA | iRobot-21D870EF... | Roomba | ID: 21D870EF1CA54FDA8E930604796E5B1F |
| iRobot 2 | 192.168.50.170 | 50:14:79:92:8D:67 | iRobot-F2D7E845... | Roomba | ID: F2D7E84522BE4F46B7C65BF13B0369FF |

### Printers

| Device | IP | MAC | Hostname | Model | Notes |
|--------|-----|-----|----------|-------|-------|
| Printer 1 | 192.168.50.185 | 18:B4:30:BC:A9:63 | 09AA01AC02170TLW | Printer | - |
| Printer 2 | 192.168.50.117 | 18:B4:30:40:D6:AC | 07AA01AD021801Q7 | Printer | - |
| Brother Printer | 192.168.50.129 | 30:C9:AB:58:50:AD | BRW30C9AB5850AD | Brother Printer | - |

---

## Computers & Laptops

| Device | IP | MAC | Hostname | Type | Notes |
|--------|-----|-----|----------|------|-------|
| Lenovo | 192.168.50.71 | 10:2C:6B:78:9F:96 | lenovo | Laptop/PC | - |

---

## Unknown/Unidentified Devices

| IP | MAC | Hostname | Notes |
|----|-----|----------|-------|
| 192.168.50.133 | 14:C1:4E:4C:44:63 | - | Unknown device |
| 192.168.50.244 | 18:31:BF:AE:DB:00 | - | Unknown device |
| 192.168.50.112 | 1C:61:B4:F8:2C:34 | - | Unknown device |
| 192.168.50.153 | BC:24:11:EF:37:87 | - | Possibly Proxmox related |
| 192.168.50.88 | 1C:61:B4:F8:24:DC | - | Unknown device |
| 192.168.50.213 | 48:B0:2D:09:33:CC | - | Unknown device |
| 192.168.50.160 | 02:F6:13:C8:77:2F | - | Unknown device |
| 192.168.50.232 | BC:24:11:53:64:7F | - | Possibly Proxmox related |
| 192.168.50.233 | BC:24:11:04:A2:74 | - | Possibly Proxmox related |
| 192.168.50.187 | BC:24:11:3B:44:1B | - | Possibly Proxmox related |
| 192.168.50.72 | 98:93:CC:BB:75:AF | - | Unknown device |
| 192.168.50.26 | 00:17:88:6D:41:2C | - | Philips device (Hue bridge?) |
| 192.168.50.216 | 1C:61:B4:F8:2B:74 | - | Unknown device |

---

## QNAP NAS (Natasha) Details

### System Information
- **Hostname:** Natasha
- **Model:** QNAP (TBD from web UI)
- **OS:** QTS (Linux 5.10.60-qnap)
- **IP:** 192.168.50.251
- **MAC:** 24:5E:BE:16:49:2A

### Storage
- **Total Capacity:** 26.7 TB
- **Used:** 8.4 TB (32%)
- **Available:** 18.3 TB
- **Root Filesystem:** 85% full (400MB, 338.6MB used)

### Installed Packages (QPKG)
- **Plex Media Server:** v1.42.2 (Enabled)
- **Container Station:** v3.1.1.1451 (Enabled)
- **Resource Monitor:** v1.2.0 (Enabled)
- **Network & Virtual Switch:** v2.5.5 (Enabled)
- **Security Center:** v3.1.0.3632 (Disabled)
- **QVPN Service:** v3.2.10880 (Disabled)
- **Malware Remover:** v6.6.8 (Enabled)
- **QuLog Center:** v1.8.2.927 (Enabled)
- **Notification Center:** v1.9.2.3163 (Enabled)
- **Qboost:** v1.6.3 (Enabled)

### Access Methods
- **SSH:** `ssh admin@192.168.50.251` (port 22)
- **Web UI:** `https://192.168.50.251:8081`
- **External:** `https://nas.harbor.fyi` (via NPM)
- **Credentials:** admin / NEMSZERETEMnarancssarga1963takacs

### Docker Containers
Container Station is running with Docker overlay filesystems visible.
Containers include at least:
- Plex Media Server
- Additional containers (exact count TBD - Docker CLI not in default SSH PATH)

---

## WiFi Clients (Currently Connected)

**Total WiFi Clients:** 19 devices on 2.4GHz and 5GHz bands

Connected devices include:
- TP-Link smart switches (9 devices)
- Google Home devices (4 devices)
- iRobot vacuums (2 devices)
- Printers (2 devices)
- Air quality devices (2 devices)

---

## Network Statistics

### Device Count by Category
- **Infrastructure:** 5 devices (Router, Proxmox, NPM, Docker VM, NAS)
- **Mobile Devices:** 4 devices
- **Smart Home (Google/Nest):** 6 devices
- **Smart Switches (TP-Link):** 9 devices
- **Appliances:** 4 devices
- **Roomba Vacuums:** 2 devices
- **Printers:** 3 devices
- **Computers:** 1 device
- **Unknown/Unidentified:** 13 devices

**Total Active Devices:** ~47 devices on network

### IP Allocation
- **Static DHCP:** 2 devices (Proxmox, Docker VM)
- **DHCP Leases:** ~30 devices
- **Manual/Unknown:** ~15 devices
- **Available IPs:** ~200 (out of .11-.254 range)

---

## Security Considerations

### Current Security Posture
✅ **Strengths:**
- SSH key-based authentication on router
- Port forwarding limited to NPM only (ports 80, 443)
- NPM handles SSL termination with Let's Encrypt
- QNAP running security packages (Malware Remover, Security Center)
- Router web access requires authentication

⚠️ **Areas for Improvement:**
1. **13 unidentified devices** - need to identify all devices on network
2. **Many IoT devices** - potential security vulnerabilities
3. **QVPN disabled** - consider enabling for secure remote access
4. **Dynamic WAN IP** - consider DDNS or static IP for reliability
5. **Smart home devices** - typically lack security updates
6. **QNAP root filesystem at 85%** - needs cleanup

### Recommendations
1. **Enable QVPN or use Tailscale** for secure remote access
2. **Identify all unknown devices** - disconnect unauthorized devices
3. **Segment IoT devices** - consider VLAN for smart home devices
4. **Set up monitoring** for all infrastructure devices
5. **Regular security updates** for QNAP, Router, Proxmox
6. **QNAP storage cleanup** - free up root filesystem space

---

## Monitoring Integration Plan

### Uptime Kuma Monitors to Add
- [ ] Router (192.168.50.1) - Ping
- [ ] Proxmox (192.168.50.10) - Ping + HTTPS:8006
- [ ] NPM (192.168.50.45) - HTTPS:81
- [ ] Docker VM (192.168.50.149) - Ping
- [ ] QNAP NAS (192.168.50.251) - Ping + HTTPS:8081
- [ ] nas.harbor.fyi (external) - HTTPS
- [ ] All critical smart home devices - Ping

### Alerts to Configure
- Router offline > 1 minute (CRITICAL)
- NAS offline > 2 minutes (HIGH)
- Proxmox offline > 2 minutes (HIGH)
- QNAP storage > 90% (HIGH)
- QNAP root filesystem > 90% (HIGH)
- Unknown device connected (MEDIUM)

---

## Notes

### IP Address Patterns
- **192.168.50.10-50:** Infrastructure devices
- **192.168.50.51-100:** Smart home devices
- **192.168.50.101-150:** Mobile devices and computers
- **192.168.50.151-200:** IoT and printers
- **192.168.50.201-254:** DHCP pool overflow

### MAC Address Vendor Prefixes
- **58:47:CA:** Proxmox/VM
- **BC:24:11:** Intel (likely Proxmox NICs)
- **24:5E:BE:** QNAP Systems
- **AC:84:C6:** TP-Link (Kasa switches)
- **48:D6:D5:** Google (Home devices)
- **64:16:66:** Google (Nest doorbell)
- **50:14:79:** iRobot (Roomba)

---

## Next Actions

1. **Identify unknown devices** - Use router web UI "Network Map" to see device names
2. **Document Proxmox VMs** - Get IPs and MACs for all LXCs/VMs
3. **Check Philips Hue** - Verify if 00:17:88:6D:41:2C is Hue Bridge
4. **QNAP Docker containers** - Access Container Station to list all running containers
5. **Consider VLANs** - Segment network: Infrastructure / IoT / Guest
6. **Set up monitoring** - Add all devices to Uptime Kuma
7. **Update firmware** - Router, QNAP, smart devices

---

**Last Scan:** 2025-12-05 13:30 PST
**Scanned By:** Claude Code (automated network discovery)
**Methods Used:** Router DHCP leases, ARP table, wireless client lists, SSH access
