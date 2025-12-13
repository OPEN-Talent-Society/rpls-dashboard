---
name: n8n-security-hardening
description: Secure N8N access, remove public exposure, implement authentication, and harden infrastructure
---

# N8N Security Hardening Skill

This skill addresses N8N security issues including removing public port exposure, implementing proper authentication, adding reverse proxy, and following security best practices.

## When to Use This Skill

Use this skill when you need to:
- Remove N8N from public internet exposure
- Implement authentication and access control
- Add reverse proxy with SSL termination
- Harden N8N configuration
- Implement webhook security
- Set up VPN or tunnel access
- Audit N8N security configuration

## Current Security Issues

### Critical Issues
- **Port 5678 forwarded to internet** - N8N exposed publicly
- No authentication required for access
- Direct HTTP access (no SSL)
- No rate limiting
- No access logging
- Webhook endpoints unprotected

### Impact
- Unauthorized workflow access
- Potential data exposure
- Workflow manipulation risk
- Infrastructure access via workflows
- Credential exposure risk

## Security Hardening Checklist

### 1. Remove Public Exposure
- [ ] Remove port 5678 from router port forwarding
- [ ] Close firewall rule for port 5678
- [ ] Verify external access blocked
- [ ] Update DNS if needed

### 2. Implement Reverse Proxy
- [ ] Configure Nginx Proxy Manager
- [ ] Add SSL certificate (Cloudflare/Let's Encrypt)
- [ ] Set up internal-only access
- [ ] Enable access logging
- [ ] Implement rate limiting

### 3. Enable Authentication
- [ ] Configure N8N basic auth
- [ ] Set strong credentials
- [ ] Enable session management
- [ ] Configure timeout settings
- [ ] Implement IP whitelist

### 4. Webhook Security
- [ ] Enable webhook authentication
- [ ] Use secret tokens
- [ ] Implement signature validation
- [ ] Rate limit webhook endpoints
- [ ] Log all webhook calls

### 5. VPN/Tunnel Access
- [ ] Set up Tailscale/WireGuard access
- [ ] Configure split tunneling
- [ ] Document access procedures
- [ ] Test remote access
- [ ] Disable public access completely

## Available Scripts

Located in: `infrastructure-ops/scripts/n8n/`

- `n8n-security-fix.sh` - Complete security hardening
- `n8n-remove-port-forward.sh` - Remove router port forwarding
- `n8n-setup-proxy.sh` - Configure reverse proxy
- `n8n-enable-auth.sh` - Enable authentication
- `n8n-webhook-security.sh` - Secure webhook endpoints
- `n8n-audit-security.sh` - Security configuration audit

## Security Configuration

### N8N Environment Variables
```bash
# Basic Auth
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=<strong-password>

# Webhook Security
N8N_WEBHOOK_AUTHENTICATION=true
N8N_WEBHOOK_ALLOWED_ORIGINS=https://harbor.fyi

# Security
N8N_SECURE_COOKIE=true
N8N_SESSION_TIMEOUT=24

# Logging
N8N_LOG_LEVEL=info
N8N_LOG_OUTPUT=file

# Network
N8N_HOST=0.0.0.0
N8N_PORT=5678
N8N_PROTOCOL=https
N8N_EXTERNAL_URL=https://n8n.harbor.fyi
```

### Nginx Proxy Manager Configuration
```nginx
location / {
    proxy_pass http://192.168.50.149:5678;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Rate limiting
    limit_req zone=n8n burst=5 nodelay;
}
```

## Access Methods After Hardening

### Internal Access
- **VPN**: Tailscale/WireGuard to homelab network
- **Local**: Direct access from 192.168.50.0/24 network
- **SSH Tunnel**: `ssh -L 5678:192.168.50.149:5678 user@gateway`

### External Access (Secure)
- **Cloudflare Tunnel**: Zero Trust access
- **VPN Only**: No public exposure
- **Proxy with Auth**: Strong authentication required

## Audit Procedures

### Regular Security Checks
- Verify no public port exposure
- Check authentication is active
- Review access logs
- Audit workflow credentials
- Verify SSL certificates
- Check for updates

### Monitoring
- Failed authentication attempts
- Unusual webhook activity
- Workflow execution patterns
- Credential access logs
- API usage patterns

## Usage Examples

- "Remove N8N public exposure and set up reverse proxy"
- "Audit N8N security configuration"
- "Enable webhook authentication"
- "Set up Cloudflare Tunnel for N8N"
- "Verify N8N is not publicly accessible"

## Emergency Procedures

### If Breach Suspected
1. Immediately block all external access
2. Rotate all credentials in N8N
3. Audit workflow execution logs
4. Check for unauthorized workflows
5. Review all integrations
6. Restore from clean backup if needed

### Recovery Steps
1. Secure the instance
2. Change all credentials
3. Re-deploy workflows from git
4. Verify integrations
5. Document incident
6. Implement additional controls
