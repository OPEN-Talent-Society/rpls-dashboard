---
name: "SSL Certificate Manager"
description: "SSL certificate monitoring, renewal, and alerting for NPM, Caddy, and direct certificate management. Prevent expiration and automate renewals."
---

# SSL Certificate Manager

## Overview

This skill provides SSL certificate management operations:
1. **Certificate monitoring**: Track expiration for all domains
2. **Renewal automation**: Auto-renew before expiration
3. **Multi-platform**: NPM, Caddy, and standalone certificates
4. **Alerting**: Notify on certificates expiring < 30 days
5. **Validation**: Check certificate chain and validity

## Token Savings

- **No MCP needed**: Uses OpenSSL and direct API calls
- **Lightweight**: Shell scripts and curl commands only

---

## What This Skill Does

Manage SSL certificates across platforms:
1. Monitor certificate expiration (NPM, Caddy, standalone)
2. Auto-renew Let's Encrypt certificates
3. Alert on expiring certificates
4. Validate certificate chains
5. Generate reports on certificate health

## SSL Environment

**Managed Certificates:**
- **NPM**: 15+ `*.harbor.fyi` domains via Let's Encrypt
- **Caddy**: Auto-managed (future)
- **Standalone**: Custom certificates for specific services

**Certificate Storage:**
- NPM: `/data/letsencrypt` on LXC 106
- Caddy: `/data/caddy/certificates` (future)
- Standalone: `/etc/ssl/certs/`

---

## Quick Reference

### Check Certificate Expiration (Remote)

```bash
DOMAIN="cortex.harbor.fyi"
echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
  openssl x509 -noout -dates
```

**Output:**
```
notBefore=Nov  6 12:34:56 2025 GMT
notAfter=Feb  4 12:34:55 2026 GMT
```

### Check Certificate Expiration (Local File)

```bash
CERT_FILE="/etc/ssl/certs/mycert.pem"
openssl x509 -in "$CERT_FILE" -noout -dates
```

### Get Certificate Expiration in Days

```bash
DOMAIN="cortex.harbor.fyi"
EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
  openssl x509 -noout -enddate | cut -d= -f2)

EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))

echo "Certificate expires in $DAYS_LEFT days"
```

---

## Common Operations

### List All NPM Certificates

```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  SELECT
    domain_names,
    datetime(expires_on, \"unixepoch\") as expires,
    provider,
    CAST((julianday(datetime(expires_on, \"unixepoch\")) - julianday(\"now\")) AS INTEGER) as days_left
  FROM certificate
  ORDER BY expires_on;
'"
```

**Output:**
```
["cortex.harbor.fyi"]    2026-02-04 12:34:55    letsencrypt    60
["qdrant.harbor.fyi"]    2026-02-10 08:15:22    letsencrypt    66
```

### Find Expiring Certificates (< 30 days)

```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  SELECT
    domain_names,
    datetime(expires_on, \"unixepoch\") as expires,
    CAST((julianday(datetime(expires_on, \"unixepoch\")) - julianday(\"now\")) AS INTEGER) as days_left
  FROM certificate
  WHERE expires_on < strftime(\"%s\", \"now\", \"+30 days\")
  ORDER BY expires_on;
'"
```

### Check All harbor.fyi Domains

```bash
DOMAINS=(
  "cortex.harbor.fyi"
  "qdrant.harbor.fyi"
  "formbricks.harbor.fyi"
  "calcom.harbor.fyi"
  # ... add all domains
)

for DOMAIN in "${DOMAINS[@]}"; do
  echo -n "$DOMAIN: "
  EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
    openssl x509 -noout -enddate | cut -d= -f2)
  echo "$EXPIRY"
done
```

### Validate Certificate Chain

```bash
DOMAIN="cortex.harbor.fyi"
echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
  openssl x509 -noout -text | grep -A2 "Issuer:"
```

### Check Certificate Algorithm

```bash
DOMAIN="cortex.harbor.fyi"
echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | \
  openssl x509 -noout -text | grep "Signature Algorithm"
```

---

## NPM Certificate Management

### Force Renew Certificate (NPM UI)

1. Login to NPM: `https://192.168.50.45:81`
2. Navigate to SSL Certificates
3. Find certificate to renew
4. Click "Force Renew"
5. Wait for renewal (1-2 minutes)

### Force Renew via Database (Emergency)

```bash
# Delete certificate (will trigger auto-renewal on next proxy access)
CERT_ID=5

ssh root@192.168.50.45 "sqlite3 /data/database.sqlite '
  DELETE FROM certificate WHERE id = $CERT_ID;
'"

# Restart NPM to trigger renewal
ssh root@192.168.50.45 "docker restart npm"
```

**Warning:** This will cause brief downtime while certificate renews.

### Check NPM Let's Encrypt Logs

```bash
ssh root@192.168.50.45 "docker logs npm 2>&1 | grep -i 'letsencrypt\|acme'"
```

---

## Caddy Certificate Management

Caddy manages certificates automatically. No manual intervention needed.

### Check Caddy Certificate Storage

```bash
# List certificates managed by Caddy
ls -lh /data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/
```

### Force Renew Caddy Certificate

Caddy auto-renews. To force:

```bash
# Reload config (triggers check)
caddy reload --config /etc/caddy/Caddyfile

# Or restart Caddy
systemctl restart caddy
```

### Check Caddy Certificate Logs

```bash
journalctl -u caddy -f | grep -i 'certificate\|tls\|acme'
```

---

## Helper Scripts

All scripts located in: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`

### ssl-cert-check.sh
Check SSL certificate expiration for all harbor.fyi domains.

**Usage:**
```bash
bash ssl-cert-check.sh
```

**Output:**
```
=== SSL Certificate Expiration Report ===
Domain                     Expires              Days Left  Status
cortex.harbor.fyi          2026-02-04 12:34:55  60         OK
qdrant.harbor.fyi          2026-02-10 08:15:22  66         OK
old.harbor.fyi             2025-12-15 10:00:00  9          WARNING

=== Summary ===
Total: 15
OK (>30 days): 13
Warning (<30 days): 2
Expired: 0
```

### ssl-cert-renew-npm.sh
Force renew specific NPM certificate.

**Usage:**
```bash
bash ssl-cert-renew-npm.sh cortex.harbor.fyi
```

**What it does:**
1. Find certificate ID in NPM database
2. Trigger renewal via NPM API
3. Wait for completion
4. Verify new expiration date

---

## Monitoring and Alerts

### Daily Certificate Check (Hook)

`.claude/hooks/ssl-expiry-alert.sh` runs daily to:
1. Check all certificates
2. Find expiring (<30 days)
3. Send alerts (Slack, email, etc.)
4. Create NocoDB task for manual renewal if auto-renewal fails

### Alert Format

```
🚨 SSL Certificate Expiring Soon

Domain: old.harbor.fyi
Expires: 2025-12-15 (9 days)
Action: Renew via NPM or Caddy

Check: https://192.168.50.45:81/certificates
```

### Integration with NocoDB

Auto-create task for expiring certificates:

```bash
DOMAIN="old.harbor.fyi"
DAYS_LEFT=9

# Create NocoDB task
curl -X POST "https://nocodb.example.com/api/v1/db/data/noco/tasks/tasks" \
  -H "xc-token: $NOCODB_API_TOKEN" \
  -d "{
    \"task name\": \"Renew SSL: $DOMAIN\",
    \"Status\": \"To Do\",
    \"Priority\": \"High\",
    \"Notes\": \"Certificate expires in $DAYS_LEFT days\"
  }"
```

---

## Troubleshooting

### Issue: Certificate Renewal Failed
**Symptoms**: NPM shows "Failed to renew" error
**Cause**: ACME challenge failed (DNS not pointing to NPM, port 80 blocked)
**Solution**:
1. Verify DNS: `dig example.com` points to NPM IP
2. Check port 80: `curl http://example.com/.well-known/acme-challenge/test`
3. Check NPM logs: `ssh root@192.168.50.45 "docker logs npm 2>&1 | tail -100"`
4. Try manual renewal via NPM UI

### Issue: Certificate Expired
**Symptoms**: Browser shows "Your connection is not private"
**Cause**: Certificate expired, auto-renewal failed
**Solution**:
1. Delete expired certificate in NPM
2. Create new certificate for domain
3. Wait for Let's Encrypt to issue (1-2 minutes)
4. Verify: `echo | openssl s_client -connect example.com:443 | grep "Verify return code"`

### Issue: Wrong Certificate Served
**Symptoms**: Browser shows certificate for different domain
**Cause**: SNI (Server Name Indication) issue or wildcard certificate
**Solution**:
1. Check certificate CN: `echo | openssl s_client -servername example.com -connect example.com:443 | openssl x509 -noout -subject`
2. Ensure correct proxy host in NPM
3. Restart NPM: `ssh root@192.168.50.45 "docker restart npm"`

### Issue: Self-Signed Certificate
**Symptoms**: Browser shows "self-signed certificate" warning
**Cause**: Let's Encrypt challenge failed, NPM using fallback
**Solution**: Renew certificate properly via Let's Encrypt

---

## Certificate Best Practices

1. **Auto-renewal**: Let NPM/Caddy handle renewals (don't disable)
2. **Monitor expiration**: Run `ssl-cert-check.sh` weekly
3. **Backup certificates**: Include in NPM database backups
4. **DNS before SSL**: Ensure DNS points to server before requesting certificate
5. **Wildcard certificates**: Use for `*.harbor.fyi` to reduce renewal overhead
6. **Test renewal**: Force renew 60 days before expiry to catch issues early

---

## Integration with Other Skills

**NPM Proxy Manager:**
- Monitors NPM-managed certificates
- Related: `../npm-proxy-manager/skill.md`

**Caddy Config Manager:**
- Monitors Caddy-managed certificates
- Related: `../caddy-config-manager/skill.md`

**Backup Rotation:**
- Includes certificate backups
- Related: `../backup-rotation/skill.md`

---

## Related Documentation

- Let's Encrypt Docs: https://letsencrypt.org/docs/
- OpenSSL Cookbook: https://www.feistyduck.com/library/openssl-cookbook/
- NPM SSL Guide: https://nginxproxymanager.com/guide/#quick-setup
- Caddy HTTPS: https://caddyserver.com/docs/automatic-https
- Infrastructure Ops Scripts: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`
