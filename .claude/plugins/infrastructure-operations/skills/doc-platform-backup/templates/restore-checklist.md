# Documentation Platform Restore Checklist

## Preparation
- [ ] Identify backup run ID and location
- [ ] Provision restore environment (VM / container stack)
- [ ] Ensure secrets vault access for `.env` files

## Restore Steps
1. Restore Docmost Postgres dump (`pg_restore`)
2. Restore Docmost storage tarball to `/srv/docmost/storage`
3. Restore NocoDB Postgres dump and attachment storage
4. Restore automation/monitoring tarballs as needed
5. Recreate `.env` files from encrypted backups or secrets vault
6. Start Docker stacks (`docker compose up -d` per service)
7. Reconfigure DNS / reverse proxy if performing failover

## Validation
- [ ] Docmost `/api/health` returns 200
- [ ] NocoDB `/api/v1/health` returns OK
- [ ] n8n, dashboard, monitoring stacks reachable
- [ ] Spot-check recent documentation/pages and data tables

## Post-Restore Actions
- [ ] Record findings in tracker (include timing + issues)
- [ ] Update backup skill notes with lessons learned
- [ ] Close or follow up on remediation tasks
