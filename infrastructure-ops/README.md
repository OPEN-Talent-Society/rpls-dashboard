# Infrastructure Operations

This directory contains all infrastructure documentation, monitoring setup, and operational procedures.

## Contents

- `infrastructure-discovery-report.md` - Complete infrastructure inventory
- `monitoring/` - Monitoring configurations and dashboards
- `dns/` - DNS records and Cloudflare configurations
- `homelab/` - Homelab (Proxmox) documentation
- `oci/` - OCI server documentation
- `alerts/` - Alert configurations and runbooks

## Quick Links

- Uptime Kuma: https://status.aienablement.academy
- Uptime Kuma Admin: https://uptime.aienablement.academy
- Netdata Metrics: https://metrics.aienablement.academy
- Nginx Proxy Manager: https://nginx.harbor.fyi
- Portainer: https://portainer.harbor.fyi

## Infrastructure Summary

### OCI Server (163.192.41.116)
- Production services: Docmost, NocoDB, Cortex, Formbricks, Cal.com, OpenSign
- Reverse Proxy: Caddy (edge-proxy)
- Monitoring: Uptime Kuma, Dozzle, Netdata

### Homelab (192.168.50.x)
- Proxmox host: 100.103.83.62 (Tailscale)
- Docker VM: 192.168.50.149 (VM 101) / docker-host: 100.114.104.8 (Tailscale)
- Nginx Proxy Manager: 192.168.50.45 (LXC 106)
- QNAP NAS: 192.168.50.251
- GitHub Runners: 3 org runners (AI-Enablement-Academy, OPEN-Talent-Society, The-Talent-Foundation)
- Services: n8n, Qdrant, Jellyfin, Supabase, LibreChat, and more

### Domains
- **aienablement.academy** - Cloudflare DNS, production services
- **harbor.fyi** - Porkbun DNS, homelab services
