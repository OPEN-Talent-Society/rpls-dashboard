---
name: doc-platform-backup
description: End-to-end backup of Docmost, NocoDB, and automation stacks including databases, storage volumes, and remote syncs
---

# Documentation Platform Backup Skill

This skill captures the entire documentation platform footprint—Docmost, NocoDB, automation workflows, and supporting assets—into consistent backups suitable for disaster recovery, migrations, and offline analysis.

## When to Use This Skill
- Nightly or weekly full backups of the documentation platform
- Before major upgrades or infrastructure changes
- Prior to experimenting with data migrations or schema changes
- Validating backup/restore procedures during fire drills
- Supplying AI agents with the latest platform snapshot for analysis

## Scope
- Docmost Postgres database and storage (`/srv/docmost`)
- NocoDB Postgres database and attachment storage (`/srv/nocodb`)
- Automation and monitoring stacks (n8n, dashboard, monitoring)
- Configuration and `.env` files captured via tarball

## Prerequisites
- Host access with sudo privileges
- Sufficient space under `/srv/backups/doc-platform`
- Optional: credentials for OCI Object Storage or Google Drive sync jobs
- Ensure containers are healthy before running the backup

## Workflow Overview
1. Run service health checks (Docmost `/api/health`, NocoDB `/api/v1/health`)
2. Dump databases using `pg_dump`
3. Archive storage volumes and configuration files
4. Record verification metadata (checksums, timestamps)
5. Sync the backup bundle to remote destinations (OCI/GDrive)
6. Rotate old backups according to retention policy

## Reference Script
- `scripts/run-backup.sh` – wraps `ops/backup/backup-doc-platform.sh`

## Templates
- `templates/backup-report.md` – comprehensive report for each backup run
- `templates/restore-checklist.md` – guidance for scheduled restore drills

## Usage Examples
- "Run full documentation platform backup to OCI"
- "Backup Docmost and NocoDB before upgrading"
- "Trigger full backup and generate report for audit"

## Safety & Validation
- Script performs health checks before starting
- Checksums generated for every artifact
- Remote sync logged for auditing
- Retention policy enforced to prevent disk exhaustion

## Post-Run Checklist
- Confirm new backup directory exists under `/srv/backups/doc-platform`
- Verify remote copy completed successfully
- Update project tracker with backup ID and location
- Schedule periodic restore tests using `templates/restore-checklist.md`
