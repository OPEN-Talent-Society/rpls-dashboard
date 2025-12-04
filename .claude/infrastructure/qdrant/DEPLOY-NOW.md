# Qdrant Security Deployment - Ready to Execute

**Generated:** 2025-12-03
**Status:** Ready for manual execution on Docker host

---

## Pre-Generated API Keys

Copy these to the Docker host and set as environment variables:

```bash
# Generated API Keys (from local .env file)
export QDRANT_API_KEY="$(cat /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/.env | grep QDRANT_API_KEY= | cut -d= -f2)"
export QDRANT_READ_ONLY_API_KEY="$(cat /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/.env | grep QDRANT_READ_ONLY_API_KEY= | cut -d= -f2)"
```

---

## Quick Deploy (SSH to Docker Host)

### Step 1: SSH to Docker Host

```bash
# Via Tailscale
ssh adam@100.114.104.8

# Or via LAN
ssh adam@192.168.50.149
```

### Step 2: Create Directory and Copy Files

On the Docker host:

```bash
mkdir -p /opt/qdrant
cd /opt/qdrant
```

### Step 3: Create docker-compose.yml

```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  qdrant:
    image: qdrant/qdrant:v1.13.4
    container_name: qdrant
    restart: unless-stopped
    ports:
      - "6333:6333"
      - "6334:6334"
    volumes:
      - qdrant_storage:/qdrant/storage
      - qdrant_snapshots:/qdrant/snapshots
    environment:
      - QDRANT__SERVICE__API_KEY=${QDRANT_API_KEY}
      - QDRANT__SERVICE__READ_ONLY_API_KEY=${QDRANT_READ_ONLY_API_KEY}
      - QDRANT__LOG_LEVEL=info
      - QDRANT__STORAGE__PERFORMANCE__MAX_SEARCH_THREADS=4
      - QDRANT__STORAGE__OPTIMIZERS__INDEXING_THRESHOLD=10000
      - QDRANT__SERVICE__ENABLE_CORS=true
    networks:
      - proxy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:6333/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  qdrant_storage:
    driver: local
  qdrant_snapshots:
    driver: local

networks:
  proxy:
    external: true
EOF
```

### Step 4: Create .env File with Keys

```bash
# PASTE YOUR ACTUAL KEYS HERE (from local machine)
cat > .env << 'EOF'
QDRANT_API_KEY=YOUR_ADMIN_KEY_HERE
QDRANT_READ_ONLY_API_KEY=YOUR_READONLY_KEY_HERE
EOF

# Or read from your local machine and scp:
# scp /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant/.env adam@192.168.50.149:/opt/qdrant/
```

### Step 5: Backup Current Data

```bash
# Create snapshot before restart
curl -X POST "http://localhost:6333/collections/agent_memory/snapshots"

# Verify snapshot created
curl http://localhost:6333/collections/agent_memory/snapshots
```

### Step 6: Restart Qdrant with Auth

```bash
cd /opt/qdrant

# Stop current container
docker stop qdrant
docker rm qdrant

# Start with new config
docker-compose up -d

# Check logs
docker logs -f qdrant
```

### Step 7: Test Authentication

```bash
# Without key (should fail with 403)
curl http://localhost:6333/collections
# Expected: {"status":{"error":"Forbidden: API key required"},"time":0.0}

# With key (should succeed)
source .env
curl -H "api-key: ${QDRANT_API_KEY}" http://localhost:6333/collections
# Expected: {"result":{"collections":[{"name":"agent_memory"}]}...}
```

---

## Alternative: One-Line Deploy

If you can SSH, run this single command from your Mac:

```bash
# Create deployment package
tar -czf /tmp/qdrant-deploy.tar.gz -C /Users/adamkovacs/Documents/codebuild/.claude/infrastructure/qdrant .

# Deploy via SSH (replace with your actual key/password method)
scp /tmp/qdrant-deploy.tar.gz adam@192.168.50.149:/tmp/
ssh adam@192.168.50.149 "cd /opt && mkdir -p qdrant && cd qdrant && tar -xzf /tmp/qdrant-deploy.tar.gz && docker-compose up -d"
```

---

## Update Client Scripts

After deployment, update your environment:

```bash
# Add to ~/.zshrc or ~/.bashrc
export QDRANT_URL="http://192.168.50.149:6333"
export QDRANT_API_KEY="your-admin-key"
```

---

## Verification Checklist

- [ ] SSH to Docker host
- [ ] Backup created
- [ ] docker-compose.yml created
- [ ] .env file with keys created
- [ ] Container restarted
- [ ] Auth test without key returns 403
- [ ] Auth test with key returns 200
- [ ] All 491 points still accessible
- [ ] Client scripts updated with API key
