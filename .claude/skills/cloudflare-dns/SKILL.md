---
name: "Cloudflare DNS Operations"
description: "Manage Cloudflare DNS records for aienablement.academy zone with SSL workflow support. Use when creating subdomains, managing DNS, troubleshooting SSL 525 errors, or integrating with Caddy reverse proxy."
---

# Cloudflare DNS Operations

## What This Skill Does

Manage all Cloudflare DNS operations using direct API calls:
1. Create, update, delete DNS records
2. Handle SSL/TLS certificate workflow with Caddy
3. Toggle Cloudflare proxy on/off
4. Troubleshoot common DNS/SSL issues

## Credentials Location

**CRITICAL: Always check this file first for Cloudflare credentials:**
```
/Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env
```

## Quick Reference

### Environment Variables
```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env
# Sets: CF_API_TOKEN, CF_ZONE_ID, CF_ZONE_NAME
```

### Zone Details
| Property | Value |
|----------|-------|
| **Zone Name** | aienablement.academy |
| **Zone ID** | 78bc8afbb8fbc182da21dde984fd005f |
| **OCI Server IP** | 163.192.41.116 |

---

## Common Operations

### List All DNS Records
```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {id, name, type, content, proxied}'
```

### Get Specific Record
```bash
curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=subdomain.aienablement.academy" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq '.result[0]'
```

### Create A Record
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "subdomain",
    "content": "163.192.41.116",
    "ttl": 1,
    "proxied": true
  }'
```

### Create CNAME Record
```bash
curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "CNAME",
    "name": "alias",
    "content": "target.example.com",
    "ttl": 1,
    "proxied": true
  }'
```

### Update Record (Toggle Proxy)
```bash
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/{record_id}" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"proxied": false}'
```

### Delete Record
```bash
curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/{record_id}" \
  -H "Authorization: Bearer $CF_API_TOKEN"
```

---

## SSL/TLS Certificate Workflow (CRITICAL)

When adding new subdomains with Caddy and Let's Encrypt, follow this exact order:

### Step 1: Create DNS with Proxy DISABLED
```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{
    "type": "A",
    "name": "newsubdomain",
    "content": "163.192.41.116",
    "ttl": 1,
    "proxied": false
  }'
```

**IMPORTANT**: `proxied: false` allows ACME HTTP-01 challenge to reach Caddy directly.

### Step 2: Add Caddyfile Block on OCI Server
```bash
# SSH to OCI server
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116

# Edit Caddyfile (CORRECT location!)
sudo nano /home/ubuntu/reverse-proxy/Caddyfile

# Add block:
# newsubdomain.aienablement.academy {
#   reverse_proxy container-name:port
# }
```

### Step 3: Reload Caddy
```bash
# CORRECT container name is edge-proxy (NOT caddy-proxy)
sudo docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile
```

### Step 4: Wait for Certificate
```bash
# Check Caddy logs for successful cert issuance
docker logs --tail 50 edge-proxy | grep -i "certificate obtained"
```

### Step 5: Enable Cloudflare Proxy
```bash
# Get record ID
RECORD_ID=$(curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?name=newsubdomain.aienablement.academy" \
  -H "Authorization: Bearer $CF_API_TOKEN" | jq -r '.result[0].id')

# Enable proxy
curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"proxied": true}'
```

---

## Helper Scripts

### Create Subdomain Script
Create: `scripts/create-subdomain.sh`
```bash
#!/bin/bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

SUBDOMAIN=$1
IP="${2:-163.192.41.116}"

if [ -z "$SUBDOMAIN" ]; then
    echo "Usage: ./create-subdomain.sh <subdomain> [ip]"
    exit 1
fi

# Create with proxy disabled for ACME
RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{
    \"type\": \"A\",
    \"name\": \"$SUBDOMAIN\",
    \"content\": \"$IP\",
    \"ttl\": 1,
    \"proxied\": false
  }")

RECORD_ID=$(echo $RESPONSE | jq -r '.result.id')
echo "Created: $SUBDOMAIN.aienablement.academy"
echo "Record ID: $RECORD_ID"
echo ""
echo "Next steps:"
echo "1. Add Caddyfile block on OCI server"
echo "2. Reload Caddy: docker exec edge-proxy caddy reload --config /etc/caddy/Caddyfile"
echo "3. Wait for cert, then run: ./enable-proxy.sh $RECORD_ID"
```

### Enable Proxy Script
Create: `scripts/enable-proxy.sh`
```bash
#!/bin/bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

RECORD_ID=$1

if [ -z "$RECORD_ID" ]; then
    echo "Usage: ./enable-proxy.sh <record_id>"
    exit 1
fi

curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data '{"proxied": true}'

echo "Proxy enabled for record $RECORD_ID"
```

### List Records Script
Create: `scripts/list-records.sh`
```bash
#!/bin/bash
source /Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env

curl -s "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CF_API_TOKEN" | \
  jq -r '.result[] | "\(.name)\t\(.type)\t\(.content)\t\(.proxied)"' | \
  column -t -s $'\t'
```

---

## Existing Subdomains

| Subdomain | Service | Container | DNS Record ID |
|-----------|---------|-----------|---------------|
| wiki | Docmost | docmost-app | - |
| ops | NocoDB | nocodb-app | - |
| cortex | SiYuan | cortex-siyuan | - |
| forms | Formbricks | formbricks-app | - |
| calendar | Cal.com | calcom-app | 27d2af99b06a3a0d8d0b6bac8594a250 |
| status | Uptime Kuma | uptime-kuma | - |
| monitor | Dozzle | dozzle | - |
| n8n | n8n | n8n-app | - |
| dash | Dashboard | dash-app | - |

---

## Troubleshooting

### Issue: HTTP 525 SSL Handshake Failed
**Symptoms**: Browser shows Cloudflare 525 error
**Cause**: Cloudflare proxy enabled before origin certificate was issued by Let's Encrypt
**Solution**:
1. Disable proxy: `{"proxied": false}`
2. SSH to OCI and reload Caddy
3. Wait for Caddy to obtain certificate (check logs)
4. Re-enable proxy: `{"proxied": true}`

### Issue: 9109 Invalid Access Token
**Symptoms**: API returns error code 9109
**Cause**: Token expired, revoked, or incorrectly copied
**Solution**:
1. Go to Cloudflare Dashboard → My Profile → API Tokens
2. Create new token with Zone:DNS:Edit permissions
3. Update `/Users/adamkovacs/Documents/codebuild/.credentials/cloudflare/aienablement-academy.env`

### Issue: DNS Record Not Found
**Symptoms**: Query returns empty result
**Cause**: Wrong zone ID or subdomain doesn't exist
**Solution**:
1. Verify zone ID: 78bc8afbb8fbc182da21dde984fd005f
2. List all records to find correct name
3. Check for typos in subdomain name

### Issue: ACME Challenge Failed
**Symptoms**: Caddy fails to obtain certificate
**Cause**: Cloudflare proxy blocking ACME challenge, or DNS not propagated
**Solution**:
1. Ensure `proxied: false` for new records
2. Wait 2-5 minutes for DNS propagation
3. Check Caddy logs: `docker logs edge-proxy | grep acme`

---

## CRITICAL LEARNINGS (from Cal.com Deployment)

### Common Mistakes to Avoid
1. **Wrong IP**: Use 163.192.41.116 (NOT 192.18.138.10)
2. **Wrong Caddyfile path**: Use `/home/ubuntu/reverse-proxy/Caddyfile` (NOT `/srv/proxy/Caddyfile`)
3. **Wrong container name**: Use `edge-proxy` (NOT `caddy-proxy`)
4. **Enabling proxy too early**: Always wait for cert before enabling proxy

### SSL Workflow Summary
```
DNS (proxied:false) → Caddyfile → Reload Caddy → Wait for Cert → Enable Proxy
```

---

## Related Documentation

- OCI Server Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/oci-server/SKILL.md`
- Brevo Email Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/brevo-email/SKILL.md`
- Infrastructure Context: `/Users/adamkovacs/Documents/codebuild/.claude/memory/infrastructure-context.json`
- Cloudflare API Docs: https://developers.cloudflare.com/api/
