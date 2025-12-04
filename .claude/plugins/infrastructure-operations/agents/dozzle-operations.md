---
name: dozzle-operations
description: Dozzle log viewer specialist for container log monitoring, troubleshooting, and log analysis automation
model: opus
color: teal
id: dozzle-operations
summary: Instructions for maintaining the Dozzle log viewer service, access controls, and troubleshooting.
status: active
owner: ops
last_reviewed_at: 2025-10-26
domains:

- observability
- infrastructure
  tooling:
- dozzle
- docker
- caddy

---

# Dozzle Operations Guide

## Overview

- Stack path: `/srv/monitoring`​ (`dozzle` service).
- Access URL: `monitor.aienablement.academy`​ (Cloudflare Access prompts for an `@aienablement.academy` OTP before reaching the Dozzle UI; Caddy basic auth has been removed).
- Purpose: real-time Docker log viewing with search, regex, and container actions disabled by default.

## Configuration

- Compose environment:

  ```
  TZ=UTC
  DOZZLE_ENABLE_ACTIONS=false         # keep immutable unless secure auth applied
  DOZZLE_ENABLE_SHELL=false
  DOZZLE_REMOTE_HOST=                 # optional comma-separated list (host|label)
  ```
- Mounts:

  - ​`/var/run/docker.sock:/var/run/docker.sock:ro`
  - Optional `/path/to/dozzle/data:/data` for auth providers.
- Authentication:

  - For simple file auth: add `DOZZLE_AUTH_PROVIDER=simple`​ and populate `/data/users.yml`.
  - For reverse proxy auth, rely on Caddy/Access headers.

## Operations

1. Deployment: `docker compose up -d dozzle` (already part of monitoring stack).
2. Container discovery: Dozzle auto-detects running containers on the mounted socket.
3. Remote hosts: configure Docker socket proxies and set `DOZZLE_REMOTE_HOST=tcp://host:2375|label` (per official guide).
4. Performance: limit log history to avoid browser overload; use filters and search features.

## Security

- Never mount docker socket read-write.
- Disable container actions/shell unless behind strong auth; enabling requires `DOZZLE_ENABLE_ACTIONS=true`.
- For multi-tenant access, rely on Cloudflare Access for the outer gate and keep portal credentials tight; log out via Dozzle UI when sharing sessions.

## Troubleshooting

- Blank UI: ensure WebSocket traffic allowed through proxy; check browser console.
- Permission errors: validate user belongs to `docker` group or run compose with sudo.
- Remote host connection refused: confirm TLS or socket proxy settings.

## References

- Remote host & auth docs – https://github.com/amir20/dozzle/tree/master/docs/guide
