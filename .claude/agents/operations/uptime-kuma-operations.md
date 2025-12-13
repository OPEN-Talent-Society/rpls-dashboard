# uptime-kuma-operations

---

name: uptime-kuma-operations
description: When managing and interacting and working with or doing work realted to Uptime Kuma on my infra
model: opus
auto-triggers:
  - uptime kuma
  - uptime monitoring
  - status page
  - service monitoring
  - health check
  - downtime alert
  - availability monitoring
color: orange
id: uptime-kuma-operations
summary: Playbook for configuring, monitoring, and maintaining the Uptime Kuma observability stack.
status: active
owner: ops
last_reviewed_at: 2025-10-26
domains:

- observability
- infrastructure
  tooling:
- uptime-kuma
- dozzle
- brevo

---

# Uptime Kuma Operations Guide

#ops/observability #runbook #class/runbook

## Overview

- Stack path: `/srv/monitoring`​ (`uptime-kuma` service).
- Public status page: `status.aienablement.academy`.
- Admin UI: `uptime.aienablement.academy`​ (Cloudflare Access → Kuma login `opsadmin`​ / `Ops!Dash2025`).

## Configuration

```
TZ=UTC
UPTIME_KUMA_ENABLE_EMBEDDED_MARIADB=1
NODE_EXTRA_CA_CERTS=/etc/ssl/certs/custom.pem
UPTIME_KUMA_WS_ORIGIN_CHECK=strict
```

- Data volume: `./uptime-kuma-data` (nightly tar backup).
- Mount `/var/run/docker.sock` read-only for Docker monitoring.

## Monitor Setup

1. HTTP monitors: wiki, ops, dash, n8n.
2. TCP monitor: `smtp-relay.brevo.com:465`.
3. ICMP: `docker-host` ping.
4. Notifications: Brevo SMTP notifier + secondary channel (Slack/Telegram/n8n webhook).

## Operations

- Upgrade: `docker compose pull uptime-kuma && docker compose up -d`.
- Backup: export config via UI; include volume in Docmost & NocoDB Backup SOP[^1].
- Incident management: configure status page incidents and maintenance windows.

## Troubleshooting

- Service issues: `docker compose logs -f uptime-kuma`.
- Notification failures: revalidate Brevo credentials.
- WebSocket errors: adjust `UPTIME_KUMA_WS_ORIGIN_CHECK`.
- Database corruption: stop container, backup `uptime-kuma-data`​, remove `kuma.db-shm/wal`, restart.

## References

- Env vars – https://github.com/louislam/uptime-kuma-wiki/blob/master/Environment-Variables.md
- Reverse proxy – https://github.com/louislam/uptime-kuma-wiki/blob/master/Reverse-Proxy.md

[^1]: # docmost-nocodb-backup-sop

    ---

    id: docmost-nocodb-backup-sop
    title: Docmost & NocoDB Backup SOP
    summary: Standard operating procedure for database, storage, and offsite backups covering Docmost and NocoDB.
    status: active
    owner: ops
    tags:

    - backup
    - docmost
    - nocodb
      last_reviewed_at: 2025-10-26

    ---

    # Docmost & NocoDB Backup SOP

    ## Scope & Targets

    - **Docmost**: Postgres database (`docmost`​), Redis not persisted, file storage under `/srv/docmost/storage`.
    - **NocoDB**: Postgres database (`nocodb`​), attachment directory `/srv/nocodb/nc_data`​, config files (`.env`​, `docker-compose.yml`).
    - **Monitoring data**: Uptime Kuma SQLite (`/srv/monitoring/uptime-kuma-data/kuma.db`) included in weekly cycle.

    ## Backup Layout

    - Local staging root: `/srv/backups`.

      - ​`daily/` – most recent 7 rolling dumps.
      - ​`weekly/` – retained for 4 weeks.
      - ​`monthly/` – retained for 6 months.
    - Offsite: OCI Object Storage bucket `infra-backups`​ (Standard tier). Sync via `oci os object put`.

    ## Daily Job (02:15 UTC)

    1. Create timestamp variable: `STAMP=$(date -u +"%Y%m%dT%H%M")`.
    2. Dump Docmost DB:

        ```bash
        sudo docker exec docmost-postgres pg_dump -Fc -U docmost docmost \
          > /srv/backups/daily/docmost-db-${STAMP}.dump
        ```
    3. Dump NocoDB DB:

        ```bash
        sudo docker exec nocodb-postgres pg_dump -Fc -U nocodb nocodb \
          > /srv/backups/daily/nocodb-db-${STAMP}.dump
        ```
    4. Archive file stores:

        ```bash
        sudo tar -C /srv/docmost -czf /srv/backups/daily/docmost-files-${STAMP}.tar.gz storage
        sudo tar -C /srv/nocodb -czf /srv/backups/daily/nocodb-files-${STAMP}.tar.gz nc_data
        ```
    5. Copy stack configs:

        ```bash
        sudo cp /srv/docmost/.env /srv/backups/daily/docmost-env-${STAMP}
        sudo cp /srv/nocodb/.env /srv/backups/daily/nocodb-env-${STAMP}
        ```
    6. Prune local dailies older than 7 days: `find /srv/backups/daily -mtime +7 -delete`.

    _Automation_: place commands in `/usr/local/bin/backup-doc-platform.sh`​ and trigger via systemd timer (`backup-doc-platform.service`​ / `.timer`).

    ## Weekly Offsite Sync (Sundays 03:30 UTC)

    The systemd timer `backup-sync-oci.timer`​ calls `/usr/local/sbin/sync-to-oci.sh`, which:

    1. Determines the latest backup stamp (`docmost-db-*.dump`​) and copies matching artifacts from `/srv/backups/daily`​ into `/srv/backups/weekly/<stamp>/`.
    2. If the run falls on the first Sunday of the month, promotes the same stamp into `/srv/backups/monthly/<stamp>/`.
    3. Uploads the staged folders to OCI Object Storage bucket `infra-backups`​ under `weekly/<hostname>/<stamp>/`​ (and `monthly/<hostname>/<stamp>/`​ when applicable) via `oci os object sync`.
    4. Prunes local folders beyond retention windows (weekly: 35 days / 4 copies, monthly: 6 months / 6 copies) and trims remote prefixes older than the retain window using `oci os object bulk-delete`.
    5. Logs to `/srv/backups/oci-sync.log` for post-run validation.

    ## Restore Workflow

    ### Docmost

    1. Stop stack: `cd /srv/docmost && sudo docker compose down`.
    2. Restore storage: `sudo tar -C /srv/docmost -xzf /srv/backups/<tier>/docmost-files-YYYYMMDDT*.tar.gz`.
    3. Restore DB:

        ```bash
        sudo docker compose up -d docmost-postgres
        cat /srv/backups/<tier>/docmost-db-YYYYMMDDT*.dump | \
          sudo docker exec -i docmost-postgres pg_restore -U docmost -d docmost --clean
        ```
    4. Restart stack: `sudo docker compose up -d`.

    ### NocoDB

    1. Stop stack: `cd /srv/nocodb && sudo docker compose down`.
    2. Restore attachments: `sudo tar -C /srv/nocodb -xzf /srv/backups/<tier>/nocodb-files-YYYYMMDDT*.tar.gz`.
    3. Restore DB similarly:

        ```bash
        sudo docker compose up -d nocodb-postgres
        cat /srv/backups/<tier>/nocodb-db-YYYYMMDDT*.dump | \
          sudo docker exec -i nocodb-postgres pg_restore -U nocodb -d nocodb --clean
        ```
    4. Bring stack online: `sudo docker compose up -d`.

    ### Uptime Kuma (weekly)

    ```bash
    sudo docker compose down uptime-kuma
    sudo cp /srv/backups/<tier>/uptime-kuma-data-YYYYMMDDT*.tar.gz /srv/monitoring/
    sudo tar -C /srv/monitoring -xzf uptime-kuma-data-YYYYMMDDT*.tar.gz
    sudo docker compose up -d uptime-kuma
    ```
    ## Verification Cadence

    - **Daily**: monitor backup script exit codes (systemd `Status=`​), ensure files appear under `/srv/backups/daily`.
    - **Weekly**: confirm OCI bucket upload (`oci os object list -bn infra-backups --prefix weekly/${HOSTNAME}/${STAMP}`).
    - **Quarterly**: perform restore drill in staging VM; document outcome in `MIGRATION_TASKS.md`.
    - **After major upgrades**: run immediate manual backup prior to deploy.

    ## Security & Compliance

    - Restrict `/srv/backups` to root (700). Provide read-only SFTP role if human access required.
    - Store Object Storage auth keys in `/home/ubuntu/.oci/config` (600).
    - Encrypt archives at rest if auditing demands (`gpg --symmetric`).

    ## Change Management

    - Log backup/restore events in `MIGRATION_TASKS.md`.
    - If retention windows or storage targets change, update this SOP and notify Ops via Docmost runbook.

    ## Automation Assets

    - Script: `ops/backup/backup-doc-platform.sh`
    - Systemd unit: `ops/backup/backup-doc-platform.service`
    - Systemd timer: `ops/backup/backup-doc-platform.timer`
    - Log file: `/srv/backups/backup-doc-platform.log`
    - Validate with `sudo systemctl status backup-doc-platform.timer`​ and inspect `/srv/backups/backup-doc-platform.log` after the first run.

    ### Offsite Sync – Google Drive

    - Script: `ops/backup/sync-to-gdrive.sh`
    - Systemd unit: `ops/backup/sync-to-gdrive.service`
    - Systemd timer: `ops/backup/sync-to-gdrive.timer`
    - Remote: `gdrive:doc-platform-backups`

    #### Remote Configuration

    1. Install rclone (`curl -s https://rclone.org/install.sh | sudo bash` already executed on host).
    2. As root, run `sudo rclone config`​ and create a remote named `gdrive`:

        - Storage: `drive`
        - Scope: `drive.file`​ (or `drive` for full access as required)
        - Use `rclone authorize "drive"` on a workstation to complete the OAuth flow and paste the token back into the host.
        - Leave `root_folder_id`​ empty unless using a shared drive; set `team_drive` only if needed.
    3. Protect `/root/.config/rclone/rclone.conf` (mode 600).

    #### Deployment Steps

    ```bash
    sudo install -m 700 ops/backup/sync-to-gdrive.sh /usr/local/sbin/sync-to-gdrive.sh
    sudo install -m 644 ops/backup/sync-to-gdrive.service /etc/systemd/system/backup-sync-gdrive.service
    sudo install -m 644 ops/backup/sync-to-gdrive.timer /etc/systemd/system/backup-sync-gdrive.timer
    sudo systemctl daemon-reload
    sudo systemctl enable --now backup-sync-gdrive.timer
    ```
    - Timer schedule: 02:45 UTC daily (after local backup). Check status with `sudo systemctl status backup-sync-gdrive.timer`.
    - Logs: `/srv/backups/gdrive-sync.log`.
    - Remote retention: script prunes Google Drive objects older than 35 days and removes empty folders.
    - Verification: `sudo rclone ls gdrive:doc-platform-backups/daily/<STAMP>` should list tar/dump artifacts (initial run confirmed 20251022T0325 upload).

    ### Offsite Sync – OCI Object Storage

    - Script: `ops/backup/sync-to-oci.sh`
    - Systemd unit: `ops/backup/sync-to-oci.service`
    - Systemd timer: `ops/backup/sync-to-oci.timer`
    - Bucket: `infra-backups`​ (Standard tier), namespace retrieved via `oci os ns get`.

    #### Deployment Steps

    ```bash
    sudo install -m 700 ops/backup/sync-to-oci.sh /usr/local/sbin/sync-to-oci.sh
    sudo install -m 644 ops/backup/sync-to-oci.service /etc/systemd/system/backup-sync-oci.service
    sudo install -m 644 ops/backup/sync-to-oci.timer /etc/systemd/system/backup-sync-oci.timer
    sudo systemctl daemon-reload
    sudo systemctl enable --now backup-sync-oci.timer
    ```
    - Timer schedule: Sundays 03:30 UTC (after nightly runs) with `RandomizedDelaySec=5m`.
    - Logs: `/srv/backups/oci-sync.log`.
    - Remote retention: script keeps the newest four weekly and six monthly prefixes; older data removed via `oci os object bulk-delete`.
    - Verification: `oci os object list -bn infra-backups --prefix weekly/<hostname>/` should show the promoted stamp; confirm monthly path after the first-Sunday run.

    ### Docmost Markdown Sync (Container, every 10 minutes)

    - Script: `ops/docmost/export-markdown.sh`
    - Container assets: `ops/docmost-exporter/Dockerfile`​, `ops/docmost-exporter/entrypoint.sh`
    - Runtime config: provide Docmost credentials via an env file (`/secrets/docmost-export.env`​) or environment variables (supports either `DOCMOST_EMAIL`​/`DOCMOST_PASSWORD`​ or a pre-generated `DOCMOST_AUTH_TOKEN`​). `DOCMOST_AUTH_TOKEN` is preferred for long-lived automation; when set, username/password are optional.
    - Destination: `/srv/docmost/exports/markdown/latest/`​ mirrored to `gdrive:docmost-markdown`
    - Rclone config is copied into a tmpfs workspace each run before syncing so refresh tokens written by rclone never touch the host filesystem.

    #### Build Image

    ```bash
    docker build -f ops/docmost-exporter/Dockerfile -t docmost-exporter .
    ```
    #### Deploy via Compose

    ```yaml
    services:
      docmost-exporter:
        image: docmost-exporter
        restart: unless-stopped
        environment:
          DOCMOST_BASE_URL: https://wiki.aienablement.academy
          DOCMOST_AUTH_TOKEN: ${DOCMOST_AUTH_TOKEN:-}
          DOCMOST_EMAIL: ${DOCMOST_EMAIL:-}
          DOCMOST_PASSWORD: ${DOCMOST_PASSWORD:-}
          REMOTE_NAME: gdrive
          REMOTE_PATH: docmost-markdown
          EXPORT_INTERVAL: 600
          CONFIG_FILE: ""                 # rely on env vars instead of file
          RCLONE_CONFIG: /secrets/rclone.conf
        volumes:
          - /srv/docmost/exports/markdown:/exports
          - /root/.config/rclone/rclone.conf:/secrets/rclone.conf:ro
        networks:
          - reverse-proxy
    ```
    > If you prefer file-based secrets, mount `/etc/docplatform/docmost-export.env`​ into the container at `/secrets/docmost-export.env`​. Supported keys: `DOCMOST_BASE_URL`​, `DOCMOST_EMAIL`​, `DOCMOST_PASSWORD`​, `DOCMOST_AUTH_TOKEN`.
    >

    - Interval: default 600 s (`EXPORT_INTERVAL`​). Each run regenerates `/exports/<space>/…` and prunes stale directories before syncing to Google Drive.
    - Verification: observe container logs (`docker compose logs -f docmost-exporter`​) and confirm new Markdown files under `/srv/docmost/exports/markdown/latest`​ plus `rclone ls gdrive:docmost-markdown`.
    - One-off run: set `EXPORT_RUN_ONCE=true`​ (e.g., `docker run --rm -e EXPORT_RUN_ONCE=true … docmost-exporter`) to trigger a manual export without starting the loop.

    ### NocoDB CSV Snapshots (Host script, hourly)

    - Script: `ops/backup/export-nocodb-csv.sh`
    - Purpose: export every public table from the NocoDB Postgres database to CSV for quick analysis without restoring dumps.
    - Output: `/srv/nocodb/exports/csv/<stamp>/schema_table.csv`​ with `latest/` symlink; retention trims directories older than 14 days.
    - Deployment:

      ```bash
      sudo install -m 700 ops/backup/export-nocodb-csv.sh /usr/local/sbin/export-nocodb-csv.sh
      ```
      Add a systemd timer (e.g., hourly) or reuse existing backup timer to run after nightly DB dumps:

      ```ini
      # /etc/systemd/system/export-nocodb-csv.service
      [Service]
      Type=oneshot
      ExecStart=/usr/local/sbin/export-nocodb-csv.sh

      # /etc/systemd/system/export-nocodb-csv.timer
      [Timer]
      OnCalendar=*-*-* 02:30:00
      RandomizedDelaySec=5m
      Persistent=true

      [Install]
      WantedBy=timers.target
      ```
      Reload systemd and enable:

      ```bash
      sudo systemctl daemon-reload
      sudo systemctl enable --now export-nocodb-csv.timer
      ```
    - Optional offsite sync: extend the existing Google Drive sync script to copy `/srv/nocodb/exports/csv/latest`​ to `gdrive:nocodb-csv/latest` for analyst access.
    - Verification: confirm CSV files appear under `/srv/nocodb/exports/csv/<stamp>`​ and run `rclone ls gdrive:nocodb-csv/latest` if offsite sync is configured.
