# Router Firewall Manager Skill

**Purpose:** Advanced firewall rule management, port forwarding automation, and network security for ASUS router.

**Scope:**
- Firewall rule creation and management
- Port forward automation
- IP filtering and access control
- Security monitoring and alerts

---

## Prerequisites

**Required Environment Variables:**
```bash
# Uses same env vars as asus-router-manager
ASUS_ROUTER_IP=192.168.50.1
ASUS_ROUTER_SSH_PORT=5855
ASUS_ROUTER_SSH_KEY=~/.ssh/id_ed25519_asus_router_new
ASUS_ROUTER_USER=sysadmin
```

**Dependencies:**
- **asus-router-manager** skill (base router management)

---

## Core Capabilities

### 1. Firewall Rule Management
- List active firewall rules
- Add/remove firewall rules
- IP-based access control
- Protocol-specific filtering

### 2. Port Forward Automation
- Bulk port forward operations
- Template-based port forward configs
- Export/import port forward rules
- Validation and conflict detection

### 3. Security Monitoring
- Failed login attempt tracking
- Port scan detection
- Intrusion prevention monitoring
- Security event logging

### 4. Access Control Lists (ACL)
- Whitelist/blacklist IP ranges
- Geographic IP filtering
- MAC address filtering
- Time-based access rules

---

## Usage Examples

### List Firewall Rules
```bash
bash infrastructure-ops/scripts/hardware/router-firewall-list.sh
```

**Output:**
```
Active Firewall Rules:
======================
1. ACCEPT - 192.168.50.0/24 → ANY (LAN to WAN)
2. DROP   - ANY → 192.168.50.1:8443 (Block external router admin)
3. ACCEPT - 100.64.0.0/10 → ANY (Tailscale)
4. DROP   - ANY → 192.168.50.251:22 (Block external NAS SSH)
```

### Add Whitelist IP
```bash
bash infrastructure-ops/scripts/hardware/router-firewall-add.sh \
  --rule "ACCEPT" \
  --source "203.0.113.0/24" \
  --dest "192.168.50.45:443" \
  --protocol "TCP" \
  --comment "Office network to NPM"
```

### Bulk Port Forward Setup
```bash
# From template file
bash infrastructure-ops/scripts/hardware/router-port-forward-bulk.sh \
  --config infrastructure-ops/configs/port-forwards.json
```

**Template: `port-forwards.json`**
```json
{
  "port_forwards": [
    {
      "name": "NPM-HTTPS",
      "external_port": 443,
      "internal_ip": "192.168.50.45",
      "internal_port": 443,
      "protocol": "TCP",
      "enabled": true
    },
    {
      "name": "NPM-HTTP",
      "external_port": 80,
      "internal_ip": "192.168.50.45",
      "internal_port": 80,
      "protocol": "TCP",
      "enabled": true
    }
  ]
}
```

---

## ASUS Firewall NVRAM Keys

### Firewall Status
```bash
# Enable/disable firewall
nvram get fw_enable_x              # 1=enabled, 0=disabled

# Firewall log
nvram get fw_log_x                 # 1=enabled, 0=disabled
```

### Port Forwarding
```bash
# Virtual server (port forward) rules
nvram get vts_rulelist

# Format: <name>port1>ip>port2>proto>
# Example: NPM-HTTPS>443>192.168.50.45>443>tcp>
```

### URL/Keyword Filtering
```bash
nvram get url_enable_x             # URL filter enabled
nvram get keyword_enable_x         # Keyword filter enabled
nvram get url_rulelist             # URL filter rules
```

### MAC Filtering
```bash
nvram get macfilter_enable_x       # MAC filter enabled
nvram get macfilter_rulelist       # MAC filter rules
```

---

## Security Configurations

### Recommended Firewall Rules

**1. Block External Router Admin Access**
```bash
# Drop all WAN traffic to router admin port
iptables -I INPUT -i eth0 -p tcp --dport 8443 -j DROP
```

**2. Allow Tailscale Only**
```bash
# Accept traffic from Tailscale network
iptables -I INPUT -s 100.64.0.0/10 -j ACCEPT
```

**3. Rate Limit SSH**
```bash
# Limit SSH connection attempts (prevent brute force)
iptables -I INPUT -p tcp --dport 5855 -m state --state NEW -m recent --set
iptables -I INPUT -p tcp --dport 5855 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
```

**4. Drop Invalid Packets**
```bash
# Drop packets with invalid state
iptables -I INPUT -m state --state INVALID -j DROP
```

---

## Port Forward Management

### Current Active Forwards
```
External Port → Internal IP:Port
=================================
80 → 192.168.50.45:80 (NPM HTTP)
443 → 192.168.50.45:443 (NPM HTTPS)
```

### Port Forward Best Practices

**DO:**
- ✅ Use descriptive names (NPM-HTTPS, not "Rule1")
- ✅ Document purpose in comments
- ✅ Use static IPs for internal targets
- ✅ Enable only required protocols (TCP vs UDP)
- ✅ Review quarterly and remove unused

**DON'T:**
- ❌ Forward all ports (1-65535)
- ❌ Use UPnP (auto port forwarding)
- ❌ Forward router admin ports (8443, 22, 5855)
- ❌ Forward without firewall rules
- ❌ Use dynamic DHCP IPs as targets

---

## Security Monitoring

### Failed Login Detection
```bash
# Check router logs for failed SSH attempts
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 \
  "cat /var/log/messages | grep 'Failed password'"
```

### Port Scan Detection
```bash
# Check for port scan patterns in firewall logs
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 \
  "cat /var/log/firewall | grep 'SYN scan'"
```

### Active Connections
```bash
# View current connections through router
ssh -i ~/.ssh/id_ed25519_asus_router_new -p 5855 sysadmin@192.168.50.1 \
  "cat /proc/net/nf_conntrack | grep ESTABLISHED"
```

---

## Automation Scripts

### Daily Security Audit
```bash
# Script: infrastructure-ops/scripts/hardware/router-security-audit.sh
# - Check for new port forwards
# - Review failed login attempts
# - Detect unusual traffic patterns
# - Alert on security events
```

### Port Forward Validation
```bash
# Script: infrastructure-ops/scripts/hardware/router-port-forward-validate.sh
# - Verify all forwards have valid internal IPs
# - Check for conflicts (duplicate ports)
# - Test connectivity
# - Generate report
```

---

## Integration with Other Skills

### NPM (Nginx Proxy Manager)
```bash
# When adding new service to NPM, add port forward:
1. Add service to NPM (proxy host)
2. Add port forward on router (if external access needed)
3. Update DNS (Cloudflare)
4. Test external access
```

### Tailscale Integration
```bash
# Allow Tailscale IPs through firewall
# No port forwarding needed for Tailscale-only services
iptables -I INPUT -s 100.64.0.0/10 -j ACCEPT
```

---

## Troubleshooting

### Port Forward Not Working
```bash
# 1. Check rule exists
nvram get vts_rulelist | grep 443

# 2. Check internal IP is correct
ping 192.168.50.45

# 3. Test port is open on target
nc -zv 192.168.50.45 443

# 4. Check firewall isn't blocking
iptables -L -n | grep 443

# 5. Test from external network
curl -I https://YOUR_PUBLIC_IP:443
```

### Firewall Blocking Legitimate Traffic
```bash
# Check firewall logs
cat /var/log/firewall | tail -50

# Temporarily disable firewall (testing only!)
nvram set fw_enable_x=0
service restart_firewall

# Re-enable after testing
nvram set fw_enable_x=1
service restart_firewall
```

---

## Related Skills

- **asus-router-manager** - Base router management
- **docker-network-manager** - Container networking
- **cloudflare-dns** - DNS management

---

## Scripts Location

All firewall management scripts are in:
```
infrastructure-ops/scripts/hardware/
├── router-firewall-list.sh          # List firewall rules
├── router-firewall-add.sh           # Add firewall rule
├── router-firewall-remove.sh        # Remove firewall rule
├── router-port-forward-bulk.sh      # Bulk port forward operations
├── router-security-audit.sh         # Security audit
└── router-port-forward-validate.sh  # Validate port forwards
```

---

**Status:** Ready for production use
**Last Updated:** 2025-12-06
**Maintainer:** Claude Code Infrastructure Team
