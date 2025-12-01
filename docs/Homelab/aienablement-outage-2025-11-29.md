# aienablement.academy outage – 2025-11-29

## What happened
- Cloudflare returned 523 for `ops/wiki/forms/cortex` because the origin at `163.192.41.116` had nothing listening on ports 80/443.
- The web apps (NocoDB, Docmost, Formbricks, Cortex app) were running in Docker, but the reverse proxy that should expose them was absent. Only a local Mailpit listener on 127.0.0.1:8025 was present.
- DNS was already pointed at `163.192.41.116` and Cloudflare proxy was enabled; the failure was purely lack of an origin listener.

## Fix applied
- Deployed a lightweight reverse proxy (`edge-proxy`, Caddy) on the host and attached it to the existing `reverse-proxy` Docker network with upstreams:
  - `cortex.aienablement.academy` → `cortex-automation:3000`
  - `ops.aienablement.academy` → `nocodb-nocodb-app-1:8080`
  - `wiki.aienablement.academy` → `docmost-docmost-app-1:3000`
  - `forms.aienablement.academy` → `formbricks-formbricks-app-1:3000`
- Caddyfile location: `/home/ubuntu/reverse-proxy/Caddyfile`
- Container: `edge-proxy` (image `caddy:2`), bound to `0.0.0.0:80,443`
- Obtained fresh Let’s Encrypt certs for all four hosts.
- Temporarily flipped DNS to DNS-only for validation, then re-enabled Cloudflare proxy on the same A records (still pointing to `163.192.41.116`).

## Current state
- `ops/wiki/forms` respond over HTTPS through Cloudflare → Caddy → backend containers.
- `cortex` responds with Cloudflare Access login (expected).
- Host now has listeners on 80/443 via the `edge-proxy` container.

## Recommended hardening
1) Persist the proxy in compose: add a small `docker-compose.yml` in `/home/ubuntu/reverse-proxy` with the Caddy service, data volume for certs, and explicit `reverse-proxy` network. Include `email` in the Caddy global block for ACME registration.
2) Health checks: add an uptime check hitting `https://ops.aienablement.academy/health` (or similar) to catch missing listeners early.
3) Config backup: check in the Caddyfile (sans secrets) to repo or infra-as-code so the proxy can be recreated automatically on reboot/redeploy.
4) Optional: add additional routes (n8n, monitoring, etc.) to the Caddyfile so everything fronted by Cloudflare has an upstream defined.

## Quick commands (reference)
- View proxy config: `cat /home/ubuntu/reverse-proxy/Caddyfile`
- Restart proxy: `docker restart edge-proxy`
- Check listeners: `sudo ss -tlnp | egrep '(:80|:443)'`
- DNS records (Cloudflare zone `aienablement.academy`): A records for cortex/ops/wiki/forms → `163.192.41.116`, proxied=true.
