---
name: security-audit
description: Automated security scanning and vulnerability detection for Harbor Homelab
status: active
owner: security
last_reviewed_at: 2025-12-06
tags:
  - security
  - audit
  - scanning
  - vulnerability
dependencies:
  - firewall-manager
  - ssh-hardening
outputs:
  - security-audit-report
  - vulnerability-summary
  - remediation-plan
triggers:
  - run security audit
  - vulnerability scan
  - security posture check
  - compliance audit
  - port scan
  - security review
  - penetration test
---

# Security Audit Skill

Automated security scanning, vulnerability detection, and compliance checking across Harbor Homelab infrastructure.

## Audit Scope

### Systems Audited

| System | Type | IP | Critical Services |
|--------|------|-----|-------------------|
| Proxmox | Hypervisor | 192.168.50.10 | VM management, backups |
| Docker VM | Container host | 192.168.50.149 | All Docker services |
| Router | Network gateway | 192.168.50.1 | NAT, port forwarding |
| NPM | Reverse proxy | Docker VM | TLS termination |

### Security Domains

1. **Network Security**
   - Firewall status and rules
   - Open ports (internal & external)
   - Port forwarding configuration
   - Network segmentation

2. **Access Control**
   - SSH configuration
   - Password policies
   - SSH key management
   - User account security

3. **Service Security**
   - Exposed services
   - TLS/SSL configuration
   - Default credentials
   - Service versions

4. **System Hardening**
   - OS patch level
   - fail2ban status
   - SELinux/AppArmor
   - Unnecessary services

5. **Monitoring & Logging**
   - Log collection
   - Audit trail
   - Intrusion detection
   - Alert configuration

## Vulnerability Classification

### Severity Levels

**CRITICAL (Fix within 24 hours):**
- Firewall disabled on internet-facing system
- Root access with password authentication
- Unencrypted admin interfaces exposed to internet
- Known exploited vulnerabilities (CISA KEV)

**HIGH (Fix within 1 week):**
- Password authentication enabled on SSH
- Missing fail2ban or IDS
- Outdated software with security patches available
- Exposed internal services

**MEDIUM (Fix within 1 month):**
- Weak SSH keys (RSA < 2048)
- Missing security headers
- Unnecessary services running
- Poor password policies

**LOW (Fix opportunistically):**
- Missing security documentation
- Verbose error messages
- No rate limiting
- Missing monitoring

## Audit Workflows

### 1. Network Security Audit

**Port Scanning:**
```bash
# Internal scan (from LAN)
nmap -sV -sC -p- 192.168.50.149 -oN internal-scan.txt

# External scan (from internet)
nmap -sV -sC -p- YOUR_PUBLIC_IP -oN external-scan.txt

# Compare results
diff <(grep open internal-scan.txt | awk '{print $1}') \
     <(grep open external-scan.txt | awk '{print $1}')
```

**Firewall Status:**
```bash
# UFW status
ufw status verbose

# iptables rules
iptables -L -n -v --line-numbers

# Proxmox firewall
pvesh get /cluster/firewall/rules
```

**Port Forward Audit:**
```bash
# From router (if accessible)
iptables -t nat -L PREROUTING -n -v --line-numbers

# Expected format:
# External:443 -> 192.168.50.149:443 (NPM - OK)
# External:80 -> 192.168.50.149:80 (NPM - OK)
# External:??? -> 192.168.50.149:5678 (N8N - ❌ REMOVE)
```

### 2. SSH Security Audit

**Configuration Review:**
```bash
# Check critical settings
grep -E '^(PasswordAuthentication|PermitRootLogin|PubkeyAuthentication|Protocol)' \
  /etc/ssh/sshd_config

# Expected output:
# PasswordAuthentication no  ✅
# PermitRootLogin prohibit-password  ✅
# PubkeyAuthentication yes  ✅
# Protocol 2  ✅
```

**Key Inventory:**
```bash
# Count keys per user
for user in /home/* /root; do
  echo "$(basename $user): $(cat $user/.ssh/authorized_keys 2>/dev/null | wc -l) keys"
done

# Identify weak keys
for user in /home/* /root; do
  awk '{print $1, $NF}' $user/.ssh/authorized_keys 2>/dev/null | \
    grep -E 'ssh-rsa.*2048|ssh-dss' && echo "⚠️ Weak key found in $user"
done
```

**fail2ban Status:**
```bash
# Check if installed
systemctl status fail2ban || echo "❌ fail2ban not installed"

# Check ban statistics
fail2ban-client status sshd 2>/dev/null || echo "❌ fail2ban not configured"
```

### 3. Service Security Audit

**Identify Exposed Services:**
```bash
# Docker services with published ports
docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "PORTS"

# Cross-reference with firewall rules
# Services should be:
# - Behind NPM reverse proxy (443/80 only)
# - LAN-only (192.168.50.0/24)
# - Tailscale-only (100.64.0.0/10)
```

**TLS/SSL Configuration:**
```bash
# Test SSL configuration
testssl.sh https://your-domain.com

# Check certificate expiration
for domain in $(docker exec npm cat /data/nginx/proxy_host/* | grep server_name | awk '{print $2}' | tr -d ';'); do
  echo "$domain: $(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | \
    openssl x509 -noout -enddate)"
done
```

**Default Credentials:**
```bash
# Check for common defaults
# - Admin/admin
# - Root/password
# - Service-specific defaults (Portainer: admin/admin123)

# Automated check (example)
curl -s -u admin:admin http://192.168.50.149:9000/api/status && \
  echo "⚠️ Portainer has default credentials!"
```

### 4. System Hardening Audit

**Patch Level:**
```bash
# Debian/Ubuntu
apt list --upgradable

# Check for security updates
apt list --upgradable | grep -i security
```

**Unnecessary Services:**
```bash
# List all running services
systemctl list-units --type=service --state=running

# Check for common unnecessary services
for svc in telnet rsh rlogin vsftpd; do
  systemctl is-active $svc 2>/dev/null && echo "⚠️ $svc is running"
done
```

**Security Modules:**
```bash
# AppArmor status
aa-status

# SELinux status
sestatus 2>/dev/null || echo "SELinux not installed"
```

### 5. Logging & Monitoring Audit

**Log Collection:**
```bash
# Check syslog
systemctl status rsyslog

# Check auditd
systemctl status auditd || echo "❌ auditd not installed"

# Log rotation
ls -lh /var/log/*.log | awk '{print $5, $9}' | grep -E '[0-9]+G' && \
  echo "⚠️ Large log files found"
```

**Monitoring Coverage:**
```bash
# Netdata status
systemctl status netdata

# Check monitored services
curl -s http://192.168.50.149:19999/api/v1/charts | jq '.charts | keys[]'
```

## Audit Report Format

### Executive Summary
```
Security Audit Report - Harbor Homelab
Date: 2025-12-06
Auditor: Claude Code Security Audit Skill

Overall Risk: HIGH
Critical Issues: 2
High Issues: 3
Medium Issues: 5
Low Issues: 8

Priority Actions:
1. Enable UFW on Docker VM (CRITICAL)
2. Install fail2ban on all systems (HIGH)
3. Disable SSH password authentication (HIGH)
```

### Detailed Findings

**Format:**
```
[CRITICAL-001] UFW Disabled on Docker VM
  Affected: 192.168.50.149
  Impact: All Docker services exposed without firewall filtering
  Evidence: `ufw status` returns "inactive"
  Remediation: Run `enable-ufw-safe.sh` to safely enable UFW
  Timeline: Fix within 24 hours

[HIGH-002] SSH Password Authentication Enabled
  Affected: All systems
  Impact: Brute-force attacks possible, credential stuffing risk
  Evidence: `PasswordAuthentication yes` in /etc/ssh/sshd_config
  Remediation: Run `disable-password-auth.sh` after verifying key access
  Timeline: Fix within 1 week
```

### Remediation Plan

**Priority Matrix:**
```
Week 1:
  [x] Enable UFW on Docker VM
  [x] Install fail2ban
  [ ] Disable SSH password auth

Week 2-4:
  [ ] Rotate weak SSH keys
  [ ] Remove unnecessary port forwards
  [ ] Enable auditd logging

Ongoing:
  [ ] Monthly vulnerability scans
  [ ] Quarterly access review
  [ ] Annual penetration test
```

## Automation

### Daily Security Scan

**Cron Job:**
```cron
0 2 * * * /usr/local/bin/security-scan.sh | tee -a /var/log/security-audit.log
```

**Quick Scan Checks:**
- UFW status (must be active)
- fail2ban ban count
- Failed SSH login attempts (last 24h)
- New open ports
- Certificate expiration (< 30 days)

### Weekly Deep Scan

**Comprehensive Audit:**
- Full port scan (internal + external)
- SSH key inventory
- Service version check
- Security update availability
- Log analysis

### Monthly Compliance Scan

**Full Security Audit:**
- All domains (network, access, service, system, logging)
- Generate detailed report
- Update remediation plan
- Review with stakeholders

## Scripts

Located in: `infrastructure-ops/scripts/security/`

| Script | Purpose | Frequency |
|--------|---------|-----------|
| `security-scan.sh` | Quick daily checks | Daily (cron) |
| `port-scan.sh` | Internal/external port scan | Weekly |
| `ssh-audit.sh` | SSH configuration audit | Weekly |
| `compliance-audit.sh` | Full security audit | Monthly |
| `vulnerability-scan.sh` | CVE scanning | Weekly |

## Commands

- `/security-status` - Quick security posture check
- `/security-audit-full` - Run comprehensive audit
- `/security-report` - Generate audit report

## Monitoring Integration

**Netdata Alarms:**
```yaml
# /etc/netdata/health.d/security.conf
alarm: ufw_disabled
  on: system.active_processes
  lookup: average -1m unaligned of ufw
  units: processes
  every: 1m
  warn: $this == 0
  info: UFW firewall is not running
```

**Slack Alerts:**
```bash
# Send critical findings to Slack
if [ $CRITICAL_COUNT -gt 0 ]; then
  curl -X POST https://hooks.slack.com/services/YOUR/WEBHOOK \
    -d "{\"text\":\"🚨 $CRITICAL_COUNT critical security issues found!\"}"
fi
```

## Compliance Frameworks

**CIS Benchmark Coverage:**
- 2.2.6: Disable X11 Forwarding
- 5.2.4: Disable SSH Root Login
- 5.2.10: Disable SSH Password Authentication
- 5.2.15: Configure SSH Warning Banner

**NIST 800-53 Controls:**
- AC-2: Account Management
- SC-7: Boundary Protection
- SI-2: Flaw Remediation
- AU-12: Audit Generation

## References

- CIS Benchmarks: https://www.cisecurity.org/cis-benchmarks
- OWASP Testing Guide: https://owasp.org/www-project-web-security-testing-guide/
- NIST NVD: https://nvd.nist.gov/
- OpenSCAP: https://www.open-scap.org/
