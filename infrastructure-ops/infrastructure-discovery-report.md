# Infrastructure Discovery Report

**Generated:** 2025-12-05
**Scope:** Complete infrastructure scan across OCI, Proxmox, and all nested services

---

## Executive Summary

**Total Infrastructure:**

- **1 OCI Server** (163.192.41.116) - 28 containers, 83% disk usage
- **1 Proxmox Host** (100.103.83.62) - 4 LXC containers, 4 VMs
- **Docker VM** (192.168.50.149) - 34 containers
- **Total Services:** 66+ unique services across all locations

**Critical Findings:**

- ⚠️ OCI Server at 83% disk capacity (38GB/45GB used)
- ⚠️ Cal.com container unhealthy on OCI
- ⚠️ Supabase-auth restarting loop on Docker VM
- ⚠️ Supabase-realtime unhealthy on Docker VM
- ✅ 63 healthy services running normally

---

## 1. Complete Service Inventory

### 1.1 OCI Server (163.192.41.116)

#### System Resources

- **IP:** 163.192.41.116 (public), 100.114.104.8 (Tailscale)
- **Memory:** 23GB total, 18GB available, 4.2GB used
- **Disk:** 45GB total, 38GB used (83%), 7.9GB free ⚠️
- **OS:** Ubuntu 22.04 LTS (ARM64)

#### Docker Containers (28)

| Service Name                            | Image                        | Status               | Ports      | Domain                                                   |
| --------------------------------------- | ---------------------------- | -------------------- | ---------- | -------------------------------------------------------- |
| **edge-proxy**                          | caddy:2                      | ✅ Up 22m            | 80, 443    | All \*.aienablement.academy                              |
| **cortex-siyuan**                       | b3log/siyuan:v3.3.6          | ✅ Up 5d             | 6806       | cortex.aienablement.academy                              |
| **docmost-docmost-app-1**               | docmost/docmost:latest       | ✅ Up 5d             | 3000       | wiki.aienablement.academy                                |
| **docmost-docmost-db-1**                | postgres:16-alpine           | ✅ Up 5d             | 5432       | -                                                        |
| **docmost-docmost-redis-1**             | redis:7.2-alpine             | ✅ Up 5d             | 6379       | -                                                        |
| **docmost-mailpit-1**                   | axllent/mailpit:latest       | ✅ Up 5d             | 1025, 8025 | -                                                        |
| **docmost-exporter-docmost-exporter-1** | docmost-exporter:latest      | ✅ Up 5d             | -          | -                                                        |
| **formbricks-formbricks-app-1**         | formbricks:4.0.1             | ✅ Up 5d             | 3000       | forms.aienablement.academy                               |
| **formbricks-formbricks-db-1**          | pgvector/pgvector:pg17       | ✅ Up 5d             | 5432       | -                                                        |
| **formbricks-formbricks-redis-1**       | valkey/valkey:7.2-alpine     | ✅ Up 5d             | 6379       | -                                                        |
| **nocodb-nocodb-app-1**                 | nocodb/nocodb:latest         | ✅ Up 5d             | 8080       | ops.aienablement.academy                                 |
| **nocodb-nocodb-db-1**                  | postgres:16-alpine           | ✅ Up 5d             | 5432       | -                                                        |
| **n8n-n8n-app-1**                       | n8nio/n8n:latest             | ✅ Up 5d             | 5678       | (no public domain)                                       |
| **n8n-n8n-db-1**                        | postgres:16-alpine           | ✅ Up 5d             | 5432       | -                                                        |
| **calcom-app**                          | calcom/cal.com:latest        | ⚠️ Up 2d (unhealthy) | 3000       | calendar.aienablement.academy                            |
| **calcom-db**                           | postgres:15-alpine           | ✅ Up 3d             | 5432       | -                                                        |
| **calcom-redis**                        | redis:7-alpine               | ✅ Up 3d             | 6379       | -                                                        |
| **opensign-app**                        | opensign/opensign:main       | ✅ Up 2d             | 3000       | sign.aienablement.academy                                |
| **opensign-server**                     | opensign/opensignserver:main | ✅ Up 2d             | 8080       | sign.aienablement.academy/api/\*                         |
| **opensign-mongo**                      | mongo:latest                 | ✅ Up 2d             | 27017      | -                                                        |
| **synapse-api**                         | synapse_synapse              | ✅ Up 5d             | 3000       | 0.0.0.0:3000 (exposed)                                   |
| **synapse-postgres**                    | postgres:15-alpine           | ✅ Up 5d             | 5432       | -                                                        |
| **monitoring-uptime-kuma-1**            | louislam/uptime-kuma:2       | ✅ Up 5d             | 3001       | status.aienablement.academy, uptime.aienablement.academy |
| **monitoring-dozzle-1**                 | amir20/dozzle:latest         | ✅ Up 5d             | 8080       | monitor.aienablement.academy                             |
| **monitoring-netdata-1**                | netdata/netdata:stable       | ✅ Up 5d             | 19999      | metrics.aienablement.academy                             |
| **monitoring-metrics-portal-1**         | monitoring-metrics-portal    | ✅ Up 5d             | 8080       | -                                                        |
| **metamcp-pg**                          | postgres:16-alpine           | ✅ Up 5d             | 9433       | 0.0.0.0:9433 (exposed)                                   |
| **oci-fallback-mcp-gateway-1**          | oci-fallback-mcp-gateway     | ✅ Up 5d             | 8787       | 0.0.0.0:8787 (exposed)                                   |

#### Docker Networks

| Network                            | Purpose              | Connected Containers                            |
| ---------------------------------- | -------------------- | ----------------------------------------------- |
| **reverse-proxy**                  | Main proxy network   | edge-proxy, all app containers (13 containers)  |
| **docmost_docmost-internal**       | Docmost isolation    | docmost-app, docmost-db, docmost-redis          |
| **nocodb_nocodb-internal**         | NocoDB isolation     | nocodb-app, nocodb-db                           |
| **n8n_n8n-internal**               | n8n isolation        | n8n-app, n8n-db                                 |
| **calcom_calcom-internal**         | Cal.com isolation    | calcom-app, calcom-db, calcom-redis             |
| **opensign_opensign-internal**     | OpenSign isolation   | opensign-app, opensign-server, opensign-mongo   |
| **formbricks_formbricks-internal** | Formbricks isolation | formbricks-app, formbricks-db, formbricks-redis |
| **monitoring_monitoring-internal** | Monitoring stack     | uptime-kuma, dozzle, netdata, metrics-portal    |

#### Listening Ports (Host)

- **80, 443** - Caddy edge-proxy (all public traffic)
- **3000** - Synapse API (publicly exposed)
- **8787** - MCP Gateway (publicly exposed)
- **9433** - MetaMCP Postgres (publicly exposed)
- **22** - SSH

---

### 1.2 Proxmox Host (100.103.83.62)

#### System Resources

- **IP:** 100.103.83.62 (Tailscale)
- **Disk:** 98GB root (31% used), 1TB NVMe storage
- **CPU:** Multi-core server
- **Memory:** 64GB+ (hosting multiple VMs)

#### LXC Containers (4)

| VMID    | Name              | Status     | IP             | Services                                         | Purpose                      |
| ------- | ----------------- | ---------- | -------------- | ------------------------------------------------ | ---------------------------- |
| **103** | jellyfin          | ✅ Running | 192.168.50.153 | Jellyfin (port 8096)                             | Media server                 |
| **104** | qbittorrent       | ✅ Running | 192.168.50.232 | qBittorrent (port 8090, 17512)                   | Torrent client               |
| **105** | plex              | ❌ Stopped | -              | Plex Media Server                                | Media server (backup)        |
| **106** | nginxproxymanager | ✅ Running | 100.85.205.49  | NPM, OpenResty, dnsmasq                          | Reverse proxy for harbor.fyi |
| **120** | whisper-stack     | ✅ Running | 192.168.50.x   | Ollama, Postgres, Redis, Nginx (port 8080, 9000) | AI transcription service     |

#### Virtual Machines (4)

| VMID    | Name               | Status     | IP             | Memory | Disk  | Purpose                             |
| ------- | ------------------ | ---------- | -------------- | ------ | ----- | ----------------------------------- |
| **100** | Windows-OS         | ✅ Running | 192.168.50.x   | 16GB   | 100GB | Windows workstation                 |
| **101** | Docker-Debian      | ✅ Running | 192.168.50.149 | 55GB   | 132GB | Primary Docker host (34 containers) |
| **102** | haos               | ✅ Running | 192.168.50.x   | 6GB    | 32GB  | Home Assistant OS                   |
| **200** | Lubuntu-Automation | ✅ Running | 192.168.50.x   | 24GB   | 32GB  | Automation workstation              |

---

### 1.3 Docker VM (VMID 101 - 192.168.50.149)

#### System Resources

- **Memory:** 55GB allocated
- **Disk:** 132GB allocated
- **OS:** Debian

#### Docker Containers (34)

| Service Name                         | Image                      | Status               | Ports           | Purpose                           |
| ------------------------------------ | -------------------------- | -------------------- | --------------- | --------------------------------- |
| **qdrant_service**                   | qdrant/qdrant              | ✅ Up 45h            | 6333-6334       | Vector database                   |
| **whisper-jobs-redis-1**             | redis:7-alpine             | ✅ Up 3w             | 16379           | Whisper job queue                 |
| **whisper-jobs-postgres-1**          | postgres:16-alpine         | ✅ Up 3w             | 15432           | Whisper database                  |
| **ddns-updater**                     | qmcgaw/ddns-updater        | ✅ Up 45h            | 8001            | Dynamic DNS                       |
| **N8n**                              | n8nio/n8n:latest           | ✅ Up 5w             | 5678            | Workflow automation               |
| **OpenWebUI**                        | open-webui:main            | ✅ Up 5w             | 8080 (internal) | AI chat interface                 |
| **tmdb-mcp-service**                 | mcp-services-tmdb-mcp      | ✅ Up 5w             | 8080 (internal) | TMDB MCP server                   |
| **portainer**                        | portainer-ce:latest        | ✅ Up 5w             | 8000, 9443      | Docker management                 |
| **Calibre**                          | linuxserver/calibre        | ✅ Up 5w             | 3000-3001       | E-book management                 |
| **supabase-db**                      | supabase/postgres-pgvector | ✅ Up 5w             | 5432            | Supabase database                 |
| **supabase-auth**                    | supabase/gotrue:v2.171.0   | ⚠️ Restarting        | -               | Supabase authentication (failing) |
| **supabase-storage**                 | supabase/storage-api       | ✅ Up 5w             | 5000            | Supabase storage                  |
| **supabase-pooler**                  | supabase/supavisor         | ✅ Up 5w             | 5432, 6543      | Connection pooler                 |
| **supabase-kong**                    | kong:2.8.1                 | ✅ Up 5w             | 8002, 8443      | API gateway                       |
| **supabase-rest**                    | postgrest                  | ✅ Up 5w             | 3000            | REST API                          |
| **realtime-dev.supabase-realtime**   | supabase/realtime          | ⚠️ Up 5w (unhealthy) | -               | Realtime subscriptions            |
| **supabase-studio**                  | supabase/studio            | ✅ Up 5w             | 3000            | Management UI                     |
| **supabase-edge-functions**          | supabase/edge-runtime      | ✅ Up 5w             | -               | Edge functions                    |
| **supabase-meta**                    | supabase/postgres-meta     | ✅ Up 5w             | 8080            | Database metadata                 |
| **supabase-analytics**               | supabase/logflare          | ✅ Up 5w             | 4000            | Analytics                         |
| **supabase-vector**                  | timberio/vector            | ✅ Up 5w             | -               | Log aggregation                   |
| **supabase-imgproxy**                | darthsim/imgproxy          | ✅ Up 5w             | 8080            | Image optimization                |
| **LibreChat**                        | librechat/librechat        | ✅ Up 5w             | 3080            | AI chat interface                 |
| **vectordb**                         | ankane/pgvector            | ✅ Up 5w             | 5432            | Vector database                   |
| **chat-mongodb**                     | mongo                      | ✅ Up 5w             | 27017           | Chat database                     |
| **chat-meilisearch**                 | getmeili/meilisearch       | ✅ Up 5w             | 7700            | Search engine                     |
| **vaultwarden**                      | vaultwarden/server         | ✅ Up 5w             | 8180            | Password manager                  |
| **linkwarden**                       | linkwarden:latest          | ✅ Up 5w             | 3000            | Bookmark manager                  |
| **linkwarden-db**                    | postgres:16-alpine         | ✅ Up 5w             | 5432            | Linkwarden database               |
| **postiz-app**                       | postiz (custom)            | ✅ Up 5w             | 5000            | Social media manager              |
| **postiz-cache**                     | redis:7.2                  | ✅ Up 5w             | 6379            | Postiz cache                      |
| **postiz-db**                        | postgres:17-alpine         | ✅ Up 5w             | 5432            | Postiz database                   |
| **buildx_buildkit_default_builder0** | moby/buildkit              | ✅ Up 5w             | -               | Docker build cache                |

#### Docker Networks

- **mcp-bridge** - MCP services
- **librechat_default** - LibreChat stack
- **supabase_default** - Supabase stack (12 containers)
- **postiz_postiz-network** - Postiz stack
- **root_linkwarden-network** - Linkwarden stack
- **whisper-jobs_default** - Whisper jobs

---

### 1.4 LXC 106 - Nginx Proxy Manager (100.85.205.49)

#### Services

- **OpenResty/Nginx** - Reverse proxy (ports 80, 443, 81)
- **NPM Backend** - Management API
- **dnsmasq** - Local DNS (port 53)
- **Tailscale** - VPN (port 40048)

#### Listening Ports

- **80, 443** - HTTP/HTTPS proxy
- **81** - NPM admin UI
- **53** - DNS server

---

### 1.5 LXC 120 - Whisper Stack (192.168.50.x)

#### Services

- **Ollama** - LLM runtime (port 11434)
- **PostgreSQL 16** - Database (port 5432)
- **Redis** - Cache (port 6379)
- **Nginx** - Reverse proxy (port 8080)
- **uvicorn** - Python API (port 9000)

---

## 2. Network Topology Map

```
Internet
  │
  ├─► 163.192.41.116 (OCI) ──┬─► Caddy (edge-proxy) ──┬─► *.aienablement.academy
  │                           │                        ├─► cortex.aienablement.academy → cortex-siyuan:6806
  │                           │                        ├─► wiki.aienablement.academy → docmost-docmost-app-1:3000
  │                           │                        ├─► ops.aienablement.academy → nocodb-nocodb-app-1:8080
  │                           │                        ├─► forms.aienablement.academy → formbricks-formbricks-app-1:3000
  │                           │                        ├─► calendar.aienablement.academy → calcom-app:3000 (⚠️ unhealthy)
  │                           │                        ├─► sign.aienablement.academy → opensign-app:3000 + opensign-server:8080
  │                           │                        ├─► status.aienablement.academy → monitoring-uptime-kuma-1:3001
  │                           │                        ├─► uptime.aienablement.academy → monitoring-uptime-kuma-1:3001
  │                           │                        ├─► monitor.aienablement.academy → monitoring-dozzle-1:8080
  │                           │                        └─► metrics.aienablement.academy → monitoring-netdata-1:19999
  │                           │
  │                           ├─► Direct Exposed Ports:
  │                           │   ├─► :3000 → synapse-api
  │                           │   ├─► :8787 → mcp-gateway
  │                           │   └─► :9433 → metamcp-pg
  │                           │
  │                           └─► Tailscale VPN (100.114.104.8)
  │
  └─► Tailscale VPN
        │
        └─► 100.103.83.62 (Proxmox) ──┬─► LXC 106 (Nginx Proxy Manager) ──┬─► *.harbor.fyi
                                       │   ├─► nginx.harbor.fyi → 192.168.50.45:81
                                       │   ├─► portainer.harbor.fyi → 100.91.53.54:9443
                                       │   ├─► n8n.harbor.fyi → 192.168.50.149:5678 OR 100.91.53.54:5678
                                       │   ├─► ddns.harbor.fyi → 192.168.50.149:8001
                                       │   ├─► postiz.harbor.fyi → 192.168.50.149:5000
                                       │   ├─► library.harbor.fyi → 192.168.50.149:8080
                                       │   ├─► plex.harbor.fyi → 192.168.50.47:32400
                                       │   ├─► nas.harbor.fyi → 192.168.50.252:443
                                       │   ├─► chat.harbor.fyi → 192.168.50.149:8181 OR 100.91.53.54:3080
                                       │   ├─► bookmarks.harbor.fyi → 100.91.53.54:3000
                                       │   ├─► bitwarden.harbor.fyi → 100.91.53.54:8180
                                       │   ├─► supabase.harbor.fyi → 192.168.50.149:8002
                                       │   ├─► mem0.harbor.fyi → 192.168.50.153:8000
                                       │   ├─► jellyfin.harbor.fyi → 192.168.50.153:8096
                                       │   └─► qdrant.harbor.fyi → 192.168.50.149:6333
                                       │
                                       ├─► LXC 103 (Jellyfin) ──► 192.168.50.153:8096
                                       ├─► LXC 104 (qBittorrent) ──► 192.168.50.232:8090
                                       ├─► LXC 120 (Whisper Stack) ──► 192.168.50.x:8080
                                       │
                                       ├─► VM 101 (Docker-Debian) ──► 192.168.50.149
                                       │   └─► 34 Docker Containers
                                       │       ├─► Supabase Stack (12 containers) :8002, :8443
                                       │       ├─► LibreChat :3080
                                       │       ├─► Qdrant :6333
                                       │       ├─► Postiz :5000
                                       │       ├─► Linkwarden :3000
                                       │       ├─► Vaultwarden :8180
                                       │       ├─► Portainer :9443
                                       │       ├─► N8n :5678
                                       │       ├─► OpenWebUI (internal)
                                       │       └─► DDNS Updater :8001
                                       │
                                       ├─► VM 102 (Home Assistant) ──► 192.168.50.x
                                       ├─► VM 100 (Windows-OS) ──► 192.168.50.x
                                       └─► VM 200 (Lubuntu-Automation) ──► 192.168.50.x

192.168.50.x Network (Homelab Internal):
  ├─► .45 - Unknown service (nginx proxy target)
  ├─► .47 - Plex server
  ├─► .149 - Docker VM (main services)
  ├─► .153 - Jellyfin LXC
  ├─► .232 - qBittorrent LXC
  └─► .252 - NAS
```

---

## 3. Domain Mapping

### 3.1 aienablement.academy (Public - OCI)

| Subdomain | Backend Service                          | Location      | Status       |
| --------- | ---------------------------------------- | ------------- | ------------ |
| cortex    | cortex-siyuan:6806                       | OCI Container | ✅           |
| wiki      | docmost-docmost-app-1:3000               | OCI Container | ✅           |
| ops       | nocodb-nocodb-app-1:8080                 | OCI Container | ✅           |
| forms     | formbricks-formbricks-app-1:3000         | OCI Container | ✅           |
| calendar  | calcom-app:3000                          | OCI Container | ⚠️ Unhealthy |
| sign      | opensign-app:3000 + opensign-server:8080 | OCI Container | ✅           |
| status    | monitoring-uptime-kuma-1:3001            | OCI Container | ✅           |
| uptime    | monitoring-uptime-kuma-1:3001            | OCI Container | ✅           |
| monitor   | monitoring-dozzle-1:8080                 | OCI Container | ✅           |
| metrics   | monitoring-netdata-1:19999               | OCI Container | ✅           |

### 3.2 harbor.fyi (Private - Homelab via NPM)

| Subdomain | Backend Service        | Location              | IP:Port             | Status                   |
| --------- | ---------------------- | --------------------- | ------------------- | ------------------------ |
| nginx     | NPM admin              | LXC 106               | 192.168.50.45:81    | ✅                       |
| portainer | Portainer UI           | Docker VM             | 100.91.53.54:9443   | ✅                       |
| n8n       | n8n Automation         | Docker VM / Tailscale | 192.168.50.149:5678 | ✅ (duplicate entries)   |
| ddns      | DDNS Updater           | Docker VM             | 192.168.50.149:8001 | ✅                       |
| postiz    | Social Media Manager   | Docker VM             | 192.168.50.149:5000 | ✅                       |
| library   | Calibre / OpenWebUI    | Docker VM             | 192.168.50.149:8080 | ✅                       |
| plex      | Plex Media Server      | Proxmox VM            | 192.168.50.47:32400 | ⚠️ Duplicate entries     |
| nas       | NAS Storage            | NAS Device            | 192.168.50.252:443  | ✅                       |
| chat      | LibreChat              | Docker VM / Tailscale | Multiple IPs        | ⚠️ Duplicate/conflicting |
| bookmarks | Linkwarden             | Docker VM             | 100.91.53.54:3000   | ✅                       |
| bitwarden | Vaultwarden            | Docker VM             | 100.91.53.54:8180   | ✅                       |
| supabase  | Supabase Kong          | Docker VM             | 192.168.50.149:8002 | ✅                       |
| mem0      | Unknown Memory Service | Unknown               | 192.168.50.153:8000 | ❓                       |
| jellyfin  | Jellyfin Media         | LXC 103               | 192.168.50.153:8096 | ✅                       |
| qdrant    | Qdrant Vector DB       | Docker VM             | 192.168.50.149:6333 | ✅                       |

---

## 4. Missing/Broken Services

### 4.1 Unhealthy Containers

| Service                            | Location                   | Issue                         | Impact                                     |
| ---------------------------------- | -------------------------- | ----------------------------- | ------------------------------------------ |
| **calcom-app**                     | OCI (163.192.41.116)       | Health check failing          | calendar.aienablement.academy may not work |
| **supabase-auth**                  | Docker VM (192.168.50.149) | Restarting loop (exit code 1) | Supabase authentication down               |
| **realtime-dev.supabase-realtime** | Docker VM (192.168.50.149) | Unhealthy status              | Supabase realtime features broken          |

### 4.2 Duplicate/Conflicting Entries

| Domain           | Issue                                                         | Recommended Action                          |
| ---------------- | ------------------------------------------------------------- | ------------------------------------------- |
| n8n.harbor.fyi   | Two proxy entries (192.168.50.149:5678 and 100.91.53.54:5678) | Remove duplicate, keep one                  |
| chat.harbor.fyi  | Two proxy entries (192.168.50.149:8181 and 100.91.53.54:3080) | Clarify if separate services or consolidate |
| plex.harbor.fyi  | Two entries with different ports (:32400 and :3240)           | Remove typo entry (:3240)                   |
| nginx.harbor.fyi | Two identical entries                                         | Remove duplicate                            |

### 4.3 Unknown/Unidentified Services

| Service         | IP:Port             | Issue                                   |
| --------------- | ------------------- | --------------------------------------- |
| mem0.harbor.fyi | 192.168.50.153:8000 | No container/service found at this port |
| 192.168.50.45   | :81                 | Unknown target for nginx.harbor.fyi     |
| 192.168.50.47   | -                   | Plex server host not scanned            |
| 192.168.50.252  | -                   | NAS not scanned                         |

### 4.4 Services Without Public Domains

These services are running but not exposed via domain names:

**OCI:**

- n8n-n8n-app-1 (port 5678) - No public domain configured
- docmost-exporter-docmost-exporter-1 - Background service
- monitoring-metrics-portal-1 - No domain configured

**Docker VM:**

- OpenWebUI (port 8080 internal) - No external access
- Calibre (ports 3000-3001) - Mapped to library.harbor.fyi but unclear
- TMDB MCP Service - Internal only

---

## 5. Monitoring Gaps

### 5.1 Currently Monitored (Uptime Kuma)

- status.aienablement.academy
- uptime.aienablement.academy

### 5.2 Services NOT Monitored

**Critical Public Services (aienablement.academy):**

- cortex.aienablement.academy
- wiki.aienablement.academy
- ops.aienablement.academy
- forms.aienablement.academy
- calendar.aienablement.academy (already broken)
- sign.aienablement.academy
- monitor.aienablement.academy
- metrics.aienablement.academy

**Harbor.fyi Services:**

- ALL 19 harbor.fyi subdomains (none monitored)
- portainer.harbor.fyi
- n8n.harbor.fyi
- supabase.harbor.fyi
- qdrant.harbor.fyi
- jellyfin.harbor.fyi
- bitwarden.harbor.fyi
- postiz.harbor.fyi

**Infrastructure Services:**

- OCI Server health (disk, memory, CPU)
- Proxmox host health
- Docker VM health
- Individual container health status
- Database backup status
- SSL certificate expiry

**Direct Exposed Ports (Security Risk):**

- 163.192.41.116:3000 (synapse-api)
- 163.192.41.116:8787 (mcp-gateway)
- 163.192.41.116:9433 (metamcp-pg)

### 5.3 Missing Monitoring Features

- SSL certificate expiration monitoring
- Disk space alerts (OCI at 83%!)
- Container restart/crash alerts
- Database size monitoring
- Backup verification
- Network connectivity between services
- DNS resolution checks

---

## 6. Recommendations

### 6.1 Immediate Actions (High Priority)

1. **Fix Disk Space on OCI (CRITICAL)**
   - Current: 83% full (38GB/45GB)
   - Action: Clean up Docker images, logs, and old volumes
   - Command: `docker system prune -a --volumes`

2. **Fix Broken Services**
   - Cal.com: Investigate health check failure
   - Supabase-auth: Check logs for restart loop cause
   - Supabase-realtime: Diagnose unhealthy status

3. **Remove Duplicate NPM Entries**
   - Clean up n8n.harbor.fyi (remove duplicate)
   - Fix plex.harbor.fyi port typo
   - Remove duplicate nginx.harbor.fyi entry
   - Clarify chat.harbor.fyi routing

4. **Secure Direct Port Exposure**
   - Move synapse-api behind reverse proxy
   - Move mcp-gateway behind reverse proxy
   - Move metamcp-pg to private network (only via Tailscale)

### 6.2 Monitoring Setup (High Priority)

1. **Add All Public Services to Uptime Kuma**
   - All 10 aienablement.academy subdomains
   - All 19 harbor.fyi subdomains
   - Set up alert notifications (email/Slack/Discord)

2. **Infrastructure Monitoring**
   - OCI disk space alert (>80% threshold)
   - Container health checks
   - SSL certificate expiry (30-day warning)
   - Database connectivity checks

3. **Create Monitoring Dashboard**
   - Overall service health view
   - Resource usage trends
   - Alert history

### 6.3 Medium Priority

1. **Document Missing Services**
   - Investigate 192.168.50.45:81 (nginx proxy target)
   - Scan 192.168.50.47 (Plex server)
   - Scan 192.168.50.252 (NAS)
   - Identify mem0.harbor.fyi backend

2. **Network Organization**
   - Document all Tailscale IPs
   - Create network diagram with IP ranges
   - Document firewall rules

3. **Backup Verification**
   - Verify backup schedule for all databases
   - Test restore procedures
   - Document backup locations

### 6.4 Low Priority (Nice to Have)

1. **Optimize Resource Usage**
   - Review unused containers
   - Consolidate services where possible
   - Optimize Docker image sizes

2. **Documentation**
   - Create service dependency map
   - Document deployment procedures
   - Create disaster recovery plan

3. **Security Audit**
   - Review exposed services
   - Update to latest container versions
   - Implement fail2ban for SSH

---

## 7. Quick Reference

### SSH Access Commands

```bash
# OCI Server
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116

# Proxmox Host
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62

# Docker VM (via Proxmox)
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62 "qm guest exec 101 -- <command>"

# LXC Containers (via Proxmox)
ssh -i ~/.ssh/id_ed25519_proxmox root@100.103.83.62 "pct exec <vmid> -- <command>"
```

### Key Management URLs

- **Proxmox Web UI:** https://100.103.83.62:8006
- **Nginx Proxy Manager:** http://100.85.205.49:81
- **Portainer:** https://portainer.harbor.fyi (100.91.53.54:9443)
- **Uptime Kuma:** https://uptime.aienablement.academy
- **Dozzle Logs:** https://monitor.aienablement.academy
- **Netdata Metrics:** https://metrics.aienablement.academy

---

## 8. Summary Statistics

| Metric                                | Count                             |
| ------------------------------------- | --------------------------------- |
| Total Servers                         | 1 OCI + 1 Proxmox                 |
| Total LXC Containers                  | 4 (3 running, 1 stopped)          |
| Total VMs                             | 4 (all running)                   |
| Total Docker Containers               | 62 (28 on OCI + 34 on Docker VM)  |
| Healthy Services                      | 59                                |
| Unhealthy/Restarting                  | 3                                 |
| Public Domains (aienablement.academy) | 10                                |
| Private Domains (harbor.fyi)          | 19                                |
| Exposed Ports (security concern)      | 3                                 |
| Monitoring Coverage                   | ~7% (2 out of 29 domains)         |
| Critical Issues                       | 4 (disk space, 3 broken services) |

---

**Report End**
