---
name: "NPM Proxy Manager"
description: "Nginx Proxy Manager configuration management via database operations. Manage proxy hosts, SSL certificates, and fix outdated Tailscale IPs."
---

# NPM Proxy Manager

## Overview

This skill provides NPM (Nginx Proxy Manager) operations with direct database access:
1. **List proxy hosts**: View all configured proxy hosts and their backend IPs
2. **Add proxy hosts**: Create new proxy configurations via database
3. **Fix outdated IPs**: Detect and fix Tailscale IP drift automatically
4. **SSL management**: Monitor certificate status and expiration

## Token Savings

- **No MCP needed**: Uses direct SSH + SQLite commands
- **Lightweight**: Shell scripts only, minimal token overhead

---

## What This Skill Does

Manage all NPM operations via direct database access:
1. Query proxy host configurations
2. Add new proxy hosts programmatically
3. Detect and fix outdated Tailscale IPs
4. Monitor SSL certificate status
5. Backup NPM database

## NPM Environment

**NPM Server:**
- IP: `192.168.50.45`
- LXC: `106` on Proxmox
- Database: `/data/database.sqlite`
- SSH Access: `root@192.168.50.45`

**Managed Domains:**
- `*.harbor.fyi` - 15+ subdomains
- SSL: Let's Encrypt via NPM
- Backend: Tailscale network devices

---

## Quick Reference

### SSH Database Access
```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite 'SELECT * FROM proxy_host;'"
```

### Database Schema (Key Tables)

**proxy_host**
- `id` - Proxy host ID
- `domain_names` - JSON array of domains
- `forward_host` - Backend IP/hostname
- `forward_port` - Backend port
- `certificate_id` - SSL certificate ID
- `enabled` - 0 or 1

**certificate**
- `id` - Certificate ID
- `domain_names` - JSON array of domains
- `expires_on` - Unix timestamp
- `provider` - 'letsencrypt'

**access_list**
- `id` - Access list ID
- `name` - Access list name

---

## Common Operations

### List All Proxy Hosts

```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite -json '
  SELECT
    id,
    domain_names,
    forward_host,
    forward_port,
    certificate_id,
    enabled
  FROM proxy_host
  ORDER BY id;
'"
```

### Find Proxy by Domain

```bash
DOMAIN="cortex.harbor.fyi"
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  SELECT id, domain_names, forward_host, forward_port
  FROM proxy_host
  WHERE domain_names LIKE \"%$DOMAIN%\";
'"
```

### Update Backend IP

```bash
PROXY_ID=5
NEW_IP="100.108.72.90"

ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  UPDATE proxy_host
  SET forward_host = \"$NEW_IP\"
  WHERE id = $PROXY_ID;
'"
```

### Add New Proxy Host

```bash
# First, find next available ID
NEXT_ID=$(ssh root@192.168.50.45 "sqlite3 /data/database.sqlite 'SELECT MAX(id)+1 FROM proxy_host;'")

DOMAIN='["newservice.harbor.fyi"]'
BACKEND_IP="100.108.72.99"
BACKEND_PORT=3000

ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  INSERT INTO proxy_host (
    id,
    created_on,
    modified_on,
    owner_user_id,
    domain_names,
    forward_host,
    forward_port,
    access_list_id,
    certificate_id,
    ssl_forced,
    caching_enabled,
    block_exploits,
    advanced_config,
    enabled,
    meta,
    allow_websocket_upgrade,
    http2_support,
    forward_scheme,
    hsts_enabled,
    hsts_subdomains
  ) VALUES (
    $NEXT_ID,
    datetime(\"now\"),
    datetime(\"now\"),
    1,
    \"$DOMAIN\",
    \"$BACKEND_IP\",
    $BACKEND_PORT,
    0,
    NULL,
    0,
    0,
    1,
    \"\",
    1,
    \"{}\",
    1,
    1,
    \"http\",
    0,
    0
  );
'"
```

### Check SSL Certificate Status

```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  SELECT
    id,
    domain_names,
    datetime(expires_on, \"unixepoch\") as expires,
    provider
  FROM certificate
  ORDER BY expires_on;
'"
```

### Get Certificates Expiring Soon (< 30 days)

```bash
THIRTY_DAYS_FROM_NOW=$(date -d "+30 days" +%s)

ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  SELECT
    domain_names,
    datetime(expires_on, \"unixepoch\") as expires
  FROM certificate
  WHERE expires_on < $THIRTY_DAYS_FROM_NOW;
'"
```

---

## Tailscale IP Drift Detection

### Problem
Services move between Tailscale devices, causing IP changes. NPM proxy hosts point to old IPs.

### Solution
Use the `npm-fix-ips.sh` script to detect and fix outdated IPs:

```bash
bash /Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/npm-fix-ips.sh
```

### How It Works
1. Query Tailscale for current device IPs: `tailscale status --json`
2. Query NPM database for all proxy hosts
3. Compare backend IPs with current Tailscale IPs
4. Prompt to update mismatched IPs
5. Update NPM database and reload config

---

## Backup and Restore

### Backup NPM Database

```bash
BACKUP_DIR="/Users/adamkovacs/Documents/codebuild/backups/npm"
mkdir -p "$BACKUP_DIR"

ssh root@192.168.50.45 "cat /data/database.sqlite" > "$BACKUP_DIR/npm-$(date +%Y%m%d-%H%M%S).sqlite"
```

### Restore NPM Database

```bash
BACKUP_FILE="/Users/adamkovacs/Documents/codebuild/backups/npm/npm-20251206-140000.sqlite"

cat "$BACKUP_FILE" | ssh root@192.168.50.45 "cat > /data/database.sqlite && docker restart npm"
```

---

## Helper Scripts

All scripts located in: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`

### npm-proxy-list.sh
List all NPM proxy hosts with domain, backend IP, and SSL status.

**Usage:**
```bash
bash npm-proxy-list.sh
```

**Output:**
```
ID  Domain                     Backend IP       Port  SSL  Status
1   cortex.harbor.fyi          100.108.72.90    3000  Yes  Enabled
2   qdrant.harbor.fyi          100.108.72.90    6333  Yes  Enabled
...
```

### npm-proxy-add.sh
Add new proxy host interactively.

**Usage:**
```bash
bash npm-proxy-add.sh newservice.harbor.fyi 100.108.72.99 3000
```

### npm-fix-ips.sh
Detect and fix outdated Tailscale IPs in NPM proxy configurations.

**Usage:**
```bash
bash npm-fix-ips.sh
```

**What it does:**
1. Gets current Tailscale IPs
2. Compares with NPM proxy backend IPs
3. Shows mismatches
4. Prompts to fix each mismatch
5. Updates database and reloads NPM

---

## Troubleshooting

### Issue: SSH Connection Refused
**Symptoms**: Cannot connect to 192.168.50.45
**Cause**: NPM LXC is down or SSH not running
**Solution**:
1. Check LXC status: `ssh root@192.168.50.11 pct status 106`
2. Start LXC: `ssh root@192.168.50.11 pct start 106`
3. Wait 30 seconds for SSH to start

### Issue: Database Locked
**Symptoms**: `database is locked` error
**Cause**: NPM is actively writing to database
**Solution**: Wait 5 seconds and retry, or stop NPM temporarily:
```bash
ssh root@192.168.50.45 "docker stop npm && sleep 2 && docker start npm"
```

### Issue: Changes Not Applied
**Symptoms**: Updated database but NPM still shows old config
**Cause**: NPM needs to reload configuration
**Solution**:
```bash
ssh root@192.168.50.45 "docker restart npm"
```

### Issue: SSL Certificate Expired
**Symptoms**: HTTPS not working, browser shows certificate error
**Cause**: Let's Encrypt certificate expired
**Solution**: Force renewal via NPM UI or delete and recreate certificate

---

## Integration with Tailscale

NPM relies on Tailscale network for backend communication. Always verify:
1. Backend service is on Tailscale network
2. Tailscale IP is current (use `tailscale status`)
3. Backend service is listening on correct port

**Related Skill:**
`/Users/adamkovacs/Documents/codebuild/.claude/skills/tailscale-network-manager/skill.md`

---

## Related Documentation

- NPM Official Docs: https://nginxproxymanager.com/
- Tailscale Network Manager Skill: `../tailscale-network-manager/skill.md`
- SSL Certificate Manager Skill: `../ssl-certificate-manager/skill.md`
- Infrastructure Ops Scripts: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`
