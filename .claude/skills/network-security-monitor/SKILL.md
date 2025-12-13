---
name: network-security-monitor
description: Real-time monitoring for unauthorized access attempts and security events
status: active
owner: security
last_reviewed_at: 2025-12-06
tags:
  - security
  - monitoring
  - intrusion-detection
  - alerts
dependencies:
  - firewall-manager
  - ssh-hardening
  - security-audit
outputs:
  - security-events-log
  - intrusion-alerts
---

# Network Security Monitor Skill

Real-time security event monitoring, intrusion detection, and automated alerting for Harbor Homelab.

## Monitoring Scope

### Event Categories

1. **Authentication Events**
   - SSH login attempts (success/failure)
   - sudo command execution
   - User account changes
   - Password changes

2. **Network Events**
   - Unusual port scanning
   - New connections from unknown IPs
   - High connection rates
   - Firewall rule changes

3. **Service Events**
   - Service start/stop/restart
   - Container creation/removal
   - Process spawning
   - File system changes (critical paths)

4. **Security Events**
   - fail2ban bans/unbans
   - TLS certificate errors
   - Failed API authentication
   - Privilege escalation attempts

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Event Sources                          │
├─────────────────────────────────────────────────────────┤
│ /var/log/auth.log    │ SSH, sudo, authentication        │
│ /var/log/syslog      │ System events, services          │
│ Docker events API    │ Container lifecycle              │
│ UFW logs             │ Firewall blocks                  │
│ fail2ban logs        │ Intrusion attempts               │
│ Netdata metrics      │ Performance anomalies            │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Event Processing                        │
├─────────────────────────────────────────────────────────┤
│ • Parse logs (regex/JSON)                               │
│ • Correlate events (time/source)                        │
│ • Classify severity (INFO/WARN/CRITICAL)                │
│ • Deduplicate (prevent alert fatigue)                   │
└─────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────┐
│                  Alert Channels                          │
├─────────────────────────────────────────────────────────┤
│ Slack/Discord        │ Real-time critical alerts        │
│ Email                │ Daily summaries, reports         │
│ Netdata              │ Dashboard visualization          │
│ AgentDB/Cortex       │ Persistent event storage         │
└─────────────────────────────────────────────────────────┘
```

## Detection Rules

### SSH Intrusion Detection

**Failed Login Patterns:**
```bash
# 5+ failed logins from same IP in 10 minutes
awk '/Failed password/ {print $1, $2, $3, $(NF-3)}' /var/log/auth.log | \
  sort | uniq -c | awk '$1 >= 5 {print "⚠️ Brute force from " $NF " (" $1 " attempts)"}'

# Dictionary attack (multiple usernames from same IP)
awk '/Failed password/ {print $(NF-3), $(NF-5)}' /var/log/auth.log | \
  sort | uniq | cut -d' ' -f1 | uniq -c | \
  awk '$1 >= 3 {print "⚠️ Dictionary attack from IP (tried " $1 " different usernames)"}'
```

**Successful Login Anomalies:**
```bash
# Login from new/unknown IP
# (Compare against whitelist of known IPs)
awk '/Accepted publickey/ {print $(NF-3)}' /var/log/auth.log | \
  sort -u > /tmp/recent-ips.txt

# Alert if IP not in whitelist
grep -v -F -f /etc/security/known-ips.txt /tmp/recent-ips.txt | \
  while read ip; do
    echo "⚠️ SSH login from unknown IP: $ip"
  done
```

**Privilege Escalation:**
```bash
# Unusual sudo usage
awk '/sudo.*COMMAND/ {print $1, $2, $5, $6, $NF}' /var/log/auth.log | \
  grep -v -E 'systemctl|apt|docker' | \
  tail -n 20  # Recent unusual sudo commands
```

### Network Intrusion Detection

**Port Scanning:**
```bash
# Detect SYN scan (many connections to different ports)
awk '/UFW BLOCK/ {print $12, $16}' /var/log/syslog | \
  sed 's/SRC=//; s/DPT=//' | \
  awk '{print $1}' | sort | uniq -c | \
  awk '$1 >= 10 {print "⚠️ Port scan from " $2 " (" $1 " ports)"}'
```

**Connection Flood:**
```bash
# Detect high connection rate from single IP
ss -tn | awk '{print $5}' | cut -d: -f1 | sort | uniq -c | \
  awk '$1 >= 50 {print "⚠️ Connection flood from " $2 " (" $1 " connections)"}'
```

**Unusual Outbound Connections:**
```bash
# Detect connections to unusual ports (potential C2)
ss -tn | awk '{print $4}' | cut -d: -f2 | sort | uniq -c | \
  grep -v -E ':(80|443|22|3306|5432|6379)$' | \
  awk '{print "⚠️ Unusual outbound connection on port " $2 " (" $1 " connections)"}'
```

### Service Security Monitoring

**Docker Security Events:**
```bash
# Monitor privileged container creation
docker events --filter 'event=create' --filter 'type=container' --format '{{json .}}' | \
  jq -r 'select(.Actor.Attributes.privileged=="true") |
    "⚠️ Privileged container created: \(.Actor.Attributes.name)"'

# Monitor host network mode (security risk)
docker events --filter 'event=create' --filter 'type=container' --format '{{json .}}' | \
  jq -r 'select(.Actor.Attributes."net"=="host") |
    "⚠️ Host network container created: \(.Actor.Attributes.name)"'
```

**File Integrity Monitoring:**
```bash
# Monitor critical configuration files
inotifywait -m -e modify,create,delete,move \
  /etc/ssh/sshd_config \
  /etc/ufw/*.rules \
  /etc/fail2ban/*.conf \
  --format '%T %w %e %f' --timefmt '%Y-%m-%d %H:%M:%S' | \
  while read timestamp path event file; do
    echo "⚠️ Security file modified: $path$file at $timestamp"
  done
```

**TLS Certificate Monitoring:**
```bash
# Check certificate expiration
for domain in $(cat /etc/ssl/monitored-domains.txt); do
  expiry=$(echo | openssl s_client -servername $domain -connect $domain:443 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)

  days_left=$(( ($(date -d "$expiry" +%s) - $(date +%s)) / 86400 ))

  if [ $days_left -lt 30 ]; then
    echo "⚠️ Certificate for $domain expires in $days_left days"
  fi
done
```

## Alert Severity Levels

### CRITICAL (Immediate Response)
- Firewall disabled
- Root SSH login with password
- Malware/backdoor detected
- Data exfiltration suspected
- TLS certificate expired

**Response Time:** < 5 minutes
**Channels:** Slack, Email, SMS

### HIGH (Urgent)
- 10+ failed SSH logins in 1 hour
- Successful login from unknown IP
- Privileged Docker container created
- Security configuration file modified
- fail2ban service down

**Response Time:** < 1 hour
**Channels:** Slack, Email

### MEDIUM (Important)
- 5+ failed SSH logins in 1 hour
- Port scanning detected
- Unusual sudo command
- High connection rate
- Certificate expiring in < 30 days

**Response Time:** < 24 hours
**Channels:** Slack (digest), Email

### LOW (Informational)
- Successful SSH login from known IP
- Normal service restart
- Regular backup completion
- System updates available

**Response Time:** Daily review
**Channels:** Email (daily summary)

## Alert Deduplication

**Problem:** Alert fatigue from repeated events

**Solution:** Rate limiting and aggregation

```bash
# Example: Deduplicate failed login alerts
# Only alert once per IP per hour

LAST_ALERT_FILE="/var/run/security-monitor/last-alert-$IP.txt"

if [ ! -f "$LAST_ALERT_FILE" ] || \
   [ $(( $(date +%s) - $(cat "$LAST_ALERT_FILE") )) -gt 3600 ]; then
  # Send alert
  send_alert "Failed logins from $IP"
  date +%s > "$LAST_ALERT_FILE"
fi
```

**Aggregation Example:**
```
Instead of:
  10:05 - Failed login from 1.2.3.4
  10:07 - Failed login from 1.2.3.4
  10:09 - Failed login from 1.2.3.4

Send:
  10:10 - Summary: 3 failed logins from 1.2.3.4 in last 5 minutes
```

## Monitoring Dashboard

**Netdata Custom Charts:**

```conf
# /etc/netdata/python.d/security_monitor.conf
[global]
  update_every = 10

[ssh_failed_logins]
  title = SSH Failed Login Attempts
  dimension = failed_logins 'Failed Logins' absolute 1 1

[firewall_blocks]
  title = Firewall Blocked Connections
  dimension = blocked 'Blocked' absolute 1 1

[fail2ban_bans]
  title = fail2ban Active Bans
  dimension = banned_ips 'Banned IPs' absolute 1 1
```

**Real-time Log Viewer:**
```bash
# Multi-tail security logs
multitail \
  -c /var/log/auth.log \
  -c /var/log/fail2ban.log \
  -c /var/log/ufw.log \
  -c /var/log/docker-events.log
```

## Integration with Existing Systems

### fail2ban Integration
```ini
# /etc/fail2ban/action.d/security-monitor.conf
[Definition]
actionban = /usr/local/bin/security-alert.sh "IP banned: <ip>"
actionunban = /usr/local/bin/security-alert.sh "IP unbanned: <ip>"
```

### Docker Events Integration
```bash
# Forward Docker events to security monitor
docker events --format '{{json .}}' | \
  while read event; do
    echo "$event" | /usr/local/bin/process-docker-event.sh
  done
```

### Netdata Alarms Integration
```yaml
# /etc/netdata/health.d/security.conf
alarm: ssh_failed_logins
  on: system.logins
  lookup: sum -5m unaligned of failed_logins
  units: logins
  every: 1m
  warn: $this > 5
  crit: $this > 10
  info: SSH failed login attempts
  to: slack
```

## Scripts

Located in: `infrastructure-ops/scripts/security/`

| Script | Purpose | Execution |
|--------|---------|-----------|
| `security-monitor.sh` | Main monitoring daemon | Systemd service |
| `ssh-login-alert.sh` | Alert on SSH logins | PAM hook |
| `firewall-change-alert.sh` | Alert on firewall changes | Triggered |
| `process-security-event.sh` | Event processor | Pipeline |
| `send-security-alert.sh` | Alert dispatcher | Called by scripts |

## Commands

- `/security-events [hours]` - Show recent security events
- `/security-monitor-status` - Check monitoring daemon status
- `/security-alerts-test` - Test alert channels

## Automated Responses

**Auto-ban Aggressive IPs:**
```bash
# If 20+ failed logins in 10 minutes, permanent ban
if [ $FAILED_COUNT -gt 20 ]; then
  ufw insert 1 deny from $IP comment "Auto-banned for brute force"
  fail2ban-client set sshd banip $IP
fi
```

**Auto-disable Compromised Accounts:**
```bash
# If account shows signs of compromise, lock it
usermod -L compromised_user
echo "Account locked: compromised_user at $(date)" | \
  mail -s "Security: Account locked" admin@example.com
```

**Auto-revert Security Changes:**
```bash
# If sshd_config modified, verify it's safe
if [ "$(grep '^PasswordAuthentication yes' /etc/ssh/sshd_config)" ]; then
  echo "⚠️ Password auth re-enabled! Reverting..."
  git -C /etc/ssh checkout sshd_config
  systemctl restart sshd
fi
```

## Compliance & Reporting

**Daily Security Summary:**
```
Security Summary - 2025-12-06

SSH Activity:
  - 145 successful logins (all from known IPs)
  - 23 failed login attempts (3 unique IPs)
  - 0 new SSH keys added

Firewall:
  - 1,234 blocked connections
  - Top blocked IP: 1.2.3.4 (456 attempts)
  - 0 firewall rule changes

fail2ban:
  - 2 IPs currently banned
  - 5 bans today (all temporary)
  - 0 unbans

Service Security:
  - 8 Docker containers created
  - 0 privileged containers
  - All TLS certificates valid (60+ days)

Action Items:
  - Review failed logins from 5.6.7.8 (dictionary attack)
  - Investigate unusual sudo usage by user 'backup'
```

## References

- OSSEC HIDS: https://www.ossec.net/
- fail2ban: https://www.fail2ban.org/
- Wazuh: https://wazuh.com/
- Netdata Alarms: https://learn.netdata.cloud/docs/alerts-&-notifications
