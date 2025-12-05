# Service Cleanup Plan
**Created:** 2025-12-05
**Status:** Ready for execution
**Objective:** Remove unused services and fix broken deployments

---

## Services Identified for Removal

### Homelab Docker (VM 101)

#### 1. mem0.harbor.fyi ❌ REMOVE
**Status:** 502 Bad Gateway (backend service down)
**Reason:** Not in use, service is broken
**Impact:** None - service not operational
**Action:**
```bash
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62 "qm guest exec 101 -- bash -c 'docker ps -a | grep mem0'"
# Identify container
docker stop <mem0-container>
docker rm <mem0-container>
# Remove from NPM proxy host
# Remove DNS record from Cloudflare
```

#### 2. library.harbor.fyi ⚠️ INVESTIGATE FIRST
**Status:** Connection timeout
**Reason:** Unknown purpose, not responding
**Impact:** Unknown - needs investigation
**Action:**
```bash
# First find out what this is
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62 "qm guest exec 101 -- bash -c 'docker ps -a | grep -i library'"
# Check if anyone is using it
grep -r "library.harbor.fyi" /Users/adamkovacs/Documents/codebuild/
# Then decide: remove or fix
```

---

### OCI Docker (163.192.41.116)

#### 3. dash.aienablement.academy 🔧 FIX REQUIRED
**Status:** 525 SSL handshake failure
**Reason:** SSL/TLS certificate issue
**Impact:** Dashboard not accessible
**Action:**
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116
cd /srv/dash
docker compose logs caddy | grep dash
# Check Caddy certificate acquisition
# Verify Cloudflare DNS/proxy settings
# Test: curl https://dash.aienablement.academy
```

**Root Cause Analysis Needed:**
- Check if Caddy acquired cert for dash.aienablement.academy
- Verify Cloudflare proxy is set to DNS Only during ACME challenge
- Check `/srv/proxy/Caddyfile` for dash block
- Review Caddy logs for ACME errors

#### 4. Mailpit Container ✅ CONFIRM REMOVAL
**Status:** Should have been removed (per activity.json 2025-10-21)
**Reason:** Replaced by Brevo SMTP
**Impact:** None if Brevo is working
**Action:**
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116
docker ps -a | grep mailpit
# If exists:
docker stop mailpit && docker rm mailpit
docker volume rm docmost_mailpit_data
```

#### 5. Broken Cal.com Stack 🔧 FIX OR REMOVE
**Status:** Per infrastructure discovery - 3 broken containers
- supabase-auth (exited)
- supabase-realtime (exited)
**Reason:** Cal.com dependencies broken
**Impact:** calendar.aienablement.academy may be affected
**Action:**
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116
docker ps -a | grep -E "cal|supabase"
# Check if Cal.com is actually working
curl -I https://calendar.aienablement.academy
# If working: investigate why dependencies show as exited
# If broken: restart stack or remove if not critical
```

---

## Cleanup Process

### Phase 1: Investigation (Before Removal)

For each service:
1. **Check Dependencies**
   ```bash
   # Search codebase for references
   grep -r "service-name" /Users/adamkovacs/Documents/codebuild/
   # Check Docker links/networks
   docker inspect <container> | grep -A 10 "Networks\|Links"
   ```

2. **Check Usage**
   ```bash
   # Check nginx/caddy logs for recent access
   docker logs <proxy> --since 7d | grep service-domain
   # Check Uptime Kuma for monitors
   ```

3. **Backup Configuration**
   ```bash
   # Save docker-compose.yml
   # Save .env files
   # Export container config
   docker inspect <container> > container-backup.json
   ```

### Phase 2: Removal (After Confirmation)

1. **Stop Container**
   ```bash
   docker stop <container-name>
   ```

2. **Remove Container**
   ```bash
   docker rm <container-name>
   ```

3. **Remove Volumes** (if applicable)
   ```bash
   docker volume rm <volume-name>
   ```

4. **Remove Proxy Configuration**
   - NPM: Delete proxy host via UI or SQL
   - Caddy: Remove block from Caddyfile and reload

5. **Remove DNS Records**
   - Cloudflare: Delete A/CNAME record
   - Document in cleanup log

6. **Update Documentation**
   - Remove from infrastructure inventory
   - Update monitoring plan
   - Add to cleanup log below

---

## Cleanup Execution Log

| Date | Service | Action | Result | Notes |
|------|---------|--------|--------|-------|
| | | | | |

---

## Services Requiring Fixes (Not Removal)

### 1. dash.aienablement.academy (SSL Issue)

**Problem:** HTTP 525 (SSL handshake failed)

**Diagnosis Steps:**
```bash
# 1. Check Caddy logs
ssh ubuntu@163.192.41.116
docker logs proxy-caddy-1 2>&1 | grep -A 5 "dash"

# 2. Check Cloudflare DNS
curl -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=dash.aienablement.academy" \
  -H "Authorization: Bearer $CF_TOKEN"

# 3. Check Caddyfile
cat /srv/proxy/Caddyfile | grep -A 10 "dash"

# 4. Test direct connection
curl -k https://163.192.41.116 -H "Host: dash.aienablement.academy"
```

**Possible Fixes:**
1. **Cloudflare Proxy Issue**
   - Set to DNS Only (grey cloud)
   - Let Caddy acquire cert
   - Re-enable proxy (orange cloud)

2. **Caddy Config Issue**
   - Check if dash block exists in Caddyfile
   - Reload: `docker exec proxy-caddy-1 caddy reload --config /etc/caddy/Caddyfile`

3. **Certificate Issue**
   - Delete cert: `docker exec proxy-caddy-1 rm -rf /data/caddy/certificates`
   - Restart: `docker restart proxy-caddy-1`

### 2. nas.harbor.fyi (Configuration)

**Status:** ✅ Fixed (updated to HTTP port 80)
**Remaining Issue:** May need to handle HTTPS redirect from QNAP

**If HTTPS is required:**
```bash
# QNAP redirects HTTP -> HTTPS:8081
# Option 1: Update NPM to use HTTPS backend
UPDATE proxy_host SET forward_scheme='https', forward_port=8081 WHERE id=9;

# Option 2: Let NPM handle redirect from QNAP
# Current config should work - QNAP will redirect internally
```

### 3. Cal.com Supabase Containers

**Problem:** supabase-auth and supabase-realtime exited

**Diagnosis:**
```bash
# Check Cal.com stack
docker ps -a | grep cal
docker compose -f /path/to/cal/docker-compose.yml ps

# Check logs
docker logs supabase-auth
docker logs supabase-realtime
```

**Fix:**
- Restart stack: `docker compose restart`
- Check environment variables
- Verify database connectivity
- OR remove if Cal.com works without them (possible misconfiguration)

---

## Disk Space Recovery (OCI @ 83%)

**Target:** Free up 20-30% of disk space

### Candidates for Cleanup:

1. **Docker Images**
   ```bash
   # List all images with size
   docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"

   # Remove unused images
   docker image prune -a --filter "until=24h"
   ```

2. **Docker Volumes**
   ```bash
   # List volumes with size
   docker volume ls

   # Remove unused volumes
   docker volume prune
   ```

3. **Old Backups**
   ```bash
   # Check backup directory size
   du -sh /srv/backups/*

   # Keep only last 7 days of dailies (already configured in backup script)
   # But check if old backups exist
   ls -lh /srv/backups/daily/
   ```

4. **Logs**
   ```bash
   # Check log sizes
   du -sh /var/log/*
   journalctl --disk-usage

   # Clean old logs
   journalctl --vacuum-time=7d
   ```

5. **Docker Build Cache**
   ```bash
   docker builder prune -a
   ```

**Expected Recovery:** 10-20 GB

---

## Post-Cleanup Verification

After each removal/fix:

1. **Test Remaining Services**
   ```bash
   # Test each domain
   curl -I https://<domain>
   ```

2. **Check Monitoring**
   - Remove monitors from Uptime Kuma
   - Update Netdata dashboards

3. **Update Documentation**
   - infrastructure-discovery-report.md
   - CONSOLIDATED-MONITORING-PLAN.md
   - This file (cleanup log)

4. **Commit Changes**
   ```bash
   git add .
   git commit -m "chore: cleanup unused services [removed: mem0, library, mailpit]"
   ```

---

## Risk Assessment

| Service | Risk of Removal | Mitigation |
|---------|-----------------|------------|
| mem0 | LOW | Not operational, no dependencies found |
| library | MEDIUM | Unknown purpose - investigate first |
| mailpit | LOW | Brevo confirmed working, backups available |
| dash (fix) | NONE | Fix only, no removal |
| Cal.com containers | MEDIUM | Check if Cal.com works without them |

---

## Success Criteria

- ✅ All broken services either fixed or removed
- ✅ Disk space below 70% on OCI
- ✅ No broken containers in `docker ps -a`
- ✅ All remaining services have Uptime Kuma monitors
- ✅ Documentation updated
- ✅ No dependencies broken by removals
