# Local DNS Configuration for nas.harbor.fyi
**Created:** 2025-12-05
**Issue:** Hairpin NAT - nas.harbor.fyi doesn't work from local network
**Status:** Requires Web UI configuration

---

## Problem Description

**Symptom:** When accessing `https://nas.harbor.fyi` from the local network (192.168.50.0/24), the connection times out or fails.

**Root Cause:** Hairpin NAT issue
- DNS resolves nas.harbor.fyi to public WAN IP (50.47.205.173 or similar)
- Traffic goes to router, which should forward to local NPM (192.168.50.45)
- Many routers don't support "hairpin NAT" (routing WAN→LAN traffic back into LAN)
- Result: Connection fails or times out

**What Works:**
- ✅ External access (from internet): `https://nas.harbor.fyi` → 50.47.205.173 → Router → 192.168.50.45:443 → NPM → NAS
- ✅ Local direct IP: `https://192.168.50.45` (access NPM directly)
- ✅ Tailscale: `https://100.85.205.49` (NPM's Tailscale IP)- ❌ Local via domain: `https://nas.harbor.fyi` (fails due to hairpin NAT)

---

## Solution Options

### Option 1: Use Local IP or Tailscale (CURRENT WORKAROUND)

**From Local Network:**
```bash
# Direct to NPM
https://192.168.50.45

# Via Tailscale (if connected)
https://100.85.205.49

# Direct to NAS
https://192.168.50.251:8081
```

**Pros:**
- Works immediately, no configuration needed
- Bypasses DNS entirely

**Cons:**
- Must remember IPs
- Can't use nice domain name from local network
- Different URL for local vs external

---

### Option 2: Manual /etc/hosts on Each Device

**On macOS/Linux:**
```bash
sudo sh -c 'echo "192.168.50.45 nas.harbor.fyi" >> /etc/hosts'
```

**On Windows:**
```powershell
# As Administrator
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "192.168.50.45 nas.harbor.fyi"
```

**Pros:**
- nas.harbor.fyi works from all devices that have the hosts entry
- No router configuration needed

**Cons:**
- Must configure EVERY device on network
- Requires admin/sudo access
- Difficult to maintain

---

### Option 3: Router Web UI DNS Configuration (RECOMMENDED)

**Via ASUS Router Web UI:**

1. **Login to Router:**
   - URL: `https://192.168.50.1:8443` or `https://router.asus.com:8443`
   - Username: `sysadmin`
   - Password: `swipe4DILEMMA7helpmate@theatre`

2. **Navigate to LAN DNS Settings:**
   - Go to **Advanced Settings** > **LAN** > **DHCP Server**
   - Scroll to **DNS and WINS Server Setting**

3. **Option A: Use DNS Director (if available):**
   - Go to **Advanced Settings** > **WAN** > **DNS Director**
   - Add rule: Domain `nas.harbor.fyi` → Client IP `192.168.50.45`

4. **Option B: Use DNSFilter:**
   - Go to **Advanced Settings** > **AiProtection** > **DNS Filter**
   - Enable Custom DNS
   - Add nas.harbor.fyi → 192.168.50.45

5. **Option C: Manually Edit dnsmasq (Advanced):**
   - Enable JFFS custom scripts and configs (if not already enabled)
   - SSH into router
   - Edit `/jffs/configs/dnsmasq.conf.add`:
     ```
     address=/nas.harbor.fyi/192.168.50.45
     ```
   - Restart dnsmasq: `service restart_dnsmasq`

**Note:** Attempted automated SSH configuration (dnsmasq.conf.add and hosts.add) but ASUS firmware doesn't read these files automatically without additional configuration.

**Pros:**
- Works for ALL devices on network automatically
- Uses nice domain name `nas.harbor.fyi`
- Persistent across reboots (JFFS)

**Cons:**
- Requires router web UI access
- More complex configuration

---

### Option 4: Enable Hairpin NAT (If Supported)

**Check if GT-AX11000 supports NAT Loopback:**

Some ASUS routers support NAT loopback via:
- **Advanced Settings** > **Administration** > **System**
- Look for "Enable NAT Loopback" or similar option

**OR via nvram (if available):**
```bash
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1
nvram set fw_pt_pptp=1
nvram set fw_pt_l2tp=1
nvram commit
service restart_firewall
```

**Status:** Already enabled (checked), but may not support full hairpin NAT for HTTP/HTTPS.

**Pros:**
- If it works, no other config needed
- Works automatically for all devices

**Cons:**
- GT-AX11000 may not support full hairpin NAT
- Security implications (allows LAN→WAN→LAN traffic)

---

## Current Configuration Status

### Attempted Configurations
1. ✅ **Port Forwarding:** 80, 443 → 192.168.50.45 (working)
2. ✅ **NAT Passthrough:** Enabled (fw_pt_pptp, fw_pt_l2tp, fw_pt_ipsec = 1)
3. ❌ **dnsmasq.conf.add:** Created but not read by ASUS firmware
4. ❌ **hosts.add:** Created but not read by ASUS firmware
5. ⏳ **Web UI DNS Override:** Not yet configured (requires manual web UI access)

### Files Created on Router
```bash
# SSH to router to verify:
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1

# Check files exist:
cat /jffs/configs/dnsmasq.conf.add
# Output: address=/nas.harbor.fyi/192.168.50.45

cat /jffs/configs/hosts.add
# Output: 192.168.50.45 nas.harbor.fyi
```

**These files exist but are not being read by dnsmasq.** ASUS firmware requires additional configuration to enable custom config reading.

---

## Testing Local DNS Resolution

### Test Current DNS Resolution
```bash
# Should resolve to PUBLIC IP (current behavior):
nslookup nas.harbor.fyi 192.168.50.1
# Returns: 50.47.205.173

# After fix, should resolve to LOCAL IP:
nslookup nas.harbor.fyi 192.168.50.1
# Should return: 192.168.50.45
```

### Test NPM Access
```bash
# Direct to NPM (should work):
curl -I http://192.168.50.45 -H "Host: nas.harbor.fyi"
# Returns: 301 Moved Permanently → https://nas.harbor.fyi/

# Via domain (currently fails from LAN):
curl -I https://nas.harbor.fyi
# Times out due to hairpin NAT issue
```

---

## Recommended Solution

**Best approach for your setup:**

1. **Short-term (Immediate):**
   - Use local IP `https://192.168.50.45` when on LAN
   - Use `https://nas.harbor.fyi` when external
   - OR use Tailscale IP `https://100.85.205.49` always

2. **Long-term (Recommended):**
   - Configure web UI DNS override via DNS Director or DNSFilter
   - This makes `nas.harbor.fyi` work from both LAN and WAN
   - All devices automatically use local IP when on LAN

---

## Alternative: Conditional Access Script

For frequently-used devices, create a script that detects network:

**macOS/Linux Script (`~/.local/bin/nas`):**
```bash
#!/bin/bash
# Auto-detect if on local network
if ping -c 1 -W 1 192.168.50.1 &>/dev/null; then
  # On local network - use local IP
  open "https://192.168.50.45"
else
  # External network - use domain
  open "https://nas.harbor.fyi"
fi
```

Make executable:
```bash
chmod +x ~/.local/bin/nas
```

Usage:
```bash
nas  # Opens correct URL based on network
```

---

## Next Steps

1. ⏳ **Configure via Web UI** (recommended):
   - Login to `https://192.168.50.1:8443`
   - Try DNS Director or DNSFilter
   - Add nas.harbor.fyi → 192.168.50.45

2. ⏳ **Document which method works** for this router model

3. ⏳ **Test from multiple devices** after configuration

4. ⏳ **Update NAS-ACCESS-GUIDE.md** with working solution

---

## Router Details

- **Model:** ASUS GT-AX11000
- **Firmware:** 3.0.0.4.388_24394
- **JFFS:** Enabled
- **SSH:** Port 5855 (key-based auth)
- **Web UI:** https://192.168.50.1:8443
- **Credentials:** sysadmin / swipe4DILEMMA7helpmate@theatre

---

## Resources

- ASUS Router DNS Configuration: https://www.asus.com/support/
- DNSMasq Documentation: http://www.thekelleys.org.uk/dnsmasq/doc.html
- Hairpin NAT Explanation: https://en.wikipedia.org/wiki/Hairpinning

---

**Status:** Documented workarounds provided. Web UI configuration pending.
**Last Updated:** 2025-12-05
