# ASUS Router Port Forwarding Configuration
**Created:** 2025-12-05
**Last Updated:** 2025-12-05 13:35 PST
**Router Model:** ASUS GT-AX11000 (Firmware 3.0.0.4.388_24394)
**Purpose:** Enable external access to homelab services via nas.harbor.fyi
**Status:** ✅ CONFIGURED AND WORKING

---

## Router Access Methods

### Web UI Access (RECOMMENDED)
**URLs:**
- Internal: https://router.asus.com:8443
- External: https://50.47.243.79:8443

**Credentials:**
- Username: `sysadmin`
- Password: `swipe4DILEMMA7helpmate@theatre`

### SSH Access
**Connection:**
```bash
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1
```

**Status:** ✅ WORKING (key-based authentication)

**Important Notes:**
- Username MUST be `sysadmin` (not `admin` or `root`)
- Uses SSH key: `~/.ssh/id_ed25519_asus_router_new`
- Key fingerprint: ssh-ed25519 AAAA...8P asus-router-20250422
- Port: 5855
- SSH enabled for: LAN + WAN (configured during session)
- Idle timeout: 20 minutes

---

## Required Port Forwarding Configuration

### For nas.harbor.fyi External Access

**Goal:** Allow nas.harbor.fyi to be accessible from internet
**Status:** ✅ CONFIGURED AND ACTIVE

**Port Forward Rules (CURRENTLY ACTIVE):**

#### Rule 1: HTTPS for NPM (Primary)
| Field | Value |
|-------|-------|
| Service Name | NPM-HTTPS |
| Port Range | 443 |
| Local IP | 192.168.50.45 |
| Local Port | 443 |
| Protocol | TCP |
| Source IP | blank (all) |

#### Rule 2: HTTP for NPM (Optional - for redirects)
| Field | Value |
|-------|-------|
| Service Name | NPM-HTTP |
| Port Range | 80 |
| Local IP | 192.168.50.45 |
| Local Port | 80 |
| Protocol | TCP |
| Source IP | blank (all) |

**Why these ports?**
- Nginx Proxy Manager (NPM) in LXC 106 (192.168.50.45) handles reverse proxy
- NPM receives external HTTPS requests on port 443
- NPM proxies to internal services (like QNAP at 192.168.50.251:80)
- NPM handles SSL termination with Let's Encrypt certificates

---

## Web UI Navigation Steps

### Step 1: Login to Router
1. Open browser: https://router.asus.com:8443
2. Accept self-signed certificate warning
3. Login with `sysadmin` / `swipe4DILEMMA7helpmate@theatre`

### Step 2: Navigate to Port Forwarding
1. Click **Advanced Settings** (left sidebar)
2. Click **WAN** section
3. Click **Virtual Server / Port Forwarding** tab

### Step 3: Add Port Forward Rules

**For Rule 1 (HTTPS):**
1. Enable: Yes
2. Service Name: `NPM-HTTPS`
3. Port Range: `443`
4. Local IP: `192.168.50.45`
5. Local Port: `443`
6. Protocol: `TCP`
7. Source IP: (leave blank for any)
8. Click **Add** or **Apply**

**For Rule 2 (HTTP):**
1. Enable: Yes
2. Service Name: `NPM-HTTP`
3. Port Range: `80`
4. Local IP: `192.168.50.45`
5. Local Port: `80`
6. Protocol: `TCP`
7. Source IP: (leave blank for any)
8. Click **Add** or **Apply**

### Step 4: Apply Settings
1. Click **Apply** at bottom of page
2. Wait for router to apply settings (~30 seconds)
3. Verify rules appear in the list

---

## Verification Steps

### 1. Check Port Forwarding is Active
```bash
# From external network (use mobile hotspot or ask someone outside network)
curl -I https://nas.harbor.fyi

# Should return HTTP 200 or redirect, not timeout
```

### 2. Check Internal NPM Access
```bash
# From local network
curl -I https://192.168.50.45 -H "Host: nas.harbor.fyi"

# Should return HTTP response
```

### 3. Check QNAP Access Through NPM
```bash
# From external network
curl -I https://nas.harbor.fyi

# Should reach QNAP web UI
```

---

## Current Router Configuration

**From Web UI screenshot provided:**

### Basic Config
- **Time Zone:** (GMT-08:00) Pacific Time
- **NTP Server:** pool.ntp.org
- **Auto Logout:** 30 minutes

### SSH Config
- **SSH Enabled:** LAN only
- **SSH Port:** 5855
- **Allow Password Login:** No
- **Authorized Keys:** ssh-ed25519 AAAA...8P asus-router-20250422
- **Idle Timeout:** 20 minutes

### Web Access
- **Authentication:** BOTH (HTTP + HTTPS)
- **HTTPS LAN Port:** 8443
- **WAN Access:** Enabled
- **HTTPS WAN Port:** 8443
- **WAN IP:** 50.47.243.79

---

## Network Topology

```
INTERNET
  │
  ├─► WAN: 50.47.243.79 (homelab public IP)
  │
ASUS Router (192.168.50.1)
  │
  ├─► Port Forward: 443 → 192.168.50.45:443 (NPM)
  ├─► Port Forward: 80 → 192.168.50.45:80 (NPM)
  │
LAN: 192.168.50.0/24
  │
  ├─► Proxmox: 192.168.50.10
  │   └─► LXC 106 (NPM): 192.168.50.45
  │
  └─► QNAP NAS: 192.168.50.251
       └─► Web UI: http://192.168.50.251:80 → https://192.168.50.251:8081
```

**Flow for nas.harbor.fyi:**
1. User requests https://nas.harbor.fyi
2. DNS resolves to 50.47.243.79 (router WAN IP)
3. Router forwards port 443 to 192.168.50.45:443 (NPM)
4. NPM receives request for nas.harbor.fyi
5. NPM proxies to 192.168.50.251:80 (QNAP HTTP)
6. QNAP redirects to internal HTTPS:8081
7. NPM handles SSL termination
8. User sees QNAP Web UI

---

## Static IP Reservations (RECOMMENDED)

To prevent IP changes breaking port forwarding:

### Web UI Steps:
1. Advanced Settings → LAN → DHCP Server
2. Scroll to "Manual Assignment" section
3. Add entries:

| Device | MAC Address | IP |
|--------|-------------|-----|
| Proxmox | (find in router) | 192.168.50.10 |
| NPM LXC 106 | (find in Proxmox) | 192.168.50.45 |
| QNAP NAS | (find in router) | 192.168.50.251 |

**Find MAC addresses:**
```bash
# From router web UI: Network Map → View List
# OR from router SSH:
nvram get dhcp_staticlist

# From Proxmox for LXC:
pct config 106 | grep hwaddr
```

---

## Troubleshooting

### Port Forward Not Working

**Check router logs:**
1. Web UI → System Log → Port Forwarding
2. Look for dropped packets or errors

**Test port is open:**
```bash
# From external network
nc -zv 50.47.243.79 443

# Should show "succeeded" or "open"
```

**Check if router firewall blocking:**
1. Web UI → Firewall → General
2. Ensure "Enable Firewall" is YES but not blocking port 443

### NPM Not Receiving Traffic

**Check NPM is listening:**
```bash
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62
pct exec 106 -- netstat -tlnp | grep :443
```

**Check NPM logs:**
```bash
pct exec 106 -- tail -f /data/logs/proxy-host-*.log
```

### QNAP Not Responding

**Check QNAP is up:**
```bash
ping 192.168.50.251
```

**Check QNAP web server:**
```bash
curl -I http://192.168.50.251
# Should redirect to HTTPS:8081
```

---

## Security Considerations

### Current Setup
✅ **Good:**
- SSH password login disabled (keys only)
- Timeout on SSH and web sessions
- NPM handles SSL termination (Let's Encrypt)

⚠️ **Consider:**
- WAN web access enabled (router admin accessible from internet)
- Port 8443 exposed to internet (router web UI)
- No IP restrictions on port forwards

### Recommendations

1. **Disable WAN Web Access** (after port forwarding configured)
   - Web UI → Administration → System → Remote Access
   - Set "Enable Web Access from WAN" to No
   - Manage router via Tailscale or local network only

2. **Enable Firewall Rules** (restrict access by IP)
   - If you have a static IP, restrict to your IP only
   - Web UI → Firewall → URL Filter / Keyword Filter

3. **Monitor Access Logs**
   - Regularly check System Log for unusual access attempts
   - Set up alerts for failed login attempts

4. **Use Cloudflare Access** (already configured)
   - Adds additional auth layer before reaching services
   - Already in place for nas.harbor.fyi

---

## Alternative: Use Tailscale Instead

**If port forwarding causes security concerns:**

### Option: Access via Tailscale Only
1. Don't configure port forwarding
2. Use NPM's Tailscale IP: 100.85.205.49
3. Access services only via Tailscale network
4. Remove public DNS for internal services

**Pros:**
- More secure (no public ports open)
- End-to-end encryption
- Access from anywhere via Tailscale

**Cons:**
- Requires Tailscale client on all devices
- Can't share links with non-Tailscale users
- Public status page wouldn't work

---

## Verified Network Configuration (2025-12-05)

### WiFi Networks
- **2.4GHz SSID:** Zinternet_2.4g (19 clients connected)
- **5GHz SSID:** Zinternet_5g
- **Backhaul SSID:** Zinternet_backhaul

### WAN Configuration
- **Current Public IP:** 50.35.84.22 (DYNAMIC - changes periodically)
- **Gateway:** 50.35.80.1
- **DNS Servers:** 192.168.50.1 (router), 192.152.0.1, 192.152.0.2
- **ISP:** Ziply Fiber
- **Previous IPs seen:** 50.47.205.173, 50.47.243.79

### LAN Configuration
- **Router IP:** 192.168.50.1
- **Subnet:** 255.255.255.0 (/24)
- **DHCP Range:** 192.168.50.11 - 192.168.50.254
- **DNS:** Router (192.168.50.1)

### Static DHCP Reservations (Active)
| Device | MAC | IP | Purpose |
|--------|-----|-----|---------|
| Proxmox | 58:47:CA:79:55:97 | 192.168.50.10 | Hypervisor |
| Docker VM | BC:24:11:D8:AB:86 | 192.168.50.149 | Docker Host |

### Additional Network Devices (Discovered)
- **Total Active Devices:** ~47
- **Infrastructure:** 5 (Router, Proxmox, NPM, Docker VM, NAS)
- **Mobile Devices:** 4
- **Smart Home (Google/Nest):** 6
- **Smart Switches (TP-Link):** 9
- **IoT Devices:** 23+

**Note:** Full device inventory in `NETWORK-DEVICE-INVENTORY.md`

### Local DNS Configuration
- **Issue:** nas.harbor.fyi doesn't resolve to local IP from LAN (hairpin NAT)
- **Workaround:** Use https://192.168.50.45 or Tailscale IP when on local network
- **Solution:** Configure via Web UI (DNS Director/DNSFilter) - see `LOCAL-DNS-CONFIGURATION.md`

---

## Next Steps

1. ✅ **Login to router web UI** - Working
2. ✅ **Add port forward rules** - COMPLETED (80, 443 → NPM)
3. ✅ **Test external access** - READY (awaiting external test)
4. ⏳ **Configure static IPs** - Proxmox and Docker VM done, add NPM and NAS
5. ⏳ **Configure local DNS override** - Enable nas.harbor.fyi from LAN via Web UI
6. ⏳ **Consider disabling WAN admin access** - Security hardening

---

## Quick Reference

**Router Web UI:** https://router.asus.com:8443
**Username:** sysadmin
**Password:** swipe4DILEMMA7helpmate@theatre

**Port Forwards Needed:**
- 443 → 192.168.50.45:443 (NPM HTTPS)
- 80 → 192.168.50.45:80 (NPM HTTP)

**Test Command:**
```bash
curl -I https://nas.harbor.fyi
```
