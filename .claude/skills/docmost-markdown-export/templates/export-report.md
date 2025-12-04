# Docmost Markdown Export Report

- **Triggered by:** {{ operator }}
- **Execution time:** {{ timestamp_utc }}
- **Host:** {{ host }}
- **Docmost instance:** {{ docmost_base_url }}
- **Remote destination:** {{ remote_name }}:{{ remote_path }}

## Summary
- Spaces processed: {{ space_count }}
- Successful exports: {{ success_count }}
- Failures: {{ failure_count }}
- Duration: {{ duration_human }}

## Remote Sync
- Sync status: {{ rclone_status }}
- Bytes transferred: {{ bytes_transferred }}
- Files updated: {{ files_updated }}

## Notes
{{ notes }}

## Follow-up Actions
- [ ] Verify latest snapshot in remote storage
- [ ] Share export link with stakeholders / agents
- [ ] Investigate any failures logged above
