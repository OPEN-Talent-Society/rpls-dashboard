# Documentation Platform Backup Report

- **Run ID:** {{ backup_id }}
- **Triggered by:** {{ operator }}
- **Execution time:** {{ timestamp_utc }}
- **Host:** {{ host }}
- **Backup location:** {{ backup_path }}
- **Remote copies:** {{ remote_targets }}

## Artifacts
| Component | Path | Size | Checksum |
|-----------|------|------|----------|
{{ artifact_rows }}

## Service Health (pre-flight)
- Docmost `/api/health`: {{ docmost_status }}
- NocoDB `/api/v1/health`: {{ nocodb_status }}
- Other services: {{ other_services_status }}

## Remote Sync Summary
- Destination: {{ remote_destination }}
- Status: {{ remote_status }}
- Bytes transferred: {{ remote_bytes }}

## Retention
- Backups removed this run: {{ pruned_backups }}

## Notes
{{ notes }}

## Next Steps
- [ ] Store report in tracker (`.docs/projects/docmost-nocodb-tracker.md`)
- [ ] Schedule restore drill (if pending)
- [ ] Notify stakeholders / AI agents of new snapshot
