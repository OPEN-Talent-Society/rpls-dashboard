# ddns-updater Configuration & Optimization

## Current Issues
1. **nas.harbor.fyi** may not be in the config
2. Default check period is too infrequent
3. No automatic recovery when IP changes fail to update

## Solution: Docker Compose with Optimized Settings

### Step 1: SSH into Docker VM

```bash
# Via Proxmox
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62
qm enter 101
# OR SSH to VM directly if accessible

# Navigate to docker compose directory
cd /path/to/docker-compose  # Find where ddns-updater is defined
```

### Step 2: Update docker-compose.yml

Add environment variables for faster updates:

```yaml
services:
  ddns-updater:
    image: qmcgaw/ddns-updater:latest
    container_name: ddns-updater
    restart: unless-stopped
    environment:
      - PERIOD=5m              # Check every 5 minutes (default: 10m)
      - UPDATE_COOLDOWN_PERIOD=1m  # Min time between updates
      - HTTP_TIMEOUT=10s       # API timeout
      - PUBLICIP_FETCHERS=all  # Use all methods to detect IP
      - PUBLICIP_HTTP_PROVIDERS=ipify,seeip  # Reliable IP checkers
      - LOG_LEVEL=info        # Detailed logging
      - LOG_CALLER=hidden     # Clean logs
      - SHOUTRRR_ADDRESSES=   # Optional: Add notification URL
    volumes:
      - ddns-updater-data:/updater/data
    ports:
      - "8000:8000"  # Web UI
    networks:
      - proxy
```

### Step 3: Update config.json with nas.harbor.fyi

```bash
# Edit config file
docker exec ddns-updater vi /updater/data/config.json
# OR
docker cp ddns-updater:/updater/data/config.json /tmp/config.json
vi /tmp/config.json
docker cp /tmp/config.json ddns-updater:/updater/data/config.json
```

**Add nas.harbor.fyi as FIRST entry:**

```json
{
  "settings": [
    {
      "provider": "porkbun",
      "domain": "nas.harbor.fyi",
      "api_key": "pk1_08575b590bf8563726c4c5a2dc082ddbd82bfe6cc7bb2b46655d1a087b3c806c",
      "secret_api_key": "sk1_6ba6a28ab2b9c83ab70d12bcd9ad374e05b0e51e085783c31a1974e74b8eafa0",
      "ip_version": "ipv4"
    },
    ... other domains ...
  ]
}
```

### Step 4: Restart Container

```bash
docker restart ddns-updater

# Watch logs
docker logs -f ddns-updater

# Should see:
# INFO Updating record [domain: nas.harbor.fyi | provider: porkbun | ip: ipv4]
```

### Step 5: Verify Web UI

```bash
# Open browser to: http://<docker-vm-ip>:8000
# Should show nas.harbor.fyi with current IP and last update time
```

---

## Alternative: IP Change Detection Script

If you want even faster detection, create a cron job that triggers ddns-updater on IP change:

```bash
#!/bin/bash
# /usr/local/bin/check-ip-change.sh

CURRENT_IP=$(curl -s https://api.ipify.org)
LAST_IP=$(cat /tmp/last-known-ip 2>/dev/null)

if [ "$CURRENT_IP" != "$LAST_IP" ]; then
  echo "IP changed from $LAST_IP to $CURRENT_IP"
  echo "$CURRENT_IP" > /tmp/last-known-ip

  # Force ddns-updater to check immediately
  docker exec ddns-updater kill -HUP 1

  # OR restart container
  # docker restart ddns-updater
fi
```

**Add to crontab:**
```bash
# Check every 2 minutes
*/2 * * * * /usr/local/bin/check-ip-change.sh >> /var/log/ip-check.log 2>&1
```

---

## Monitoring & Notifications

### Option 1: Uptime Kuma Integration

Add ddns-updater web UI to Uptime Kuma:
- **URL:** http://192.168.50.149:8000
- **Check Interval:** 5 minutes
- **Alert if:** Response time > 5s OR status != 200

### Option 2: Shoutrrr Notifications

Add to docker-compose environment:

```yaml
# Slack notification
- SHOUTRRR_ADDRESSES=slack://token@channel

# Ntfy notification
- SHOUTRRR_ADDRESSES=ntfy://ntfy.sh/your-topic

# Email via SMTP
- SHOUTRRR_ADDRESSES=smtp://user:password@smtp.gmail.com:587/?from=alert@example.com&to=you@example.com
```

---

## Troubleshooting 400 Errors

The 400 errors from earlier logs suggest:
1. DNS records might be locked
2. API key permissions issue
3. Cloudflare proxy enabled (interferes with Porkbun API)

**Fix:**
1. Check Porkbun dashboard → DNS records → Ensure not locked
2. Verify API key has "Edit DNS" permission
3. If Cloudflare is enabled, disable proxy (cloud icon) for specific records

---

## Expected Behavior After Fix

- **IP Check:** Every 5 minutes
- **Update Trigger:** Within 1 minute of IP change detection
- **Retry Logic:** 3 attempts with exponential backoff
- **Success Rate:** Should see "SUCCESS" in logs, not "ERROR"

---

## Verification Commands

```bash
# Check current config
docker exec ddns-updater cat /updater/data/config.json | jq '.settings[] | select(.domain | contains("nas"))'

# Check logs for nas.harbor.fyi
docker logs ddns-updater 2>&1 | grep -i "nas"

# Force manual update (restart container)
docker restart ddns-updater && docker logs -f ddns-updater

# Check current public IP
curl -s https://api.ipify.org

# Verify DNS matches
dig nas.harbor.fyi +short
```

---

**Next:** After ddns-updater is fixed, configure router DNS override for local access.
