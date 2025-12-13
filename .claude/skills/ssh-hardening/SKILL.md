---
name: ssh-hardening
description: SSH security automation - disable password auth, fail2ban, key management
status: active
owner: security
last_reviewed_at: 2025-12-06
tags:
  - security
  - ssh
  - fail2ban
  - authentication
dependencies:
  - firewall-manager
outputs:
  - ssh-audit-report
  - key-inventory
triggers:
  - harden ssh
  - disable password auth
  - install fail2ban
  - ssh key audit
  - rotate ssh keys
  - ssh security
  - configure fail2ban
---

# SSH Hardening Skill

Automates SSH security configuration, key management, and intrusion prevention across Harbor Homelab.

## Critical Vulnerabilities (From Audit)

| Issue | Systems Affected | Severity | Status |
|-------|------------------|----------|--------|
| Password auth enabled | All systems | HIGH | ❌ NOT FIXED |
| No fail2ban | All systems | HIGH | ❌ NOT INSTALLED |
| 11+ SSH keys | All systems | MEDIUM | ⚠️ NEEDS AUDIT |
| Root login allowed | Unknown | MEDIUM | ⚠️ NEEDS AUDIT |

## Security Baseline

**Target Configuration:**
```sshd_config
# Authentication
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password  # Key-only for root

# Security
Protocol 2
PermitEmptyPasswords no
MaxAuthTries 3
MaxSessions 5

# Performance
UseDNS no
X11Forwarding no

# Logging
SyslogFacility AUTH
LogLevel VERBOSE
```

## Workflows

### 1. SSH Key Audit

**Inventory All Keys:**
```bash
# Per-user authorized_keys
for user in /home/*; do
  echo "=== $(basename $user) ==="
  cat "$user/.ssh/authorized_keys" 2>/dev/null | \
    awk '{print $NF}' | sort | uniq
done

# Root keys
cat /root/.ssh/authorized_keys 2>/dev/null | \
  awk '{print $NF}' | sort | uniq
```

**Key Health Checks:**
- Identify weak keys (RSA < 2048, DSA)
- Find duplicate keys across users
- Detect keys without comments
- Check for expired/revoked keys

**Output Format:**
```
User: adam
  - ssh-ed25519 ... adam@macbook (Good - Ed25519)
  - ssh-rsa 4096 ... adam@linux (Good - RSA 4096)

User: root
  - ssh-rsa 2048 ... backup@server (⚠️ Weak - RSA 2048)
  - ssh-rsa 4096 ... ansible@tower (Good - RSA 4096)

Summary:
  Total: 11 keys
  Weak: 1 (RSA 2048)
  Duplicates: 0
  Missing comments: 0
```

### 2. Fail2Ban Installation

**Purpose:**
- Block brute-force SSH attempts
- Auto-ban after 5 failed logins
- 10-minute ban duration (configurable)

**Installation:**
```bash
# Debian/Ubuntu
apt-get update
apt-get install -y fail2ban

# Enable and start
systemctl enable fail2ban
systemctl start fail2ban
```

**Configuration (`/etc/fail2ban/jail.local`):**
```ini
[DEFAULT]
bantime = 10m
findtime = 10m
maxretry = 5
destemail = alerts@aienablement.academy
sendername = Harbor-Fail2Ban
action = %(action_mwl)s  # Ban + email with logs

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 3  # Stricter for SSH
bantime = 1h  # Longer ban for SSH
```

**Testing:**
```bash
# Check status
fail2ban-client status sshd

# Manually ban/unban (testing)
fail2ban-client set sshd banip 1.2.3.4
fail2ban-client set sshd unbanip 1.2.3.4

# View current bans
fail2ban-client status
```

### 3. Password Authentication Removal

**⚠️ CRITICAL: Only do this after verifying key-based login works!**

**Pre-flight Checks:**
```bash
# 1. Verify you have a working SSH key
ssh -i ~/.ssh/id_ed25519 user@192.168.50.149 "echo 'Key auth works'"

# 2. Verify key is in authorized_keys
ssh user@192.168.50.149 "cat ~/.ssh/authorized_keys | grep -q '$(cat ~/.ssh/id_ed25519.pub | awk "{print \$2}")' && echo 'Key found' || echo 'KEY MISSING!'"

# 3. Open backup session
# Keep one SSH session open while making changes!
```

**Disable Password Auth:**
```bash
# Backup current config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# Update config
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config

# Test config before restart
sshd -t

# If test passes, restart
systemctl restart sshd

# Verify in NEW terminal (keep backup session open!)
ssh user@192.168.50.149
```

**Rollback Plan:**
```bash
# If locked out, from Proxmox console:
cp /etc/ssh/sshd_config.backup.$(date +%Y%m%d) /etc/ssh/sshd_config
systemctl restart sshd
```

### 4. Root Login Restrictions

**Best Practice: Disable root SSH entirely**
```bash
# In /etc/ssh/sshd_config
PermitRootLogin no
```

**Alternative: Key-only root access**
```bash
# In /etc/ssh/sshd_config
PermitRootLogin prohibit-password
```

**Force sudo for all admin tasks:**
```bash
# Add admin user to sudo group
usermod -aG sudo adam

# Verify sudo access
sudo -l -U adam
```

## Scripts

Located in: `infrastructure-ops/scripts/security/`

| Script | Purpose | Safety Level |
|--------|---------|--------------|
| `ssh-audit.sh` | Audit keys and config | Read-only |
| `setup-fail2ban.sh` | Install fail2ban | Safe |
| `disable-password-auth.sh` | Remove password auth | ⚠️ RISKY - Interactive |
| `ssh-key-rotation.sh` | Rotate SSH keys | ⚠️ RISKY - Backup first |
| `ssh-config-harden.sh` | Apply security baseline | ⚠️ RISKY - Test first |

## Commands

- `/ssh-keys-audit` - Full key inventory
- `/ssh-harden-system <host>` - Apply security baseline
- `/ssh-fail2ban-status` - Check fail2ban stats

## Monitoring

**Daily Checks:**
- Failed SSH login attempts
- New SSH keys added
- Password auth re-enabled (drift detection)
- Fail2ban ban rate

**Alerts:**
- 10+ failed logins in 1 hour (brute force)
- Password auth enabled (config drift)
- fail2ban service down
- Root SSH login detected

## SSH Login Notifications

**Real-time alerts on successful SSH logins:**

**PAM Integration (`/etc/pam.d/sshd`):**
```bash
# Add after authentication
session optional pam_exec.so /usr/local/bin/ssh-login-alert.sh
```

**Alert Script (`/usr/local/bin/ssh-login-alert.sh`):**
```bash
#!/bin/bash
# Send alert on SSH login
echo "SSH Login: $PAM_USER from $PAM_RHOST on $(hostname) at $(date)" | \
  curl -X POST -H 'Content-Type: application/json' \
  -d "{\"text\":\"$(cat -)\"}" \
  https://hooks.slack.com/services/YOUR/WEBHOOK/HERE
```

## Key Rotation Strategy

**Frequency:**
- Personal keys: 1 year
- Service keys (Ansible, backup): 6 months
- Compromised keys: Immediate rotation

**Rotation Process:**
1. Generate new key pair
2. Add new public key to authorized_keys
3. Test new key works
4. Remove old key from authorized_keys
5. Update key in password manager
6. Revoke old key (add to revocation list)

## Compliance

**Standards Met:**
- CIS Benchmark: Disable password authentication
- NIST 800-53: Multi-factor authentication (key + passphrase)
- PCI-DSS: No shared/default credentials

**Audit Questions:**
1. Is password auth disabled? ❌ NO (CRITICAL)
2. Is fail2ban installed? ❌ NO (CRITICAL)
3. Are SSH keys audited regularly? ❌ NO
4. Is root SSH login restricted? ⚠️ UNKNOWN
5. Are successful logins monitored? ❌ NO

## Integration

**Pre-requisites:**
- Working SSH key authentication
- Backup access method (Proxmox console)
- Email/Slack for alerts

**Dependencies:**
- fail2ban package
- PAM for login alerts
- sshd version 7.0+

## References

- SSH Hardening Guide: https://www.ssh.com/academy/ssh/sshd_config
- fail2ban Documentation: https://www.fail2ban.org/wiki/index.php/Main_Page
- CIS SSH Benchmark: https://www.cisecurity.org/
