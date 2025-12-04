# NocoDB CSV Export Checklist

## Pre-flight
- [ ] Docker container `nocodb-nocodb-db-1` running
- [ ] Postgres credentials verified (user/password)
- [ ] Disk space available under `/srv/nocodb/exports/csv`
- [ ] Optional rclone remote reachable

## Post-run
- [ ] New timestamped directory created: {{ export_path }}
- [ ] `latest` symlink updated
- [ ] Snapshot synced to remote (if configured)
- [ ] CSV spot-check performed (row counts / headers)
- [ ] Older snapshots pruned according to retention policy
