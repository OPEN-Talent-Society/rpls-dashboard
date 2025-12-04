# Qdrant Security Deployment Guide

## Quick Start (5 Steps)

### 1. Generate API Keys
```bash
cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant
./generate-keys.sh
```

This creates a `.env` file with secure API keys.

### 2. Deploy Qdrant with API Keys
```bash
# Stop existing container
docker stop qdrant && docker rm qdrant

# Deploy new configuration
cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant
docker-compose up -d

# Verify it's running
docker ps | grep qdrant
docker logs qdrant
```

### 3. Test API Key Authentication
```bash
# Load environment variables
source .env

# Should fail (no API key)
curl https://qdrant.harbor.fyi/collections

# Should succeed (with API key)
curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections
```

### 4. Configure Nginx + SSL
```bash
# Install Nginx (if not already installed)
sudo apt update && sudo apt install nginx

# Copy Nginx configuration
sudo cp nginx.conf /etc/nginx/sites-available/qdrant.harbor.fyi

# Enable site
sudo ln -s /etc/nginx/sites-available/qdrant.harbor.fyi \
           /etc/nginx/sites-enabled/

# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Add Cloudflare Origin Certificate (manual step - see below)
sudo nano /etc/nginx/ssl/qdrant.harbor.fyi.pem
sudo nano /etc/nginx/ssl/qdrant.harbor.fyi.key

# Set permissions
sudo chmod 600 /etc/nginx/ssl/qdrant.harbor.fyi.key
sudo chmod 644 /etc/nginx/ssl/qdrant.harbor.fyi.pem

# Test configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

### 5. Update Sync Scripts
```bash
# Find all scripts using Qdrant
cd /Users/adamkovacs/Documents/codebuild
grep -r "192.168.50.149:6333" --include="*.sh" --include="*.js" --include="*.ts"

# Manually update each script using the patterns in qdrant-security-patches.diff
# Or use sed (CAREFUL - test first):
# sed -i 's|http://192.168.50.149:6333|https://qdrant.harbor.fyi|g' script.sh
```

## Detailed Steps

### Obtaining Cloudflare Origin Certificate

1. **Login to Cloudflare Dashboard**
   - Go to https://dash.cloudflare.com
   - Select your domain (harbor.fyi)

2. **Generate Origin Certificate**
   - Navigate to: SSL/TLS → Origin Server
   - Click "Create Certificate"
   - Select:
     - Private key type: RSA (2048)
     - Hostnames: `qdrant.harbor.fyi`, `*.harbor.fyi`
     - Certificate validity: 15 years
   - Click "Create"

3. **Save Certificate Files**
   ```bash
   # Copy the certificate
   sudo nano /etc/nginx/ssl/qdrant.harbor.fyi.pem
   # Paste the "Origin Certificate" content

   # Copy the private key
   sudo nano /etc/nginx/ssl/qdrant.harbor.fyi.key
   # Paste the "Private Key" content

   # Set permissions
   sudo chmod 600 /etc/nginx/ssl/qdrant.harbor.fyi.key
   sudo chmod 644 /etc/nginx/ssl/qdrant.harbor.fyi.pem
   ```

4. **Configure Cloudflare DNS**
   - Add A record: `qdrant.harbor.fyi` → your homelab IP
   - Enable "Proxied" (orange cloud icon)
   - SSL/TLS mode: "Full (strict)"

### Setting Up Cloudflare Access (Optional)

1. **Enable Cloudflare Zero Trust**
   - Go to https://one.dash.cloudflare.com
   - Navigate to: Access → Applications

2. **Create Service Token**
   - Go to: Service Authentication
   - Click "Create Service Token"
   - Name: "Qdrant API Access"
   - Save Client ID and Client Secret

3. **Create Access Policy**
   - Add Application
   - Application type: Self-hosted
   - Application domain: `qdrant.harbor.fyi`
   - Add Policy:
     - Name: "Service Token Access"
     - Action: Allow
     - Rule: Service Token
     - Select: "Qdrant API Access"

4. **Update Scripts**
   ```bash
   # Add to .env
   CF_ACCESS_CLIENT_ID="your-client-id"
   CF_ACCESS_CLIENT_SECRET="your-client-secret"

   # Update curl requests
   curl -H "api-key: ${QDRANT_API_KEY}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        https://qdrant.harbor.fyi/collections
   ```

5. **Uncomment Nginx Validation**
   - Edit `/etc/nginx/sites-available/qdrant.harbor.fyi`
   - Uncomment the Cloudflare Access validation block
   - Reload Nginx: `sudo systemctl reload nginx`

### Setting Up Tailscale Access (Optional)

1. **Install Tailscale on Homelab Server**
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

2. **Advertise Subnet Routes**
   ```bash
   sudo tailscale up --advertise-routes=192.168.50.0/24 --accept-routes
   ```

3. **Approve Routes in Tailscale Admin**
   - Go to https://login.tailscale.com/admin/machines
   - Find your homelab server
   - Click "Edit route settings"
   - Approve the 192.168.50.0/24 route

4. **Get Tailscale IP**
   ```bash
   tailscale ip -4
   # Example output: 100.x.x.x
   ```

5. **Access Qdrant via Tailscale**
   ```bash
   # Update .env
   QDRANT_TAILSCALE_URL=http://100.x.x.x:6333

   # Use in scripts
   curl -H "api-key: ${QDRANT_API_KEY}" ${QDRANT_TAILSCALE_URL}/collections
   ```

## Verification Tests

### Test 1: API Key Required
```bash
# Should return 401 Unauthorized
curl -v https://qdrant.harbor.fyi/collections 2>&1 | grep "401\|Unauthorized"
```

### Test 2: Valid API Key Works
```bash
# Should return 200 OK with collections list
curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections
```

### Test 3: Read-Only Key Restrictions
```bash
# Should work (GET)
curl -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
     https://qdrant.harbor.fyi/collections

# Should fail (PUT - 403 Forbidden)
curl -X PUT -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
     -H "Content-Type: application/json" \
     https://qdrant.harbor.fyi/collections/test \
     -d '{"vectors": {"size": 128, "distance": "Cosine"}}'
```

### Test 4: SSL/TLS
```bash
# Check SSL certificate
openssl s_client -connect qdrant.harbor.fyi:443 -servername qdrant.harbor.fyi \
  < /dev/null 2>&1 | grep "Verify return code"

# Should show: Verify return code: 0 (ok)
```

### Test 5: CORS Headers
```bash
# Check CORS headers
curl -H "Origin: https://example.com" \
     -H "api-key: ${QDRANT_API_KEY}" \
     -v https://qdrant.harbor.fyi/collections 2>&1 | grep "Access-Control"

# Should see Access-Control-Allow-Origin header
```

### Test 6: Rate Limiting
```bash
# Send 150 requests (should trigger rate limit at 100/min)
for i in {1..150}; do
  curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections
done

# Should see 429 Too Many Requests after ~100 requests
```

## Rollback Plan

If something goes wrong:

### Rollback Step 1: Revert Qdrant Container
```bash
# Stop new container
docker stop qdrant

# Start old container without API keys
docker run -d --name qdrant \
  -p 6333:6333 \
  -v qdrant_storage:/qdrant/storage \
  qdrant/qdrant:v1.13.4
```

### Rollback Step 2: Disable Nginx Site
```bash
sudo rm /etc/nginx/sites-enabled/qdrant.harbor.fyi
sudo systemctl reload nginx
```

### Rollback Step 3: Update Scripts
```bash
# Revert to old URL in scripts
sed -i 's|https://qdrant.harbor.fyi|http://192.168.50.149:6333|g' script.sh
```

## Security Checklist

- [ ] API keys generated and stored in password manager
- [ ] `.env` file created and NOT committed to git
- [ ] `.env` added to `.gitignore`
- [ ] Qdrant container restarted with API key authentication
- [ ] API key authentication tested (401 without key, 200 with key)
- [ ] Read-only key restrictions verified (GET works, PUT fails)
- [ ] Cloudflare Origin Certificate obtained and installed
- [ ] Nginx configured with SSL and rate limiting
- [ ] Nginx configuration tested (`nginx -t`)
- [ ] Cloudflare DNS updated (A record, proxied, Full (strict) SSL)
- [ ] HTTPS access tested from external network
- [ ] (Optional) Cloudflare Access configured and tested
- [ ] (Optional) Tailscale access configured and tested
- [ ] All sync scripts updated with API key headers
- [ ] All scripts tested after updates
- [ ] Documentation updated with new HTTPS URLs
- [ ] Calendar reminder set for key rotation (90 days)
- [ ] Backup of Qdrant data verified
- [ ] Monitoring/alerting configured for failed auth attempts

## Maintenance

### Rotating API Keys (Every 90 Days)
```bash
# Generate new keys
cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant
./generate-keys.sh

# Update .env with new keys
nano .env

# Restart Qdrant
docker-compose restart qdrant

# Update all scripts with new keys
# Test all integrations
```

### Monitoring Logs
```bash
# Qdrant logs
docker logs -f qdrant

# Nginx access logs
sudo tail -f /var/log/nginx/qdrant.harbor.fyi.access.log

# Nginx error logs
sudo tail -f /var/log/nginx/qdrant.harbor.fyi.error.log

# Failed auth attempts
sudo grep "401\|403" /var/log/nginx/qdrant.harbor.fyi.access.log
```

### Backup Qdrant Data
```bash
# Create snapshot
curl -X POST -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/snapshots

# Download snapshot
curl -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/snapshots/snapshot-2024-01-01.snapshot \
     -o qdrant-backup-$(date +%Y%m%d).snapshot

# Or backup Docker volume
docker run --rm \
  -v qdrant_storage:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/qdrant-backup-$(date +%Y%m%d).tar.gz /source
```

## Troubleshooting

### Issue: Docker container won't start
```bash
# Check logs
docker logs qdrant

# Common causes:
# - Invalid API key format (must be non-empty string)
# - Port conflict (6333 already in use)
# - Volume permission issues

# Fix permissions
sudo chown -R 1000:1000 /var/lib/docker/volumes/qdrant_storage
```

### Issue: Nginx 502 Bad Gateway
```bash
# Check Qdrant is running
docker ps | grep qdrant

# Check Qdrant is responding
curl http://localhost:6333/healthz

# Check Nginx can reach Qdrant
docker exec -it nginx curl http://qdrant:6333/healthz

# Check Docker network
docker network inspect proxy
```

### Issue: SSL certificate not trusted
```bash
# Verify certificate
openssl x509 -in /etc/nginx/ssl/qdrant.harbor.fyi.pem -text -noout

# Check Cloudflare SSL mode (must be "Full (strict)")
# Check certificate is for correct domain
```

### Issue: Rate limiting too aggressive
```bash
# Edit Nginx config
sudo nano /etc/nginx/sites-available/qdrant.harbor.fyi

# Increase rate limits:
# limit_req_zone ... rate=100r/m;  → rate=500r/m;

# Reload Nginx
sudo systemctl reload nginx
```

## Support

For issues:
1. Check logs (Qdrant, Nginx, Docker)
2. Verify environment variables are set
3. Test API key authentication directly
4. Check Cloudflare dashboard for SSL/DNS issues
5. Review security documentation: `/Users/adamkovacs/Documents/codebuild/.claude/docs/QDRANT-SECURITY.md`
