---
name: netdata-operations
description: Netdata monitoring specialist for system metrics collection, performance analysis, and infrastructure observability
model: opus
color: yellow
id: netdata-operations
summary: Procedures for deploying and tuning the Netdata monitoring stack for host and container insights.
status: active
owner: ops
last_reviewed_at: 2025-12-12
domains:
  - observability
  - infrastructure
tooling:
  - netdata
  - docker
  - cloudflare
auto-triggers:
  - netdata
  - system metrics
  - cpu usage
  - memory usage
  - disk usage
  - performance monitoring
  - server health
---

# Netdata Operations Guide

## Overview

- Netdata is optional monitoring for deep host metrics; enable via compose profile `metrics`.
- Access URL: `metrics.aienablement.academy`​ (Cloudflare Access + portal login). Authenticate with an `@aienablement.academy`​ email OTP, then use the HTML portal (`opsadmin`​ / `Ops!Dash2025`​). Service token credentials for automation live in `/srv/monitoring/.env` (0600).
- Container runs privileged with host mounts; use sparingly to limit resource impact.

## Enabling

1. Export profile:

    ```
    cd /srv/monitoring
    sudo docker compose --profile metrics up -d netdata
    ```
2. Verify health: visit `https://metrics.aienablement.academy`​, or locally `curl -sf http://127.0.0.1:19999/api/v1/info`.
3. Configure reverse proxy (Caddy) and Cloudflare Access before exposing. When scripting against the portal or Netdata API, present the service token via `CF-Access-Client-Id`​ / `CF-Access-Client-Secret`​ headers (values from `/srv/monitoring/.env`).

## Configuration

- Compose mounts (per Netdata docs):

  ```
  - netdatalib:/var/lib/netdata
  - netdatacache:/var/cache/netdata
  - /var/run/docker.sock:/var/run/docker.sock:ro
  - /sys:/host/sys:ro
  - /proc:/host/proc:ro
  - /etc/os-release:/host/etc/os-release:ro
  - /etc/hostname:/host/etc/hostname:ro
  ```
- For HTTPS upstreams (collectors), add `tls_skip_verify: yes` when using self-signed certs.
- Reverse proxy example (Nginx) per docs:

  ```nginx
  upstream netdata_backend { server 127.0.0.1:19999; keepalive 1024; }
  ```

## Operations

- Dashboards: use Netdata Cloud optional; otherwise view local charts.
- Alerts: configure health.d rules under `/etc/netdata/health.d/`. Persist custom configs via bind mounts.
- Integrations: send metrics to Prometheus or other collectors using `stream.conf` or exporting connectors.
- Resource control: limit data retention by tuning `memory mode`​ and `history`.

## Security

- Always place behind Access control; Netdata exposes sensitive host data.
- Disable unused collectors to reduce attack surface.
- Regularly update image; apply security patches.

## Troubleshooting

- High CPU: disable noisy collectors, reduce data collection frequency.
- Missing charts: ensure required directories are mounted read-only as above.
- TLS scrape errors: configure `tls_skip_verify` for self-signed endpoints or install CA certs.

## References

- Official Docker guidance – https://github.com/netdata/netdata/blob/master/packaging/docker/README.md
- Reverse proxy configuration – https://github.com/netdata/netdata/blob/master/docs/netdata-agent/configuration/running-the-netdata-agent-behind-a-reverse-proxy/Running-behind-nginx.md
