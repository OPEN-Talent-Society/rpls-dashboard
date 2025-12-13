---
name: docker-operations
description: Docker containerization specialist for container lifecycle management, orchestration, security, and performance optimization
model: opus
color: cyan
id: docker-operations
summary: Standard operating procedures for building, publishing, and maintaining Docker-based services.
status: active
owner: ops
last_reviewed_at: 2025-12-12
domains:
  - containers
  - infrastructure
tooling:
  - docker
  - compose
  - registries
auto-triggers:
  - docker container
  - docker compose
  - container restart
  - docker logs
  - container health
  - docker build
  - docker deploy
  - container troubleshoot
---

# Docker Operations Runbook

## Scope

- Manage Docker Engine and Compose deployments on the OCI host (`docker-host`) and future nodes.
- Ensure containers follow security, resource, and lifecycle guidelines, complementing `.docs/agents/docker-host-operations.md`.

## Host Configuration

- Keep `docker-ce`​ packages current (`sudo apt update && sudo apt install docker-ce docker-compose-plugin`).
- Enforce rootless usage for app stacks where possible; otherwise restrict group membership to `docker`.
- Configure log rotation (`/etc/docker/daemon.json`):

  ```json
  { "log-driver": "json-file", "log-opts": { "max-size": "10m", "max-file": "3" } }
  ```
- Maintain `/var/lib/docker` on fast storage; alert when utilization > 70 %.

## Compose Standards

- Run each stack from `/srv/<service>`​ with `.env`​, `docker-compose.yml`, and README.
- Pin images by major.minor tags; avoid `latest` except during initial bootstrap.
- Include `healthcheck`​ entries and join shared networks (e.g., `reverse-proxy`) as needed.
- Label services with `com.docker.compose.project`​ and custom tags (`traefik.enable`​, `caddy`) for routing/observability.

## Lifecycle Tasks

1. Deploy: `docker compose pull && docker compose up -d --remove-orphans`.
2. Audit: weekly `docker image prune --filter "until=168h"`​ and `docker volume prune` (after verifying backups).
3. Backup: snapshot named volumes via `docker run --rm -v volume:/data busybox tar`.
4. Troubleshoot: inspect logs via Dozzle or `docker compose logs -f --tail=200`.

## Security

- Enable Docker context TLS when exposing remote APIs (per Uptime Kuma guide `daemon.json` hosts entry).
- Review `docker scout quickview` for image vulnerabilities.
- Use secrets (`docker secret`, env files with 600 perms) rather than inline values.

## References

- Docker Official Docs – https://docs.docker.com/engine/
- Uptime Kuma Docker monitoring guidance – https://github.com/louislam/uptime-kuma-wiki/blob/master/How-to-Monitor-Docker-Containers.md
