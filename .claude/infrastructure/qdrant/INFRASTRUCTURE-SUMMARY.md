# Qdrant Secured Infrastructure - Complete Configuration

**Created**: 2025-12-03
**Status**: Ready for deployment
**Environment**: Homelab with Docker + Nginx reverse proxy

---

## Overview

This infrastructure setup provides a **three-layer secured Qdrant deployment**:

1. **Layer 1**: Docker container with API key authentication (admin + read-only)
2. **Layer 2**: Nginx reverse proxy with SSL/TLS (Cloudflare Origin Certificate)
3. **Layer 3**: Optional Tailscale VPN access for private network connectivity

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ External Clients                                              │
│ (Applications, APIs, Dashboards)                             │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS
                         │ api-key header
                         │
        ┌────────────────▼────────────────┐
        │ Nginx Reverse Proxy              │
        │ (192.168.50.45:443)              │
        │                                  │
        │ • SSL/TLS (Cloudflare cert)      │
        │ • Rate limiting                  │
        │ • CORS headers                   │
        │ • Request validation             │
        │ • Optional: Cloudflare Access    │
        └────────────────┬────────────────┘
                         │ HTTP (internal only)
                         │ 127.0.0.1:6333
                         │
        ┌────────────────▼────────────────┐
        │ Docker Host (192.168.50.149)     │
        │                                  │
        │  ┌──────────────────────────┐   │
        │  │ Qdrant Container         │   │
        │  │ • Port 6333 (REST)       │   │
        │  │ • Port 6334 (gRPC)       │   │
        │  │ • API key auth (enforced)│   │
        │  │ • Data volumes mounted   │   │
        │  └──────────────────────────┘   │
        │                                  │
        │  Volumes:                        │
        │  • qdrant_storage                │
        │  • qdrant_snapshots              │
        └──────────────────────────────────┘

Optional: Tailscale VPN for private network access
```

---

## Files Created/Updated

### 1. Docker Configuration

**File**: `/Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/docker-compose.yml`

```yaml
version: '3.8'
services:
  qdrant:
    image: qdrant/qdrant:v1.13.4
    container_name: qdrant
    restart: unless-stopped
    ports:
      - "127.0.0.1:6333:6333"  # Only localhost (nginx proxies)
      - "127.0.0.1:6334:6334"  # gRPC
    volumes:
      - qdrant_storage:/qdrant/storage
      - qdrant_snapshots:/qdrant/snapshots
    environment:
      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}
      - QDRANT__SERVICE__READ_ONLY_API_KEY=${QDRANT_READ_ONLY_API_KEY}
      - QDRANT__LOG_LEVEL=info
      - QDRANT__SERVICE__ENABLE_CORS=true
    networks:
      - proxy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
```

**Key Features**:
- Listens on localhost only (port 6333)
- API key authentication enforced
- Separate read-only API key support
- Health checks enabled
- Docker volume persistence
- External Docker network for proxy communication

### 2. Nginx Reverse Proxy Configuration

**File**: `/Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/nginx.conf`

**Path on Nginx Host**: `/etc/nginx/sites-available/qdrant.harbor.fyi`

```nginx
# Key features:
- SSL/TLS with Cloudflare Origin Certificate
- Rate limiting zones:
  • 100 req/min for API operations
  • 500 req/min for search operations
- Security headers:
  • Strict-Transport-Security (HSTS)
  • X-Frame-Options
  • X-Content-Type-Options
  • X-XSS-Protection
- CORS headers for dashboard access
- API key validation (401 if missing)
- Separate location blocks for:
  • Dashboard (read-only)
  • Health checks (no rate limit)
  • Metrics (authenticated)
  • Collections API (write operations)
  • Search API (higher rate limit)
  • All other endpoints
- Timeouts optimized for each operation type
- 100MB max body size for bulk operations
```

### 3. Deployment Script

**File**: `/Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/deploy.sh`
**Permissions**: `755` (executable)

**Features**:
- Pre-deployment checks (Docker, networks, volumes)
- Automatic container deployment
- Health check with 30-second timeout
- API key authentication testing
- Read-only key verification
- Comprehensive deployment verification
- Rollback capability
- Color-coded output
- Detailed logging

**Usage**:
```bash
# Basic deployment
./deploy.sh

# Deploy with verification
./deploy.sh --verify

# Rollback deployment
./deploy.sh --rollback

# Show help
./deploy.sh --help
```

### 4. Supporting Files

| File | Purpose |
|------|---------|
| `.env.example` | Environment variables template |
| `generate-keys.sh` | Generate secure 64-char API keys |
| `test-security.sh` | Verify security configuration |
| `qdrant-security-patches.diff` | Patterns for updating integration scripts |
| `DEPLOYMENT.md` | Comprehensive deployment guide |
| `README.md` | Quick start and reference |

---

## Environment Variables

**Required** - Set in `.env` (not committed to git):

```bash
# API Keys (64-char alphanumeric, generated by ./generate-keys.sh)
QDRANT_API_KEY=your-admin-api-key-here
QDRANT_READ_ONLY_API_KEY=your-readonly-api-key-here

# URLs
QDRANT_URL=https://qdrant.harbor.fyi
QDRANT_TAILSCALE_URL=http://100.x.x.x:6333  # Optional

# Optional: Cloudflare Access credentials
CF_ACCESS_CLIENT_ID=your-client-id
CF_ACCESS_CLIENT_SECRET=your-client-secret
```

---

## Deployment Steps

### Step 1: Generate API Keys
```bash
cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant
./generate-keys.sh
```
This creates a `.env` file with secure, random API keys.

### Step 2: Deploy Qdrant Container
```bash
# Option A: Using deploy script (recommended)
./deploy.sh --verify

# Option B: Manual deployment
docker-compose up -d
docker logs -f qdrant
```

### Step 3: Test Locally
```bash
# Load environment
source .env

# Test without API key (should fail with 401)
curl -v http://localhost:6333/collections

# Test with API key (should succeed with 200)
curl -v -H "api-key: ${QDRANT_API_KEY}" http://localhost:6333/collections
```

### Step 4: Configure Nginx (on 192.168.50.45)
```bash
# Copy configuration
sudo cp nginx.conf /etc/nginx/sites-available/qdrant.harbor.fyi

# Enable site
sudo ln -s /etc/nginx/sites-available/qdrant.harbor.fyi \
           /etc/nginx/sites-enabled/

# Create SSL directory
sudo mkdir -p /etc/nginx/ssl

# Add Cloudflare Origin Certificate (manual step)
# 1. Generate in Cloudflare dashboard
# 2. Save to /etc/nginx/ssl/qdrant.harbor.fyi.pem
# 3. Save key to /etc/nginx/ssl/qdrant.harbor.fyi.key
# 4. Set permissions: sudo chmod 600 *.key && sudo chmod 644 *.pem

# Test and reload
sudo nginx -t
sudo systemctl reload nginx
```

### Step 5: Configure Cloudflare DNS
1. Login to Cloudflare dashboard (https://dash.cloudflare.com)
2. Select domain: `harbor.fyi`
3. DNS Records:
   - Add A record: `qdrant.harbor.fyi` → `192.168.50.45`
   - Enable "Proxied" (orange cloud)
   - SSL/TLS mode: "Full (strict)"

### Step 6: Update Integration Scripts
```bash
# Find scripts using Qdrant
grep -r "192.168.50.149:6333" /Users/adamkovacs/Documents/codebuild

# Update URLs in each script
# From: http://192.168.50.149:6333
# To: https://qdrant.harbor.fyi
# Add: -H "api-key: ${QDRANT_API_KEY}"
```

---

## Verification Tests

### Test 1: API Key Required
```bash
# Should return 401 Unauthorized
curl -v https://qdrant.harbor.fyi/collections
```

### Test 2: Valid API Key Works
```bash
# Should return 200 OK with collections list
curl -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/collections
```

### Test 3: Read-Only Key Restrictions
```bash
# GET should work
curl -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
     https://qdrant.harbor.fyi/collections

# PUT should fail (403 Forbidden)
curl -X PUT \
     -H "api-key: ${QDRANT_READ_ONLY_API_KEY}" \
     -H "Content-Type: application/json" \
     -d '{"vectors": {"size": 128, "distance": "Cosine"}}' \
     https://qdrant.harbor.fyi/collections/test
```

### Test 4: SSL/TLS Certificate
```bash
# Verify certificate
openssl s_client -connect qdrant.harbor.fyi:443 \
  -servername qdrant.harbor.fyi < /dev/null 2>&1 | grep "Verify return code"
# Should show: Verify return code: 0 (ok)
```

### Test 5: Rate Limiting
```bash
# Send 150 requests (should hit limit at 100/min)
for i in {1..150}; do
  curl -H "api-key: ${QDRANT_API_KEY}" \
       https://qdrant.harbor.fyi/collections
done
# Should see 429 Too Many Requests after ~100 requests
```

---

## Security Features

### API Key Authentication
- **Admin Key**: Full read/write access
- **Read-Only Key**: Search queries only
- Keys stored in environment variables
- 64-character alphanumeric format
- Enforced at Qdrant container level

### Network Security
- Qdrant listens on localhost only (127.0.0.1:6333)
- Nginx reverse proxy in front
- No direct access from external networks
- Cloudflare Origin Certificate for encryption

### Rate Limiting
- 100 requests/minute for general API
- 500 requests/minute for search queries
- 10-20 request burst allowance
- Per-IP limiting

### Security Headers
- HSTS (Strict-Transport-Security)
- X-Frame-Options: SAMEORIGIN
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- CORS headers for dashboard

### Optional: Cloudflare Access
- Additional authentication layer
- Service token validation
- Client ID/Secret headers
- Uncomment nginx config to enable

### Optional: Tailscale VPN
- Private network access
- No public internet exposure
- Backup access method
- Cloudflare failover

---

## Maintenance

### API Key Rotation (Every 90 Days)
```bash
cd /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant

# Generate new keys
./generate-keys.sh

# Update .env
nano .env

# Restart Qdrant
docker-compose restart qdrant

# Update all integration scripts
# Test all endpoints
```

### Monitoring Logs

**Qdrant Container**:
```bash
docker logs -f qdrant
```

**Nginx Access**:
```bash
sudo tail -f /var/log/nginx/qdrant.harbor.fyi.access.log
```

**Failed Auth Attempts**:
```bash
sudo grep "401\|403" /var/log/nginx/qdrant.harbor.fyi.access.log
```

### Backup Data

**Via API**:
```bash
source .env
curl -X POST -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/snapshots
```

**Via Docker Volume**:
```bash
docker run --rm \
  -v qdrant_storage:/source \
  -v $(pwd):/backup \
  alpine tar czf /backup/qdrant-backup-$(date +%Y%m%d).tar.gz /source
```

---

## Troubleshooting

### Container Won't Start
```bash
# Check logs
docker logs qdrant

# Common issues:
# - Port 6333/6334 already in use
# - Invalid API key format
# - Volume permission issues

# Fix permissions
sudo chown -R 1000:1000 /var/lib/docker/volumes/qdrant_storage
```

### Nginx 502 Bad Gateway
```bash
# Verify Qdrant is running
docker ps | grep qdrant

# Test connection
curl http://localhost:6333/healthz

# Check Docker network
docker network inspect proxy
```

### SSL Certificate Not Trusted
```bash
# Verify certificate details
openssl x509 -in /etc/nginx/ssl/qdrant.harbor.fyi.pem -text -noout

# Common issues:
# - Certificate expired
# - Wrong domain name
# - Cloudflare SSL mode not "Full (strict)"
```

### Rate Limiting Too Aggressive
```bash
# Edit Nginx config
sudo nano /etc/nginx/sites-available/qdrant.harbor.fyi

# Increase limits:
# limit_req_zone ... rate=100r/m;  → rate=500r/m;

# Reload Nginx
sudo systemctl reload nginx
```

---

## File Paths Summary

All files created in `/Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/`:

| File | Size | Executable | Purpose |
|------|------|-----------|---------|
| `deploy.sh` | 10 KB | ✅ | Main deployment script |
| `docker-compose.yml` | 1.2 KB | ❌ | Docker configuration |
| `nginx.conf` | 6.5 KB | ❌ | Nginx reverse proxy config |
| `generate-keys.sh` | 2.1 KB | ✅ | API key generator |
| `test-security.sh` | 6.6 KB | ✅ | Security verification tests |
| `.env.example` | 895 B | ❌ | Environment template |
| `DEPLOYMENT.md` | 10 KB | ❌ | Detailed deployment guide |
| `README.md` | 4.4 KB | ❌ | Quick start and reference |
| `qdrant-security-patches.diff` | 4.0 KB | ❌ | Script update patterns |
| `INFRASTRUCTURE-SUMMARY.md` | This file | ❌ | Complete overview |

---

## Integration Points

### Qdrant URLs
- **External (HTTPS)**: `https://qdrant.harbor.fyi`
- **Internal (HTTP)**: `http://localhost:6333` (Docker host only)
- **Tailscale (Private)**: `http://100.x.x.x:6333` (optional)

### Header Requirements
All requests to Qdrant must include:
```bash
-H "api-key: ${QDRANT_API_KEY}"
```

### Example cURL Requests
```bash
# List collections
curl -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/collections

# Search vectors
curl -X POST \
     -H "api-key: ${QDRANT_API_KEY}" \
     -H "Content-Type: application/json" \
     -d '{...}' \
     https://qdrant.harbor.fyi/collections/my_collection/points/search

# Get metrics
curl -H "api-key: ${QDRANT_API_KEY}" \
     https://qdrant.harbor.fyi/metrics

# Access dashboard
# Browser: https://qdrant.harbor.fyi/dashboard
```

---

## Network Topology

```
Homelab Network (192.168.50.0/24)
├── Docker Host (192.168.50.149)
│   └── Qdrant Container (port 6333/6334)
│       └── Docker network: proxy
│           ├── Volume: qdrant_storage
│           └── Volume: qdrant_snapshots
│
├── Nginx Proxy (192.168.50.45)
│   └── https://qdrant.harbor.fyi:443
│       └── Proxies to: http://192.168.50.149:6333
│
└── Cloudflare (External)
    ├── DNS: qdrant.harbor.fyi → 192.168.50.45
    ├── Origin Certificate (for Nginx SSL)
    └── SSL/TLS mode: Full (strict)

Optional:
└── Tailscale VPN
    └── Private access: http://100.x.x.x:6333
```

---

## Checklist for Deployment

- [ ] Review this documentation
- [ ] Generate API keys: `./generate-keys.sh`
- [ ] Deploy Qdrant: `./deploy.sh --verify`
- [ ] Test local API access with API key
- [ ] Obtain Cloudflare Origin Certificate
- [ ] Configure Nginx on 192.168.50.45
- [ ] Install SSL certificates
- [ ] Test Nginx configuration: `sudo nginx -t`
- [ ] Configure Cloudflare DNS
- [ ] Test HTTPS access from external network
- [ ] Update all integration scripts
- [ ] Test all endpoints
- [ ] Document keys in password manager
- [ ] Set up monitoring and alerting
- [ ] Schedule API key rotation (90-day reminder)
- [ ] Backup Qdrant data
- [ ] Archive this documentation in Cortex

---

## Support & Resources

- **Qdrant Documentation**: https://qdrant.tech/documentation/
- **Docker Documentation**: https://docs.docker.com/
- **Nginx Documentation**: https://nginx.org/en/docs/
- **Cloudflare SSL**: https://developers.cloudflare.com/ssl/
- **Tailscale**: https://tailscale.com/kb/
- **Local Security Guide**: `.claude/docs/QDRANT-SECURITY.md`

---

**Last Updated**: 2025-12-03
**Version**: 1.0
**Status**: Ready for deployment
