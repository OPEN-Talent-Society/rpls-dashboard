---
name: nocodb-csv-export
description: Export NocoDB workspaces to CSV, rotate local snapshots, and sync artifacts for downstream analytics and recovery workflows
---

# NocoDB CSV Export Skill

This skill orchestrates NocoDB data exports, stages timestamped CSV snapshots, and synchronizes them to remote storage so analysts, automation, and AI agents can consume structured datasets without touching production.

## When to Use This Skill
- Nightly or ad-hoc exports of the `public` schema for analytics
- Preparing datasets for offline review or incident response
- Seeding non-production environments with sanitized data
- Validating export pipelines after NocoDB upgrades
- Feeding AI agents with up-to-date relational snapshots

## Prerequisites
- Docker access on the NocoDB host (container name `nocodb-nocodb-db-1` by default)
- Postgres credentials for the NocoDB database
- Sufficient disk space under `/srv/nocodb/exports/csv`
- Optional: Rclone configuration if exports are synced offsite

## Workflow Overview
1. Inspect running containers and ensure the database is reachable
2. Enumerate `public` tables via `psql`
3. Export each table to CSV using `\COPY`
4. Stage results under `/srv/nocodb/exports/csv/<timestamp>/`
5. Refresh the `latest` symlink to the new snapshot
6. Prune snapshots older than the retention window
7. Optionally sync the export directory to cloud storage

## Reference Script
- `scripts/run-export.sh` – delegates to `ops/backup/export-nocodb-csv.sh`

## Templates
- `templates/export-checklist.md` – pre-flight and post-run checklist
- `templates/export-summary.md` – shareable summary for stakeholders

## Usage Examples
- "Export all NocoDB tables to CSV and sync to Drive"
- "Run NocoDB CSV export with custom retention"
- "Prepare CSV snapshot for analytics handoff"

## Safety & Validation
- Verifies container availability before exporting
- Warns if no tables are discovered
- Logs each table export along with file size
- Deletes snapshots older than 14 days by default (configurable)

## Post-Run Checklist
- Confirm the `latest/` symlink points at the new timestamped directory
- Validate remote sync (if enabled) completed successfully
- Spot-check representative CSV files for row counts and headers
