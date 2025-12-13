---
name: "Caddy Config Manager"
description: "Caddy reverse proxy configuration management. Alternative to NPM for simpler use cases, automatic HTTPS, and API-driven config updates."
triggers:
  - configure caddy
  - add reverse proxy
  - caddy api config
  - automatic https
  - update caddy routes
  - caddy configuration
  - manage proxy routes
---

# Caddy Config Manager

## Overview

This skill provides Caddy reverse proxy operations:
1. **Configuration management**: Update Caddy config via API or file
2. **Automatic HTTPS**: Zero-config SSL with Let's Encrypt
3. **Dynamic routing**: Add/remove routes without restart
4. **API-driven**: Manage config via REST API
5. **NPM alternative**: Simpler alternative for basic reverse proxy needs

## Token Savings

- **No MCP needed**: Uses Caddy CLI and API directly
- **Lightweight**: Shell scripts and curl commands only

---

## What This Skill Does

Manage Caddy reverse proxy operations:
1. Add/remove reverse proxy routes
2. Manage SSL certificates (automatic)
3. Update configuration via API
4. Monitor proxy health
5. Integrate with Tailscale network

## Caddy Environment

**Current Status:**
- **Not yet deployed** - Future alternative to NPM
- **Planned**: LXC or Docker container on Proxmox
- **Use case**: Lightweight services, API-driven config, dev environments

**When to Use Caddy vs NPM:**

| Feature | NPM | Caddy |
|---------|-----|-------|
| Web UI | Yes | No (API only) |
| Automatic HTTPS | Yes (manual setup) | Yes (zero-config) |
| Database | SQLite | No database (JSON file) |
| Dynamic config | Manual/DB edit | API-driven |
| Complexity | Medium | Low |
| Best for | Production, many services | Dev, API-driven, simple setups |

---

## Quick Reference

### Caddy Installation

**Docker:**
```bash
docker run -d \
  --name caddy \
  -p 80:80 \
  -p 443:443 \
  -p 2019:2019 \
  -v caddy_data:/data \
  -v caddy_config:/config \
  -v /path/to/Caddyfile:/etc/caddy/Caddyfile \
  caddy:latest
```

**LXC (Debian):**
```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update
apt install caddy
```

### Caddyfile Example

```caddyfile
# /etc/caddy/Caddyfile

# Enable API
{
    admin 0.0.0.0:2019
}

# Reverse proxy for Cortex
cortex.harbor.fyi {
    reverse_proxy 100.108.72.90:3000
}

# Reverse proxy for Qdrant
qdrant.harbor.fyi {
    reverse_proxy 100.108.72.90:6333
}

# Reverse proxy with custom headers
api.harbor.fyi {
    reverse_proxy 100.108.72.90:8000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
    }
}
```

---

## Common Operations

### Add Reverse Proxy Route (via Caddyfile)

**Edit Caddyfile:**
```bash
cat >> /etc/caddy/Caddyfile << 'EOF'

newservice.harbor.fyi {
    reverse_proxy 100.108.72.99:3000
}
EOF
```

**Reload config:**
```bash
caddy reload --config /etc/caddy/Caddyfile
```

### Add Route via API (Dynamic)

```bash
DOMAIN="newservice.harbor.fyi"
BACKEND_IP="100.108.72.99"
BACKEND_PORT=3000

curl -X POST http://localhost:2019/config/apps/http/servers/srv0/routes \
  -H "Content-Type: application/json" \
  -d "{
    \"match\": [{\"host\": [\"$DOMAIN\"]}],
    \"handle\": [{
      \"handler\": \"reverse_proxy\",
      \"upstreams\": [{\"dial\": \"$BACKEND_IP:$BACKEND_PORT\"}]
    }]
  }"
```

### List Current Routes

```bash
curl -s http://localhost:2019/config/apps/http/servers/srv0/routes | jq .
```

### Remove Route via API

```bash
ROUTE_INDEX=0  # Index of route to remove
curl -X DELETE http://localhost:2019/config/apps/http/servers/srv0/routes/$ROUTE_INDEX
```

### Get Current Config

```bash
curl -s http://localhost:2019/config/ | jq .
```

### Validate Caddyfile

```bash
caddy validate --config /etc/caddy/Caddyfile
```

---

## Automatic HTTPS

Caddy automatically obtains and renews SSL certificates from Let's Encrypt.

### How It Works
1. Add domain to Caddyfile: `example.com { ... }`
2. Caddy detects it needs HTTPS
3. Automatic ACME challenge (HTTP-01 or TLS-ALPN-01)
4. Certificate obtained and installed
5. Auto-renewal 30 days before expiry

**No configuration needed!**

### Disable HTTPS (for testing)

```caddyfile
http://example.com {
    reverse_proxy localhost:3000
}
```

### Custom SSL Certificate

```caddyfile
example.com {
    tls /path/to/cert.pem /path/to/key.pem
    reverse_proxy localhost:3000
}
```

---

## Integration with Tailscale

Caddy works seamlessly with Tailscale backends:

```caddyfile
service.harbor.fyi {
    reverse_proxy 100.108.72.90:3000 {
        # Health check
        health_uri /health
        health_interval 10s
        health_timeout 5s
    }
}
```

### Dynamic Backend Discovery

Use Caddy API to update backends when Tailscale IPs change:

```bash
NEW_IP=$(tailscale status --json | jq -r '.Peer[] | select(.HostName == "docker-vm") | .TailscaleIPs[0]')

curl -X PATCH http://localhost:2019/config/apps/http/servers/srv0/routes/0/handle/0/upstreams/0 \
  -H "Content-Type: application/json" \
  -d "{\"dial\": \"$NEW_IP:3000\"}"
```

---

## Helper Scripts

All scripts located in: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`

### caddy-add-route.sh
Add new reverse proxy route via API.

**Usage:**
```bash
bash caddy-add-route.sh newservice.harbor.fyi 100.108.72.99 3000
```

### caddy-list-routes.sh
List all configured routes.

**Usage:**
```bash
bash caddy-list-routes.sh
```

**Output:**
```
Domain                     Backend              Status
cortex.harbor.fyi          100.108.72.90:3000   Active
qdrant.harbor.fyi          100.108.72.90:6333   Active
```

### caddy-reload-config.sh
Reload Caddyfile configuration.

**Usage:**
```bash
bash caddy-reload-config.sh
```

---

## Migration from NPM

### Export NPM Routes

```bash
ssh root@192.168.50.45 "sqlite3 /data/database.sqlite -json '
  SELECT domain_names, forward_host, forward_port
  FROM proxy_host
  WHERE enabled = 1;
'" > npm-routes.json
```

### Generate Caddyfile from NPM Export

```bash
jq -r '.[] |
  (.domain_names | fromjson | .[0]) + " {\n" +
  "    reverse_proxy " + .forward_host + ":" + (.forward_port | tostring) + "\n" +
  "}\n"
' npm-routes.json > Caddyfile
```

### Test Before Switching

1. Deploy Caddy on different port (e.g., 8080)
2. Test routes: `curl -H "Host: service.harbor.fyi" http://localhost:8080`
3. Verify SSL works
4. Switch DNS/firewall to Caddy

---

## Troubleshooting

### Issue: Certificate Obtaining Failed
**Symptoms**: `acme: error: 403` in logs
**Cause**: DNS not pointing to Caddy server, or port 80/443 blocked
**Solution**:
1. Verify DNS: `dig example.com` points to Caddy server
2. Check firewall: `iptables -L | grep 80\|443`
3. Test ACME challenge: `curl http://example.com/.well-known/acme-challenge/test`

### Issue: Reverse Proxy Not Working
**Symptoms**: 502 Bad Gateway
**Cause**: Backend service not reachable
**Solution**:
1. Check backend is running: `curl http://100.108.72.90:3000`
2. Check Tailscale connectivity: `ping 100.108.72.90`
3. Check Caddy logs: `journalctl -u caddy -f`

### Issue: Config Not Reloading
**Symptoms**: Changes to Caddyfile not applied
**Cause**: Syntax error in Caddyfile
**Solution**:
1. Validate config: `caddy validate --config /etc/caddy/Caddyfile`
2. Check logs: `journalctl -u caddy -n 50`
3. Force reload: `systemctl reload caddy`

### Issue: API Not Accessible
**Symptoms**: `curl http://localhost:2019` connection refused
**Cause**: Admin API not enabled
**Solution**: Add to Caddyfile:
```caddyfile
{
    admin 0.0.0.0:2019
}
```

---

## Caddy vs NPM Comparison

| Aspect | NPM | Caddy |
|--------|-----|-------|
| **Setup Complexity** | Medium (Docker + DB) | Low (single binary) |
| **HTTPS** | Manual certificate setup | Automatic |
| **Configuration** | Web UI + SQLite | Caddyfile or API |
| **Dynamic Updates** | Database edits + restart | API calls (no restart) |
| **Monitoring** | Web UI | API + logs |
| **Best Use Case** | Multi-user, production | Single admin, dev/API-driven |
| **Learning Curve** | Low (UI-driven) | Medium (config file) |

---

## When to Use Caddy

**Use Caddy when:**
- API-driven configuration preferred
- Automatic HTTPS without UI clicks
- Simpler setup for dev environments
- Integration with CI/CD pipelines
- Need dynamic route updates without restart

**Use NPM when:**
- Multiple admins need web UI
- Access control lists required
- Database-backed configuration preferred
- Already invested in NPM workflows

---

## Related Documentation

- Caddy Docs: https://caddyserver.com/docs/
- Caddyfile Syntax: https://caddyserver.com/docs/caddyfile
- API Reference: https://caddyserver.com/docs/api
- NPM Proxy Manager Skill: `../npm-proxy-manager/skill.md`
- Tailscale Network Manager Skill: `../tailscale-network-manager/skill.md`
- Infrastructure Ops Scripts: `/Users/adamkovacs/Documents/codebuild/infrastructure-ops/scripts/networking/`
