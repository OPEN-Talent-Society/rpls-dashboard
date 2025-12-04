---
name: docmost-markdown-export
description: Automate Docmost space exports to Markdown and synchronize them to offsite storage for human and AI consumption
---

# Docmost Markdown Export Skill

This skill automates Docmost documentation exports, keeps the Markdown mirror current, and ensures backups land in the right remote destinations for both human readers and downstream AI agents.

## When to Use This Skill

Use this skill whenever you need to:
- Produce a fresh Markdown snapshot of all Docmost spaces
- Sync Docmost knowledge into Google Drive or other remote storage
- Provide up-to-date corpora for AI agents and search indexes
- Validate that exports remain healthy after Docmost upgrades
- Schedule recurring exports via cron, systemd timers, or container jobs

## Prerequisites
- Access to the Docmost host (`/srv/docmost` stack) with appropriate credentials
- Rclone configuration for Google Drive or other remotes (`/root/.config/rclone/rclone.conf` on the host)
- Environment secrets file (`/etc/docplatform/docmost-export.env`) or exported `DOCMOST_*` variables

## Workflow Overview
1. Authenticate to Docmost (email/password or existing auth token)
2. Request Markdown exports for every space via the Docmost API
3. Stage the results locally under `/srv/docmost/exports/markdown/latest`
4. Sync the Markdown tree to the configured remote (e.g., `gdrive:docmost-markdown`)
5. Prune aged exports while keeping the canonical `latest/` tree intact
6. Optionally generate and distribute an export summary

## Reference Script
- `scripts/run-export.sh` – wraps the canonical automation at `ops/docmost/export-markdown.sh`

## Templates
- `templates/export-report.md` – standardized summary for each export run (status, remote paths, timestamp)

## Usage Examples
- "Export Docmost spaces and sync to Google Drive"
- "Run Docmost Markdown export with auth token"
- "Generate Docmost export report for weekly knowledge sync"

## Safety & Validation
- Script enforces presence of credentials and rclone config before executing
- Temporary working directories are cleaned automatically on exit
- Remote sync uses `rclone sync` with `--delete` to prevent stale files
- Output log records both Docmost API responses and rclone operations for auditability

## Post-Run Checklist
- Confirm `/srv/docmost/exports/markdown/latest` contains fresh content
- Verify remote destination (e.g., `gdrive:docmost-markdown/latest`) reflects the new snapshot
- Review the generated export report for warnings or failures
