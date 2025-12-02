---
name: vercel-deployment
description: Comprehensive Vercel CLI and API integration for deploying Next.js applications, managing deployments, and monitoring production environments.
status: active
owner: platform
last_reviewed_at: 2025-12-01
tags:
  - deployment
  - vercel
  - hosting
  - serverless
  - edge
  - nextjs
  - payload-cms
dependencies: []
outputs:
  - deployment
  - project-config
  - domain-management
---

# Vercel Deployment Skill

Comprehensive Vercel CLI and API integration for deploying Next.js applications, managing deployments, and monitoring production environments.

## When to Use

Use this skill when:
- Deploying applications to Vercel
- Managing preview and production deployments
- Inspecting deployment status and logs
- Rolling back to previous deployments
- Configuring build settings and framework presets

## Prerequisites

Required environment variables:
- `VERCEL_TOKEN` - Vercel access token (from https://vercel.com/account/tokens)
- `VERCEL_ORG_ID` - Organization/team ID (optional for personal accounts)
- `VERCEL_PROJECT_ID` - Project ID (auto-detected after `vercel link`)

## Vercel CLI Commands

### Installation & Setup

```bash
# Install Vercel CLI globally
pnpm add -g vercel

# Or use without installing
pnpm dlx vercel

# Login to Vercel
vercel login

# Link existing project
vercel link

# Initialize new project
vercel init
```

### Deployment Commands

```bash
# Preview deployment (default)
vercel

# Production deployment
vercel --prod

# Deploy specific directory
vercel ./apps/web --prod

# Deploy with build command override
vercel --build-env NODE_ENV=production

# Deploy and skip build (pre-built)
vercel --prebuilt

# Deploy with specific framework
vercel --framework nextjs

# Force new deployment (skip cache)
vercel --force

# Deploy with custom name
vercel --name my-app-preview

# Deploy to specific team
vercel --scope my-team
```

### Deployment Management

```bash
# List recent deployments
vercel ls

# List deployments for specific project
vercel ls my-project

# Get deployment details
vercel inspect <deployment-url>

# View deployment logs
vercel logs <deployment-url>

# Real-time log streaming
vercel logs <deployment-url> --follow

# Rollback to previous deployment
vercel rollback <deployment-url>

# Remove/cancel deployment
vercel rm <deployment-url>

# Alias deployment to custom domain
vercel alias <deployment-url> <custom-domain>
```

### Build & Preview

```bash
# Local development server (mirrors Vercel)
vercel dev

# Build locally (same as Vercel build)
vercel build

# Pull environment variables for local dev
vercel env pull .env.local
```

## Vercel SDK (TypeScript)

### Installation

```bash
pnpm add @vercel/sdk
```

### Basic Usage

```typescript
import { Vercel } from "@vercel/sdk";

// Initialize client (lazy initialization for SSR safety)
function getVercelClient(): Vercel {
  const token = process.env.VERCEL_TOKEN;
  if (!token) {
    throw new Error('VERCEL_TOKEN not configured');
  }
  return new Vercel({ bearerToken: token });
}

// List deployments
async function listDeployments() {
  const vercel = getVercelClient();
  const { deployments } = await vercel.deployments.getDeployments({
    limit: 10,
    state: "READY"
  });
  return deployments;
}

// Get deployment details
async function getDeployment(idOrUrl: string) {
  const vercel = getVercelClient();
  return await vercel.deployments.getDeployment({
    idOrUrl
  });
}

// Create deployment
async function createDeployment(projectId: string, files: any[]) {
  const vercel = getVercelClient();
  return await vercel.deployments.createDeployment({
    requestBody: {
      name: "my-app",
      project: projectId,
      target: "production",
      files
    }
  });
}
```

### Client Library (Event-Driven Deployments)

```typescript
import { createClient } from "@vercel/client";

const client = createClient({
  token: process.env.VERCEL_TOKEN!,
  teamId: process.env.VERCEL_ORG_ID
});

// Deploy with progress events
async function deployWithProgress(path: string) {
  const deployment = await client.deploy(path, {
    name: "my-app",
    target: "production"
  });

  for await (const event of deployment) {
    switch (event.type) {
      case "building":
        console.log("Building:", event.payload.logs);
        break;
      case "ready":
        console.log("Deployed:", event.payload.url);
        break;
      case "error":
        console.error("Failed:", event.payload.message);
        break;
    }
  }
}
```

## REST API

### Base URL
```
https://api.vercel.com
```

### Authentication
```bash
Authorization: Bearer <VERCEL_TOKEN>
```

### Common Endpoints

```bash
# List deployments
GET /v6/deployments?limit=10&state=READY

# Get deployment
GET /v13/deployments/{idOrUrl}

# Create deployment
POST /v13/deployments
Content-Type: application/json

{
  "name": "my-app",
  "project": "prj_xxx",
  "target": "production",
  "gitSource": {
    "type": "github",
    "repo": "owner/repo",
    "ref": "main"
  }
}

# Cancel deployment
PATCH /v12/deployments/{id}/cancel

# List projects
GET /v9/projects

# Get project
GET /v9/projects/{idOrName}
```

## Monorepo Configuration

### vercel.json for Monorepo

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "buildCommand": "cd ../.. && pnpm build --filter=web",
  "installCommand": "cd ../.. && ppnpm add",
  "framework": "nextjs",
  "outputDirectory": ".next"
}
```

### Root Directory Setting

When deploying from a monorepo subdirectory:
1. Go to Project Settings > General
2. Set "Root Directory" to `apps/web`
3. Vercel auto-detects the monorepo structure

## GitHub Integration

### Automatic Deployments

1. Connect repository in Vercel Dashboard
2. Configure production branch (usually `main`)
3. Each push creates preview deployment
4. Merges to production branch deploy to production

### vercel.json Configuration

```json
{
  "git": {
    "deploymentEnabled": {
      "main": true,
      "dev": false
    }
  },
  "github": {
    "autoAlias": true,
    "autoJobCancelation": true,
    "silent": false
  }
}
```

## Build Configuration

### Framework Presets

Vercel auto-detects frameworks. Override in vercel.json:

```json
{
  "framework": "nextjs",
  "buildCommand": "pnpm build",
  "installCommand": "ppnpm add --frozen-lockfile",
  "outputDirectory": ".next"
}
```

### Build Environment Variables

```json
{
  "build": {
    "env": {
      "NODE_ENV": "production",
      "NEXT_TELEMETRY_DISABLED": "1"
    }
  }
}
```

## Common Patterns

### Health Check Endpoint

```typescript
// app/api/health/route.ts
export async function GET() {
  return Response.json({
    status: "ok",
    timestamp: new Date().toISOString()
  });
}
```

### Deployment Verification

```bash
# After deployment, verify health
curl -s https://your-app.vercel.app/api/health | jq

# Check response headers
curl -I https://your-app.vercel.app
```

### Preview URL Pattern

```
https://{project}-{hash}-{team}.vercel.app
https://{project}-git-{branch}-{team}.vercel.app
```

## Best Practices

### 1. Use Preview Deployments
- Test changes in isolated preview environments
- Share preview URLs for review
- Use branch protection with required checks

### 2. Environment Variable Management
- Use `vercel env pull` for local development
- Separate Development/Preview/Production values
- Never commit secrets to repository

### 3. Build Optimization
- Enable caching with `turbo` or `nx`
- Use standalone output for Next.js
- Minimize bundle size with tree shaking

### 4. Monitoring
- Use Vercel Analytics for performance
- Enable Speed Insights for Core Web Vitals
- Check Function logs for errors

## Integration Points

- **Payload CMS**: Use `@payloadcms/db-vercel-postgres` adapter
- **PostgreSQL**: Use Vercel Postgres or external with connection pooling
- **Blob Storage**: Use Vercel Blob for file uploads
- **KV**: Use Vercel KV for caching/sessions
- **Edge Config**: Use for feature flags and A/B testing

## Troubleshooting

### Build Fails
```bash
# View build logs
vercel logs <deployment-url> --output=raw

# Check build output locally
vercel build --debug
```

### Function Timeout
- Hobby: 10s max
- Pro: 60s max (300s for Streaming)
- Configure in vercel.json: `"functions": { "api/**": { "maxDuration": 60 } }`

### Memory Issues
```json
{
  "functions": {
    "api/**": {
      "memory": 1024
    }
  }
}
```

## Sources
- [Vercel CLI Documentation](https://vercel.com/docs/cli)
- [Vercel SDK](https://www.npmjs.com/package/@vercel/sdk)
- [Vercel REST API](https://vercel.com/docs/rest-api)
- [Next.js on Vercel](https://vercel.com/docs/frameworks/nextjs)

---

*Vercel Deployment Skill v2.0 - Updated 2025-12-01*
