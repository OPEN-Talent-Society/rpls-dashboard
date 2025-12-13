# linux-server-operations

---

name: linux-server-operations
description: Linux server administration specialist for system management, security, performance tuning, and infrastructure automation
auto-triggers:
  - linux server administration
  - ubuntu server management
  - system security hardening
  - server performance tuning
  - firewall configuration ufw
  - ssh security configuration
  - system monitoring logs
model: opus
color: orange
id: linux-server-operations
summary: Guidance for administering the underlying OCI Linux host, including security, patching, and troubleshooting.
status: active
owner: ops
last_reviewed_at: 2025-10-26
domains:

- infrastructure
- security
  tooling:
- linux
- ssh
- monitoring

---

# Linux Server Operations Guide

#linux #ops/infrastructure #runbook #class/runbook

## Scope

- Applies to Ubuntu 22.04+ hosts (OCI `docker-host`) and future Linux servers.
- Covers system updates, hardening, monitoring, and troubleshooting.

## Baseline Setup

```
sudo apt update && sudo apt upgrade -y
sudo unattended-upgrade
```

- Users & SSH: create admin user, grant sudo via `/etc/sudoers.d/<user>`, disable password auth and root login, enable fail2ban.
- Firewall:

```
sudo ufw allow 22,80,443/tcp
sudo ufw enable
```

- Time sync: ensure `systemd-timesyncd`​ active; set timezone `timedatectl set-timezone UTC`.

## Monitoring & Logs

- Journald persistent storage (`/etc/systemd/journald.conf`​: `Storage=persistent`).
- Review logs:

```
sudo journalctl -u docker -n 200
sudo journalctl --since "1 hour ago" -p err
```

- Resource checks: `htop`​, `iostat`​, `df -h`​, `docker stats`.
- Integrate with Netdata/Uptime Kuma for continuous monitoring.

## Maintenance

- Security patches: monitor CVEs or subscribe to Ubuntu Pro.
- Kernel updates: schedule reboots during low traffic (announce via status page).
- Backups: include `/etc`​, `/var/backups`, and application volumes in offsite sync.
- Disk management: alert at 70 %, prune old logs and Docker artifacts.

## Troubleshooting

- Service failures: `systemctl status <service>`, restart if necessary.
- Network: `ip addr`​, `ip route`​, `ss -tulpn`​, `sudo tcpdump -i eth0 port 443`.
- Filesystem: `sudo smartctl -H /dev/sda`​, plan maintenance for `fsck`.
- Performance: inspect high CPU, swap usage, adjust sysctl (`vm.swappiness`​, `net.core.somaxconn`).

## References

- Ubuntu Server Docs – https://ubuntu.com/server/docs
- journald – https://www.freedesktop.org/software/systemd/man/journalctl.html
