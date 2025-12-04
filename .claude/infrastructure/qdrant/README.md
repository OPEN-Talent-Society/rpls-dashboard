# Qdrant Security Infrastructure

This directory contains security configuration for Qdrant vector database.

## Quick Start

```bash
# 1. Generate API keys
./generate-keys.sh

# 2. Deploy secured Qdrant
docker-compose up -d

# 3. Test security
./test-security.sh

# 4. Configure Nginx + SSL (see DEPLOYMENT.md)

# 5. Update sync scripts (see qdrant-security-patches.diff)
```

## Files

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Qdrant with API key authentication |
| `nginx.conf` | Nginx reverse proxy with SSL and rate limiting |
| `.env.example` | Environment variables template |
| `generate-keys.sh` | Generate secure API keys |
| `test-security.sh` | Verify security configuration |
| `qdrant-security-patches.diff` | Patterns for updating scripts |
| `DEPLOYMENT.md` | Step-by-step deployment guide |

## Documentation

- **Security Guide**: `/Users/adamkovacs/Documents/codebuild/.claude/docs/QDRANT-SECURITY.md`
- **Deployment Guide**: `DEPLOYMENT.md`
- **Patch Reference**: `qdrant-security-patches.diff`

## Security Layers

### Layer 1: API Key Authentication
- Admin key: Full access (read/write)
- Read-only key: Search queries only
- Keys in environment variables

### Layer 2: Nginx + SSL
- SSL termination (Cloudflare Origin Certificate)
- Rate limiting (100 req/min API, 500 req/min search)
- CORS headers for dashboard
- Optional: Cloudflare Access validation

### Layer 3: Tailscale (Optional)
- Private network access
- No public exposure
- Backup access method

## Environment Variables

```bash
# Required
QDRANT_API_KEY=<64-char-admin-key>
QDRANT_READ_ONLY_API_KEY=<64-char-readonly-key>
QDRANT_URL=https://qdrant.harbor.fyi

# Optional: Cloudflare Access
CF_ACCESS_CLIENT_ID=<client-id>
CF_ACCESS_CLIENT_SECRET=<client-secret>

# Optional: Tailscale
QDRANT_TAILSCALE_URL=http://100.x.x.x:6333
```

## Usage Examples

### Basic Query
```bash
curl -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/collections
```

### With Cloudflare Access
```bash
curl -H "api-key: ${QDRANT_API_KEY}" \
     -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
     -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
     https://qdrant.harbor.fyi/collections
```

### JavaScript/TypeScript
```javascript
const response = await fetch('https://qdrant.harbor.fyi/collections', {
  headers: {
    'api-key': process.env.QDRANT_API_KEY
  }
});
```

### Python
```python
import requests
import os

headers = {'api-key': os.environ['QDRANT_API_KEY']}
response = requests.get('https://qdrant.harbor.fyi/collections', headers=headers)
```

## Deployment Checklist

- [ ] Generate API keys: `./generate-keys.sh`
- [ ] Deploy Qdrant: `docker-compose up -d`
- [ ] Test API keys: `./test-security.sh`
- [ ] Obtain Cloudflare Origin Certificate
- [ ] Configure Nginx: `sudo cp nginx.conf /etc/nginx/sites-available/`
- [ ] Enable SSL: Add certificate to `/etc/nginx/ssl/`
- [ ] Test Nginx: `sudo nginx -t`
- [ ] Update Cloudflare DNS (A record, proxied, Full strict SSL)
- [ ] Update sync scripts (see `qdrant-security-patches.diff`)
- [ ] Test all integrations
- [ ] Document keys in password manager
- [ ] Set key rotation reminder (90 days)

## Maintenance

### Rotate API Keys (Every 90 Days)
```bash
./generate-keys.sh
docker-compose restart qdrant
# Update all sync scripts
```

### Monitor Logs
```bash
# Qdrant
docker logs -f qdrant

# Nginx
sudo tail -f /var/log/nginx/qdrant.harbor.fyi.access.log
```

### Backup Data
```bash
# Via API
curl -X POST -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/snapshots

# Via Docker volume
docker run --rm \
  -v qdrant_storage:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/qdrant-backup-$(date +%Y%m%d).tar.gz /source
```

## Troubleshooting

### Test API Key
```bash
# Should fail (401)
curl -v https://qdrant.harbor.fyi/collections

# Should work (200)
curl -v -H "api-key: ${QDRANT_API_KEY}" https://qdrant.harbor.fyi/collections
```

### Check Container
```bash
docker ps | grep qdrant
docker logs qdrant
docker inspect qdrant
```

### Check SSL
```bash
openssl s_client -connect qdrant.harbor.fyi:443 -servername qdrant.harbor.fyi
```

### Test Nginx
```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

## Support

- **Security Documentation**: `.claude/docs/QDRANT-SECURITY.md`
- **Deployment Guide**: `DEPLOYMENT.md`
- **Qdrant Docs**: https://qdrant.tech/documentation/
- **Cloudflare SSL**: https://developers.cloudflare.com/ssl/
- **Tailscale**: https://tailscale.com/kb/
