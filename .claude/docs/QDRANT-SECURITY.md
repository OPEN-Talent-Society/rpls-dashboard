# Qdrant Security Configuration

## Current State (INSECURE)
- HTTP only, no SSL
- No API key authentication
- Publicly accessible at qdrant.harbor.fyi
- Direct port exposure: 192.168.50.149:6333
- No authentication headers

## Target State (3-Layer Security)

### Layer 1: Qdrant API Key Authentication
Qdrant supports built-in API key authentication for access control.

**Configuration:**
- Admin key for write operations (collections, points, indexes)
- Read-only key for search queries only
- Keys configured via environment variables
- Keys stored in `.env` (excluded from git)

**Environment Variables:**
```bash
QDRANT__SERVICE__API_KEY=<admin-key>
QDRANT__SERVICE__READ_ONLY_API_KEY=<read-only-key>
```

**Usage:**
```bash
# Admin operations (create collections, upsert points)
curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections

# Read-only operations (search, retrieve)
curl -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" https://qdrant.harbor.fyi/collections/my-collection/points/search
```

### Layer 2: Nginx + SSL + Cloudflare Access

**Nginx Configuration:**
- SSL termination via Cloudflare Origin Certificate
- Reverse proxy to internal Qdrant (qdrant:6333)
- Cloudflare Access validation (CF-Access-Client-Id/Secret headers)
- CORS headers for dashboard access
- Rate limiting for API endpoints

**Cloudflare Access Integration:**
- Same setup as Cortex (cortex.aienablement.academy)
- Service Token validation via headers
- Zero Trust network access
- Audit logs in Cloudflare dashboard

**Benefits:**
- End-to-end encryption (Cloudflare → Nginx → Qdrant)
- Additional authentication layer
- DDoS protection via Cloudflare
- Access logs and monitoring

### Layer 3: Tailscale (Alternative/Backup Access)

**Configuration:**
- Expose Qdrant on Tailscale network as `qdrant.tailnet`
- Accessible only to authenticated Tailscale devices
- No public internet exposure needed
- Direct access: `http://100.x.x.x:6333` (Tailscale IP)

**Use Cases:**
- Development and testing
- Emergency access if Cloudflare is down
- Internal admin operations
- Backup access method

**Benefits:**
- Zero configuration firewall
- Encrypted WireGuard tunnel
- Device authentication built-in
- Works from anywhere with Tailscale

## Implementation Steps

### Step 1: Generate Secure API Keys

Generate cryptographically secure API keys:

```bash
# Admin API key (64 characters, alphanumeric)
openssl rand -base64 48 | tr -d '/+=' | cut -c1-64

# Read-only API key (64 characters, alphanumeric)
openssl rand -base64 48 | tr -d '/+=' | cut -c1-64
```

Store these in your `.env` file (never commit to git):

```bash
# Qdrant Security
QDRANT_API_KEY=<admin-key-from-above>
QDRANT_READ_ONLY_API_KEY=<read-only-key-from-above>
QDRANT_URL=https://qdrant.harbor.fyi
```

### Step 2: Update Qdrant Docker Container

1. **Stop existing container:**
   ```bash
   docker stop qdrant && docker rm qdrant
   ```

2. **Deploy new configuration:**
   ```bash
   cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant
   docker-compose up -d
   ```

3. **Verify API key authentication:**
   ```bash
   # Should fail (no API key)
   curl https://qdrant.harbor.fyi/collections

   # Should succeed (with API key)
   curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections
   ```

### Step 3: Configure Nginx + SSL

1. **Obtain Cloudflare Origin Certificate:**
   - Login to Cloudflare dashboard
   - SSL/TLS → Origin Server → Create Certificate
   - Save certificate as `/etc/nginx/ssl/qdrant.harbor.fyi.pem`
   - Save private key as `/etc/nginx/ssl/qdrant.harbor.fyi.key`

2. **Deploy Nginx configuration:**
   ```bash
   # Copy configuration
   sudo cp /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/nginx.conf \
           /etc/nginx/sites-available/qdrant.harbor.fyi

   # Enable site
   sudo ln -s /etc/nginx/sites-available/qdrant.harbor.fyi \
              /etc/nginx/sites-enabled/

   # Test configuration
   sudo nginx -t

   # Reload
   sudo systemctl reload nginx
   ```

3. **Update Cloudflare DNS:**
   - Set `qdrant.harbor.fyi` to point to your homelab IP
   - Enable "Proxied" (orange cloud) for DDoS protection
   - Set SSL/TLS mode to "Full (strict)"

### Step 4: Configure Cloudflare Access (Optional)

1. **Create Service Token:**
   - Cloudflare Zero Trust → Access → Service Authentication
   - Create Service Token: "Qdrant API Access"
   - Save Client ID and Client Secret

2. **Add to `.env`:**
   ```bash
   CF_ACCESS_CLIENT_ID=<client-id>
   CF_ACCESS_CLIENT_SECRET=<client-secret>
   ```

3. **Create Access Policy:**
   - Application: `qdrant.harbor.fyi`
   - Policy: Allow Service Token
   - Service Token: Select "Qdrant API Access"

4. **Update sync scripts** to include headers:
   ```bash
   curl -H "api-key: ${QDRANT_API_KEY}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        https://qdrant.harbor.fyi/collections
   ```

### Step 5: Update All Sync Scripts

1. **Identify scripts using Qdrant:**
   ```bash
   cd /Users/adamkovacs/Documents/codebuild
   grep -r "qdrant" --include="*.sh" --include="*.js" --include="*.ts"
   ```

2. **Apply patch file:**
   ```bash
   # Provided in qdrant-security-patches.diff
   patch < .claude/infrastructure/qdrant/qdrant-security-patches.diff
   ```

3. **Manual updates needed:**
   - Add `api-key` header to all curl/fetch requests
   - Update `QDRANT_URL` from HTTP to HTTPS
   - Add Cloudflare Access headers (if enabled)

### Step 6: Configure Tailscale (Optional)

1. **Add Qdrant to Tailscale:**
   ```bash
   # On homelab server
   sudo tailscale up --advertise-routes=192.168.50.0/24
   ```

2. **Access via Tailscale:**
   ```bash
   # Get Tailscale IP
   tailscale ip -4

   # Access Qdrant
   curl -H "api-key: ${QDRANT_API_KEY}" http://100.x.x.x:6333/collections
   ```

3. **Update `.env` with Tailscale URL:**
   ```bash
   QDRANT_TAILSCALE_URL=http://100.x.x.x:6333
   ```

## Security Best Practices

### API Key Management
- ✅ Never commit API keys to git
- ✅ Use separate keys for read/write operations
- ✅ Rotate keys every 90 days
- ✅ Use environment variables or secret management
- ✅ Audit API key usage in logs

### Network Security
- ✅ Use HTTPS for all external access
- ✅ Enable Cloudflare proxy for DDoS protection
- ✅ Implement rate limiting (Nginx)
- ✅ Use Tailscale for internal access
- ✅ Block direct IP access (only domain access)

### Monitoring & Auditing
- ✅ Enable Qdrant logs: `QDRANT__LOG_LEVEL=info`
- ✅ Monitor failed authentication attempts
- ✅ Set up alerts for unusual API usage
- ✅ Review Cloudflare Access logs weekly
- ✅ Track collection modifications

### Backup & Recovery
- ✅ Backup Qdrant data directory: `/qdrant/storage`
- ✅ Store backups encrypted
- ✅ Test restoration process monthly
- ✅ Document API key recovery process
- ✅ Keep Tailscale access as backup

## Testing Security

### Test 1: API Key Authentication
```bash
# Should fail (401 Unauthorized)
curl https://qdrant.harbor.fyi/collections

# Should succeed (200 OK)
curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections

# Should fail for write with read-only key (403 Forbidden)
curl -X PUT -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
     https://qdrant.harbor.fyi/collections/test
```

### Test 2: SSL/TLS
```bash
# Check SSL certificate
openssl s_client -connect qdrant.harbor.fyi:443 -servername qdrant.harbor.fyi

# Verify TLS version (should be TLS 1.2+)
curl -vI https://qdrant.harbor.fyi 2>&1 | grep "TLS"
```

### Test 3: Cloudflare Access
```bash
# Should fail (CF Access blocked)
curl -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections

# Should succeed (with CF headers)
curl -H "api-key: ${QDRANT_API_KEY}" \
     -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
     -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
     https://qdrant.harbor.fyi/collections
```

### Test 4: Tailscale Access
```bash
# Should succeed (on Tailscale network)
curl -H "api-key: ${QDRANT_API_KEY}" http://100.x.x.x:6333/collections

# Should fail (not on Tailscale network)
# Test from external network
```

## Troubleshooting

### Issue: 401 Unauthorized
**Cause:** Missing or invalid API key
**Solution:**
```bash
# Verify API key is set
echo $QDRANT_API_KEY

# Test with explicit key
curl -H "api-key: your-actual-key-here" https://qdrant.harbor.fyi/collections
```

### Issue: SSL Certificate Error
**Cause:** Cloudflare Origin Certificate not trusted
**Solution:**
```bash
# Check certificate
sudo ls -la /etc/nginx/ssl/qdrant.harbor.fyi*

# Verify Nginx SSL config
sudo nginx -t

# Check Cloudflare SSL mode (should be "Full (strict)")
```

### Issue: Cloudflare Access Blocked
**Cause:** Missing or invalid CF-Access headers
**Solution:**
```bash
# Verify service token is active in Cloudflare dashboard
# Check headers are correct
curl -v -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        https://qdrant.harbor.fyi/collections
```

### Issue: Cannot Connect via Tailscale
**Cause:** Subnet routes not advertised
**Solution:**
```bash
# On homelab server
sudo tailscale up --advertise-routes=192.168.50.0/24 --accept-routes

# Verify routes
tailscale status
```

## Migration Checklist

- [ ] Generate API keys
- [ ] Update `.env` with keys
- [ ] Stop existing Qdrant container
- [ ] Deploy new docker-compose.yml
- [ ] Verify API key authentication works
- [ ] Obtain Cloudflare Origin Certificate
- [ ] Configure Nginx with SSL
- [ ] Update Cloudflare DNS settings
- [ ] Test HTTPS access
- [ ] (Optional) Configure Cloudflare Access
- [ ] (Optional) Set up Tailscale access
- [ ] Update all sync scripts with API keys
- [ ] Test all endpoints
- [ ] Document API keys in password manager
- [ ] Set calendar reminder for key rotation (90 days)

## References

- [Qdrant Security Documentation](https://qdrant.tech/documentation/guides/security/)
- [Cloudflare Origin Certificates](https://developers.cloudflare.com/ssl/origin-configuration/origin-ca/)
- [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/applications/configure-apps/)
- [Tailscale Subnet Routers](https://tailscale.com/kb/1019/subnets/)
- [Nginx SSL Configuration](https://nginx.org/en/docs/http/configuring_https_servers.html)
