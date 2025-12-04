# NocoDB CSV Export Summary

- **Triggered by:** {{ operator }}
- **Execution time:** {{ timestamp_utc }}
- **Host:** {{ host }}
- **Database:** {{ database_name }}
- **Snapshot directory:** {{ export_path }}

## Table Exports
| Table | Rows | File Size |
|-------|------|-----------|
{{ table_rows }}

## Sync Status
- Remote: {{ remote_name }}:{{ remote_path }}
- Outcome: {{ sync_status }}
- Bytes transferred: {{ bytes_transferred }}

## Notes
{{ notes }}

## Follow-up Actions
- [ ] Share snapshot link with stakeholders
- [ ] Update analytics dashboards with new data
- [ ] Archive summary in project tracker
