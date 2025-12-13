# Vercel Deployment Skill

**AI Cloud platform for zero-config deployments, serverless/edge functions, and multi-tenant applications**

## Quick Start

```bash
# Install Vercel CLI
pnpm add -g vercel

# Login
vercel login

# Deploy (from project directory)
vercel

# Deploy to production
vercel --prod
```

## What This Skill Covers

### Core Capabilities
- **Zero-Config Deployment** - Automatic framework detection and optimization
- **Serverless Functions** - 250MB, 300s timeout, full Node.js API
- **Edge Functions** - 4MB, sub-40ms cold start, V8 runtime
- **Domain Management** - DNS automation, wildcard SSL, Domain Connect
- **Environment Variables** - Encrypted, sensitive mode, 64KB limit
- **CI/CD Integration** - GitHub Actions, GitLab CI, webhooks
- **Observability** - Drains (OpenTelemetry), Web Analytics, Speed Insights
- **Team Collaboration** - RBAC, project roles, access groups

### 2025 Innovations
- **Unified Runtime** - Edge Middleware + Functions merged
- **Vercel Drains** - Export traces, logs, analytics to any destination
- **Domain Connect** - One-click DNS automation
- **Active CPU Pricing** - Pay only for execution time
- **Fluid Compute** - Concurrent request handling in single instance
- **Vercel for Platforms** - Multi-tenant SaaS infrastructure

### When to Use Vercel
✅ **Perfect For:**
- Next.js applications (official platform)
- Static sites (React, Vue, Svelte)
- Serverless APIs and microservices
- Edge computing use cases
- AI-powered applications (Vercel AI SDK)
- Multi-tenant platforms
- Rapid prototyping and MVP deployment

❌ **Consider Alternatives If:**
- You need long-running processes (>300s)
- You require traditional VM/container control
- You need persistent WebSocket servers
- Budget is extremely constrained (self-hosted cheaper at scale)

## Example: Next.js Deployment

### 1. Basic Deployment

```bash
# Initialize project (if needed)
pnpx create-next-app@latest my-app

# Deploy
cd my-app
vercel

# Deploy to production
vercel --prod
```

### 2. Serverless Function

```typescript
// api/hello.ts
import type { VercelRequest, VercelResponse } from '@vercel/node';

export default function handler(req: VercelRequest, res: VercelResponse) {
  const { name = 'World' } = req.query;
  res.status(200).json({ message: `Hello, ${name}!` });
}
```

### 3. Edge Function

```typescript
// middleware.ts (Next.js Edge Middleware)
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  // Check authentication
  const token = request.cookies.get('auth-token');

  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: '/dashboard/:path*',
};
```

### 4. Environment Variables

```bash
# Add environment variable
vercel env add DATABASE_URL production

# Pull environment variables to local
vercel env pull .env.local

# List all environment variables
vercel env ls
```

## Architecture

```
┌─────────────────────────────────────────────┐
│              Global CDN                      │
│  (Automatic caching, Edge network)          │
└──────────────┬──────────────────────────────┘
               │
        ┌──────┴───────┐
        │              │
        ▼              ▼
┌──────────────┐  ┌──────────────┐
│ Edge Runtime │  │   Serverless │
│ (V8, 4MB)    │  │  (Node.js)   │
│ <40ms cold   │  │  250MB, 300s │
└──────────────┘  └──────────────┘
        │              │
        └──────┬───────┘
               ▼
┌─────────────────────────────────────────────┐
│         Application Code                     │
│  (Next.js, React, Vue, Svelte, Static)      │
└─────────────────────────────────────────────┘
```

## CLI Commands

### Essential Commands

```bash
# Authentication
vercel login                    # Login to Vercel
vercel logout                   # Logout
vercel whoami                   # Show current user

# Project Management
vercel link                     # Link directory to project
vercel init [template]          # Initialize from template
vercel list                     # List all projects

# Deployment
vercel                          # Deploy to preview
vercel --prod                   # Deploy to production
vercel --prebuilt              # Deploy pre-built output
vercel --force                 # Force new deployment

# Development
vercel dev                      # Start local dev server
vercel dev --debug             # Dev with debug output

# Environment Variables
vercel env add [name] [env]    # Add variable
vercel env ls                  # List all variables
vercel env rm [name] [env]     # Remove variable
vercel env pull [file]         # Pull to local file

# Domain Management
vercel domains add [domain]    # Add domain
vercel domains ls              # List domains
vercel domains rm [domain]     # Remove domain
vercel certs issue [domain]    # Issue SSL certificate

# Logs & Monitoring
vercel logs [url]              # View deployment logs
vercel inspect [url]           # Inspect deployment
```

### Advanced Commands

```bash
# Team Management
vercel teams list              # List teams
vercel teams switch [team]     # Switch to team

# Build Management
vercel build                   # Build project locally
vercel cache clean             # Clear build cache

# Blob Storage
vercel blob add [file]         # Upload to blob storage
vercel blob ls                 # List blobs
vercel blob rm [key]           # Delete blob

# Deployment Management
vercel promote [url]           # Promote deployment to production
vercel rollback                # Rollback to previous production
vercel rm [name]               # Remove project
```

## Best Practices

### 1. Function Optimization

**Serverless Functions:**
```typescript
// ✅ GOOD - Reuse connections
import { createClient } from '@supabase/supabase-js';

let supabase: any;

export default async function handler(req, res) {
  if (!supabase) {
    supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_KEY!);
  }
  // Use supabase...
}
```

**Edge Functions:**
```typescript
// ✅ GOOD - Minimal dependencies
import { geolocation } from '@vercel/edge';

export const config = { runtime: 'edge' };

export default function handler(req: Request) {
  const { country } = geolocation(req);
  return new Response(`Hello from ${country}!`);
}
```

### 2. Environment Variables

```bash
# ✅ GOOD - Use sensitive mode for secrets
vercel env add API_KEY production --sensitive

# ✅ GOOD - Separate environments
vercel env add DATABASE_URL development
vercel env add DATABASE_URL production
```

### 3. Domain Configuration

```bash
# Add custom domain
vercel domains add example.com

# Add wildcard domain (Enterprise only)
vercel domains add "*.example.com"

# Configure DNS via CLI
vercel dns add example.com A 192.168.1.1
```

### 4. Deployment Strategies

**Preview Deployments:**
- Automatically created for every git push
- Unique URL per commit/branch
- Perfect for code review and testing

**Production Deployments:**
- Created on merge to main/production branch
- Can be created manually with `vercel --prod`
- Supports rolling releases and instant rollbacks

**Custom Environments (Pro/Enterprise):**
```bash
# Deploy to staging environment
vercel deploy --target=staging

# Pull staging variables
vercel pull --environment=staging
```

### 5. Observability

**Vercel Drains (Export to External):**
```json
// vercel.json
{
  "observability": {
    "drains": [
      {
        "name": "datadog",
        "endpoint": "https://http-intake.logs.datadoghq.com/v1/input",
        "headers": {
          "DD-API-KEY": "@datadog-api-key"
        }
      }
    ]
  }
}
```

**Web Analytics:**
```typescript
// Enable in Next.js
// next.config.js
module.exports = {
  analytics: {
    enabled: true
  }
}
```

## Integration Examples

### 1. Next.js with Database

```typescript
// app/api/users/route.ts
import { sql } from '@vercel/postgres';

export async function GET() {
  try {
    const { rows } = await sql`SELECT * FROM users`;
    return Response.json(rows);
  } catch (error) {
    return Response.json({ error }, { status: 500 });
  }
}
```

### 2. GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy to Vercel
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
```

### 3. Multi-Tenant Platform

```typescript
// middleware.ts - Subdomain routing
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const hostname = request.headers.get('host') || '';
  const subdomain = hostname.split('.')[0];

  // Route to tenant-specific page
  if (subdomain && subdomain !== 'www') {
    return NextResponse.rewrite(new URL(`/tenant/${subdomain}${request.nextUrl.pathname}`, request.url));
  }

  return NextResponse.next();
}
```

### 4. Vercel AI SDK

```typescript
// app/api/chat/route.ts
import { openai } from '@ai-sdk/openai';
import { streamText } from 'ai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4-turbo'),
    messages,
  });

  return result.toDataStreamResponse();
}
```

## Pricing Tiers

### Hobby (Free)
- 100 GB bandwidth/month
- 6,000 build minutes/month
- Serverless execution: 100 GB-hours/month
- 1 project

### Pro ($20/user/month)
- 1 TB bandwidth/month (then $0.15/GB)
- 24,000 build minutes/month
- Serverless execution: 1,000 GB-hours/month
- Web Analytics
- 1 custom environment
- Password protection

### Enterprise (Custom)
- Custom bandwidth and compute
- 12 custom environments
- Advanced security (SAML, SOC 2)
- 99.99% SLA
- Priority support
- White-label options

## Resources

- **Official Docs:** https://vercel.com/docs
- **API Reference:** https://vercel.com/docs/rest-api
- **CLI Reference:** https://vercel.com/docs/cli
- **Templates:** https://vercel.com/templates
- **AI SDK:** https://sdk.vercel.ai/docs
- **Community:** https://vercel.com/community
- **Research Report:** `VERCEL-PLATFORM-RESEARCH-2025.md`

## Troubleshooting

### Common Issues

**Build failures:**
```bash
# Check build logs
vercel logs [deployment-url]

# Try local build
vercel build

# Clear cache
vercel cache clean
```

**Environment variables not working:**
```bash
# Pull latest variables
vercel env pull .env.local

# Verify variables are set
vercel env ls
```

**Domain not resolving:**
```bash
# Check DNS configuration
vercel domains inspect example.com

# Verify SSL certificate
vercel certs ls
```

**Function timeouts:**
- Upgrade to Pro for 300s timeout
- Move long-running tasks to background jobs
- Use streaming responses for gradual output

**Edge function limits:**
- Keep bundle under 4MB
- Use Web APIs only (no Node.js APIs)
- Minimize dependencies

## Security Best Practices

### 1. Environment Variables
- Use `--sensitive` flag for secrets
- Never commit `.env` files
- Rotate secrets regularly

### 2. Authentication
- Implement edge authentication for low latency
- Use JWT verification at edge
- Rate limit API endpoints

### 3. Headers
```json
// vercel.json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" },
        { "key": "X-XSS-Protection", "value": "1; mode=block" }
      ]
    }
  ]
}
```

### 4. Firewall (Enterprise)
- Configure IP allowlists/denylists
- Set up DDoS protection
- Enable WAF rules

## Next Steps

1. Read the full skill documentation: `skill.md`
2. Review the research report: `VERCEL-PLATFORM-RESEARCH-2025.md`
3. Explore templates: https://vercel.com/templates
4. Try the AI SDK: https://sdk.vercel.ai
5. Join the community: https://vercel.com/community

---

**Skill Location:** `.claude/skills/vercel-deployment/`
**Last Updated:** 2025-12-09
**Maintained By:** Claude Code Agent Swarm
