---
name: firewall-manager
description: UFW/iptables management with safe SSH rules and multi-system coordination
status: active
owner: security
last_reviewed_at: 2025-12-06
tags:
  - security
  - firewall
  - ufw
  - iptables
dependencies:
  - ssh-hardening
outputs:
  - firewall-audit-report
triggers:
  - enable firewall
  - configure ufw
  - firewall rules
  - block external access
  - lan only access
  - firewall audit
  - port forwarding rules
---

# Firewall Manager Skill

Manages firewall configurations across Harbor Homelab infrastructure with SSH-safe rule management.

## Critical Priorities

1. **NEVER lock yourself out** - Always allow SSH before enabling firewall
2. **Defense in depth** - Multiple firewall layers (router, Proxmox, VM-level)
3. **Minimal exposure** - Only allow required services
4. **Audit trail** - Log all firewall changes

## Systems Under Management

| System | IP | Firewall | Status | Priority |
|--------|-----|----------|--------|----------|
| Docker VM | 192.168.50.149 | UFW | ❌ DISABLED | CRITICAL |
| Proxmox | 192.168.50.10 | Proxmox FW | ✅ Active | Good |
| Router | 192.168.50.1 | iptables | ⚠️ Unknown | Audit |

## Workflow

### 1. Docker VM UFW Re-enable (CRITICAL)

**Problem:** UFW disabled, all ports exposed on Docker host

**Solution:**
```bash
# Phase 1: SSH Protection (MUST DO FIRST)
ufw allow 22/tcp comment 'SSH - NEVER REMOVE'
ufw allow from 192.168.50.0/24 to any port 22

# Phase 2: Essential Services
ufw allow 80/tcp comment 'HTTP - NPM'
ufw allow 443/tcp comment 'HTTPS - NPM'
ufw allow from 192.168.50.0/24 to any port 81 comment 'NPM Admin - LAN only'

# Phase 3: Docker Integration
ufw default allow routed  # Allow Docker container networking

# Phase 4: Enable (SAFE NOW)
ufw --force enable
systemctl enable ufw
```

### 2. Service-Specific Rules

**N8N (Port 5678) - SHOULD NOT BE INTERNET-FACING:**
```bash
# Block external access
ufw deny 5678/tcp comment 'N8N - Use Tailscale/VPN only'

# Allow only from LAN/Tailscale
ufw allow from 192.168.50.0/24 to any port 5678
ufw allow from 100.64.0.0/10 to any port 5678  # Tailscale CGNAT range
```

**Internal Services (should be LAN-only):**
```bash
# Portainer
ufw allow from 192.168.50.0/24 to any port 9000

# Netdata
ufw allow from 192.168.50.0/24 to any port 19999

# Qdrant
ufw allow from 192.168.50.0/24 to any port 6333
```

### 3. Router Port Forward Audit

**Current Forwards (10 active):**
- Identify which services NEED internet exposure
- Remove unnecessary forwards
- Add rate limiting where possible

**Safe Patterns:**
```
External 443 -> NPM (443) -> Internal services (TLS required)
External 80 -> NPM (80) -> Redirect to 443
```

**Unsafe Patterns:**
```
❌ Direct port forwards to Docker VM services
❌ Unencrypted admin interfaces (NPM port 81)
❌ Database ports (PostgreSQL, Redis, etc.)
```

## Scripts

Located in: `infrastructure-ops/scripts/security/`

| Script | Purpose | Safety |
|--------|---------|--------|
| `enable-ufw-safe.sh` | Re-enable UFW with SSH protection | SSH-safe |
| `firewall-audit.sh` | Show all firewall rules | Read-only |
| `block-service-external.sh <port>` | Block external access to service | Reversible |
| `allow-lan-only.sh <port> <service>` | LAN-only access | Safe |

## Commands

- `/firewall-rules` - Show rules across all systems
- `/firewall-enable-docker` - Safe UFW re-enable for Docker VM
- `/firewall-audit` - Full security audit

## Monitoring

**Daily Checks:**
- UFW status on Docker VM
- Unauthorized firewall changes
- New port forwards on router
- Failed connection attempts

**Alerts:**
- UFW disabled (CRITICAL)
- New port forward added
- High rate of blocked connections

## Recovery Procedures

**If Locked Out:**
```bash
# From Proxmox console (not SSH):
ufw disable
ufw allow 22/tcp
ufw --force enable
```

**Reset to Safe Defaults:**
```bash
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow from 192.168.50.0/24  # Allow all LAN traffic
ufw --force enable
```

## Integration

**Pre-requisites:**
- SSH access to all systems
- Root/sudo privileges
- Backup of current firewall rules

**Testing:**
```bash
# Test before enabling
ufw --dry-run enable

# Verify SSH still works after enable
ssh -o ConnectTimeout=5 user@192.168.50.149 "echo 'SSH OK'"
```

## Compliance

**Security Standards:**
- CIS Benchmark: UFW enabled on all Linux systems
- NIST: Deny-by-default firewall policy
- PCI-DSS: Network segmentation between DMZ and internal

**Audit Questions:**
1. Is UFW enabled on Docker VM? ❌ NO (CRITICAL)
2. Are admin interfaces LAN-only? ⚠️ PARTIAL
3. Are unnecessary ports blocked? ⚠️ NEEDS AUDIT
4. Is there a firewall change log? ❌ NO

## References

- UFW Documentation: `man ufw`
- Docker UFW Integration: https://github.com/chaifeng/ufw-docker
- Proxmox Firewall: https://pve.proxmox.com/wiki/Firewall
