# Infrastructure Expansion Plugin

Toolkit for managing the on-prem + OCI infrastructure estate: Proxmox, NAS, Docmost, NocoDB, monitoring, and network access.

## Included Assets
- **Agents**: `proxmox-ops`, `nas-backup-admin`, `docker-host-operations`, `docker-operations`, `docmost-admin`, `docmost-nocodb-agent`, `tailscale-operations`, `uptime-kuma-operations`, `oci-operations`, `digitalocean-operations`.
- **Skills**: `infra-health`, `backup-rotation`, `tailscale-access-review`, existing platform skills (Docmost export, docker deploy).
- **Commands**: `/infra:health`, `/infra:backup`.
- **Hooks**: infrastructure heartbeat, backup verifier.

## Usage
Install locally via `claude plugin install infrastructure-expansion@local` after running `scripts/sync/claude-sync.sh`. The plugin mirrors canonical markdown from `.docs/`.
