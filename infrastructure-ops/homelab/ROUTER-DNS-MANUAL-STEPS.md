# ASUS Router DNS Override - Manual Configuration

## Why You Need This

**Problem:** When accessing `nas.harbor.fyi` from your local network, you get:
- `ERR_SSL_UNRECOGNIZED_NAME_ALERT`
- Timeouts or connection failures

**Root Cause:** Your device resolves `nas.harbor.fyi` to the public WAN IP (50.47.212.131), causing hairpin NAT issues.

**Solution:** Configure router to override DNS for `nas.harbor.fyi` to resolve to local NPM IP (192.168.50.45) when queried from LAN.

---

## Method 1: DNS Director (Recommended - If Available)

### Step 1: Login to Router
```
URL: https://router.asus.com:8443
Username: sysadmin
Password: swipe4DILEMMA7helpmate@theatre
```

### Step 2: Navigate to DNS Director
1. Click **Advanced Settings** (left sidebar)
2. Click **WAN** section
3. Look for **DNS Director** tab
   - If not visible, try **LAN** → **DNS Director**
   - Or check **AiProtection** → **DNS Filter**

### Step 3: Add DNS Override Rule
```
Domain/Hostname: nas.harbor.fyi
Target IP: 192.168.50.45
Client: All (or leave blank)
```

### Step 4: Apply & Save
- Click **Add** or **+**
- Click **Apply** at bottom
- Wait ~30 seconds for changes to take effect

### Step 5: Verify
```bash
nslookup nas.harbor.fyi 192.168.50.1
# Should return: 192.168.50.45 (not public IP)
```

---

## Method 2: AiProtection DNS Filter (If DNS Director Not Available)

### Step 1: Navigate to AiProtection
1. Advanced Settings → **AiProtection**
2. Click **DNS Filter** tab

### Step 2: Enable Custom DNS
1. Enable DNS Filter: **ON**
2. Filter Mode: **Router**
3. DNS Server: **Custom**

### Step 3: Add Custom DNS Entry
This method requires:
- Running a local DNS server (like Pi-hole or AdGuard Home)
- OR using DNSMasq custom config (already attempted via CLI)

**If this option doesn't allow custom domain overrides, use Method 3.**

---

## Method 3: LAN DHCP DNS Settings (Alternative)

### Step 1: Navigate to LAN
1. Advanced Settings → **LAN**
2. Click **DHCP Server** tab

### Step 2: Custom DNS Settings
Look for:
- **DNS Server 1**: 192.168.50.1 (router itself)
- **Advertise router's IP in addition to user-specified DNS**: YES

**Note:** This method alone won't override specific domains. You still need dnsmasq custom config (which we already created via CLI).

---

## Method 4: Enable Custom Scripts (CLI - Most Reliable)

We already created the scripts via CLI. To make them work:

### Step 1: Enable JFFS Custom Scripts (If Not Already)
```bash
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1

# Check if enabled
nvram get jffs2_scripts

# If returns 0, enable:
nvram set jffs2_scripts=1
nvram commit

# Verify files exist
ls -la /jffs/scripts/dnsmasq.postconf
ls -la /jffs/configs/dnsmasq.conf.add
```

### Step 2: Reboot Router (Required for Scripts to Take Effect)
```bash
# Via CLI
reboot

# OR via Web UI
Administration → System → Reboot
```

### Step 3: Verify After Reboot
```bash
nslookup nas.harbor.fyi 192.168.50.1
# Should return: 192.168.50.45
```

---

## Verification & Testing

### Test 1: DNS Resolution
```bash
# From local network
nslookup nas.harbor.fyi 192.168.50.1
# Expected: 192.168.50.45

# From external DNS
nslookup nas.harbor.fyi 8.8.8.8
# Expected: 50.47.212.131 (public IP)
```

### Test 2: HTTPS Access
```bash
# Should now work without SSL error
curl -I https://nas.harbor.fyi
# Expected: HTTP 200 or redirect to login
```

### Test 3: Browser Access
```
Open: https://nas.harbor.fyi
Expected: QNAP NAS login page (no SSL errors)
```

---

## Troubleshooting

### Still Getting Public IP?
1. **Clear DNS cache on your device:**
   ```bash
   # macOS
   sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder

   # Windows
   ipconfig /flushdns

   # Linux
   sudo systemd-resolve --flush-caches
   ```

2. **Check router DNS server:**
   ```bash
   cat /etc/resolv.conf
   # Should show: nameserver 192.168.50.1
   ```

3. **Restart dnsmasq on router:**
   ```bash
   ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1
   service restart_dnsmasq
   ```

### SSL Errors Still Happening?
If DNS is correct (192.168.50.45) but SSL still fails:
- NPM might not have the SSL certificate for nas.harbor.fyi
- Check NPM (192.168.50.45:81) → Proxy Hosts → nas.harbor.fyi → Ensure "Force SSL" enabled
- Verify Let's Encrypt certificate is valid

---

## Summary of What Should Happen

**From LAN (Local Network):**
```
Your Device → Router DNS (192.168.50.1) → Override: nas.harbor.fyi = 192.168.50.45
→ NPM (192.168.50.45) → QNAP NAS (192.168.50.251)
```

**From WAN (External Network):**
```
Your Device → Public DNS (8.8.8.8) → Porkbun: nas.harbor.fyi = 50.47.212.131
→ Router WAN → Port Forward → NPM (192.168.50.45) → QNAP NAS (192.168.50.251)
```

**Result:** `nas.harbor.fyi` works universally from both local and external networks! ✅

---

**Status:** Scripts created via CLI. **Next step:** Either configure via Web UI (Method 1/2) or reboot router to activate scripts (Method 4).
