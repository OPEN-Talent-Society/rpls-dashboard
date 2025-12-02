---
name: digitalocean-infrastructure
description: DigitalOcean infrastructure management skill. Use this when you need to manage droplets, apps, images, or other DO resources. This skill provides guidance on enabling the DigitalOcean MCP server on-demand to save context tokens when not actively managing infrastructure.
status: active
owner: platform
last_reviewed_at: 2025-12-01
tags:
  - infrastructure
  - digitalocean
  - droplets
  - apps
  - cloud
dependencies: []
outputs:
  - droplet-management
  - app-deployment
  - infrastructure-config
---

# DigitalOcean Infrastructure Skill

This skill provides guidance for managing DigitalOcean infrastructure. The MCP server is **NOT loaded by default** to save context tokens - enable it only when needed.

## When to Use This Skill

Use this skill when you need to:
- Create, manage, or delete Droplets
- Deploy or manage App Platform applications
- Work with images, snapshots, or backups
- Resize or scale infrastructure
- Manage networking (VPCs, load balancers)

## Enabling the MCP Server

To enable DigitalOcean MCP, add this to `.claude/mcp.json`:

```json
{
  "digitalocean-mcp": {
    "type": "stdio",
    "command": "pnpm",
    "args": [
      "dlx",
      "@digitalocean/mcp@latest",
      "--services",
      "droplets,apps"
    ],
    "env": {
      "DIGITALOCEAN_API_TOKEN": "${DIGITALOCEAN_API_TOKEN}"
    }
  }
}
```

Then restart Claude Code to load the new MCP.

## Available Tools (when enabled)

### Droplet Management
- `mcp__digitalocean-mcp__droplet-list` - List all droplets
- `mcp__digitalocean-mcp__droplet-get` - Get droplet by ID
- `mcp__digitalocean-mcp__droplet-create` - Create new droplet
- `mcp__digitalocean-mcp__droplet-delete` - Delete droplet
- `mcp__digitalocean-mcp__resize-droplet` - Resize droplet
- `mcp__digitalocean-mcp__power-on-droplet` - Power on
- `mcp__digitalocean-mcp__power-off-droplet` - Power off
- `mcp__digitalocean-mcp__reboot-droplet` - Reboot
- `mcp__digitalocean-mcp__snapshot-droplet` - Take snapshot

### App Platform
- `mcp__digitalocean-mcp__apps-list` - List all apps
- `mcp__digitalocean-mcp__apps-get-info` - Get app details
- `mcp__digitalocean-mcp__apps-create-app-from-spec` - Create app from spec
- `mcp__digitalocean-mcp__apps-update` - Update app
- `mcp__digitalocean-mcp__apps-delete` - Delete app
- `mcp__digitalocean-mcp__apps-get-deployment-status` - Deployment status
- `mcp__digitalocean-mcp__apps-get-logs` - Get app logs

### Image Management
- `mcp__digitalocean-mcp__image-list` - List images
- `mcp__digitalocean-mcp__image-get` - Get image
- `mcp__digitalocean-mcp__image-create` - Create custom image
- `mcp__digitalocean-mcp__image-delete` - Delete image
- `mcp__digitalocean-mcp__image-action-transfer` - Transfer to region

### Other Tools
- `mcp__digitalocean-mcp__region-list` - List regions
- `mcp__digitalocean-mcp__size-list` - List droplet sizes

## Common Workflows

### Create a Droplet
```
1. List available sizes: mcp__digitalocean-mcp__size-list
2. List available regions: mcp__digitalocean-mcp__region-list
3. List images: mcp__digitalocean-mcp__image-list (type: "distribution")
4. Create droplet: mcp__digitalocean-mcp__droplet-create
   - Name: "my-droplet"
   - Size: "s-1vcpu-1gb"
   - Region: "nyc3"
   - ImageID: (from image list)
```

### Deploy App Platform App
```
1. Create app spec (see DO docs for format)
2. Use mcp__digitalocean-mcp__apps-create-app-from-spec
3. Monitor with mcp__digitalocean-mcp__apps-get-deployment-status
4. View logs with mcp__digitalocean-mcp__apps-get-logs
```

## Environment Variables

Ensure this is set in your environment:
```bash
export DIGITALOCEAN_API_TOKEN="your-api-token"
```

## Token Savings

By keeping this MCP disabled when not needed:
- **Saves ~15k-25k context tokens** per session
- Enable only when actively managing infrastructure
- Disable after completing infrastructure tasks

## Disable After Use

After completing infrastructure work, remove from `mcp.json` and restart to reclaim context tokens.

---

*DigitalOcean Infrastructure Skill v1.0*
