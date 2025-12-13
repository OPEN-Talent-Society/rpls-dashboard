---
name: vercel-deployment
description: Comprehensive Vercel platform management including zero-config deployments, serverless/edge functions, domain management, CI/CD, team collaboration, and observability.
status: active
owner: platform
last_reviewed_at: 2025-12-09
tags:
  - deployment
  - vercel
  - hosting
  - serverless
  - edge
  - nextjs
  - ai-cloud
  - multi-tenant
  - observability
dependencies: []
outputs:
  - deployment
  - project-config
  - domain-management
  - environment-variables
  - team-management
  - monitoring
---

# Vercel Deployment

**Category:** Infrastructure & DevOps
**Type:** Platform Management
**Status:** Production Ready

## Overview

Vercel is the AI Cloud platform for deploying, scaling, and managing modern web applications. This skill provides comprehensive Vercel platform management including zero-config deployments, serverless and edge functions, domain management, environment variables, team collaboration, and observability.

**When to Use This Skill:**

- Deploying Next.js, React, Vue, Svelte, or static sites
- Managing serverless and edge functions
- Configuring custom domains and DNS
- Setting up CI/CD pipelines
- Managing environment variables and secrets
- Implementing multi-tenant platforms
- Monitoring application performance
- Team collaboration and RBAC management

**Platform Evolution (2025):**

- Unified Runtime (Edge Middleware + Functions)
- Vercel for Platforms (multi-tenant support)
- Vercel Drains (OpenTelemetry export)
- Domain Connect (one-click DNS)
- Active CPU Pricing model
- Fluid Compute for concurrent workloads

---

## Core Capabilities

### 1. Deployment

**Zero-Configuration Deployment:**
- Automatic framework detection (Next.js, React, Vue, Svelte, etc.)
- Automatic build optimization
- Global CDN delivery
- Preview deployments for every git push
- Production deployments on merge to main

**Deployment Methods:**
1. **Git Integration** - GitHub, GitLab, Bitbucket
2. **CLI Deployment** - Manual control with `vercel deploy`
3. **API Deployment** - Programmatic via REST API
4. **Deploy Hooks** - Webhook-triggered deployments

**Build Configuration:**
- Maximum build time: 45 minutes
- Build resources (Pro): 8192 MB memory, 23 GB disk, 4 CPUs
- Build caching via Artifacts API
- Custom build commands via `vercel.json`

### 2. Serverless Functions

**Characteristics:**
- Default region: Washington, D.C., USA (configurable)
- Automatic scaling from zero to massive traffic
- Instance reuse for reduced cold starts
- Fluid Compute for concurrent request handling
- Multi-runtime support: Node.js, Bun, Python, Rust, Go, Ruby, WebAssembly

**Specifications:**
- Maximum uncompressed size: 250 MB
- Timeout: 10 seconds (Hobby), 300 seconds (Pro)
- Full Node.js API support (process, fs, path)
- TCP/UDP connections allowed
- Hundreds of milliseconds cold start

**Pricing Model:**
- Active CPU usage charges
- Provisioned memory at 1/11th the rate of active CPU
- Per-invocation charges
- Cost savings with Fluid Compute concurrency

**Use Cases:**
- Database operations
- API endpoints with complex logic
- File processing
- Background jobs
- Third-party service integration

### 3. Edge Functions and Middleware

**Edge Runtime:**
- Built on V8 JavaScript engine
- Lightweight and globally distributed
- Sub-40ms cold starts
- Execute in region closest to user
- 40% faster than hot Serverless Functions
- 15x cheaper for image generation workloads

**Edge Middleware:**
- Runs before caching and routing
- Perfect for authentication, redirects, personalization
- Merged with Edge Functions into unified runtime (June 2025)
- Supports TypeScript, JavaScript, WebAssembly

**Limitations:**
- No native Node.js APIs (process, path, fs)
- No TCP/UDP connections
- Maximum request size: 1 MB
- Maximum function size: 4 MB (including bundled code)
- Maximum response size: 4 MB

**Common Use Cases:**
- JWT authentication at edge
- Geographic routing and personalization
- A/B testing and feature flags
- Bot protection
- Request/response transformation
- Custom redirects and rewrites

### 4. Environment Variables

**Security Features:**
- Encrypted at rest
- Role-based view permissions
- Sensitive Environment Variables (cannot be decrypted after creation)
- Secret redaction in logs

**Environment Types:**
1. **Production** - Live deployments
2. **Preview** - Branch/PR deployments
3. **Development** - Local development

**Size Limits:**
- Total per deployment: 64 KB
- Edge Functions/Middleware: 5 KB per variable

### 5. Domain Management

**DNS Configuration:**
- Vercel nameservers: `ns1.vercel-dns.com`, `ns2.vercel-dns.com`
- Supported record types: A, AAAA, ALIAS, CAA, CNAME, MX, SRV, TXT
- Default TTL: 60 seconds
- Domain Connect (one-click automated DNS setup)

**Custom Domain Workflow:**
1. Add domain to project
2. Verify ownership (TXT record or nameservers)
3. SSL certificate auto-issued
4. DNS propagation (minutes to hours)

**Wildcard Domains:**
- Require Vercel nameservers
- Individual certificates per subdomain
- On-the-fly certificate generation
- Perfect for multi-tenant applications

### 6. Analytics and Monitoring

**Vercel Observability (2025):**
- OpenTelemetry trace export
- Web Analytics events
- Speed Insights metrics
- Custom query notebooks

**Core Capabilities:**

1. **Web Analytics**
   - Page views and visitor tracking
   - Referrer analysis
   - Geographic demographics
   - Device and browser statistics

2. **Speed Insights**
   - Core Web Vitals (LCP, FID, CLS)
   - Real User Monitoring (RUM)
   - Performance budgets
   - Trend analysis

3. **Monitoring**
   - Request rate visualization
   - Error occurrence tracking
   - Bandwidth usage analysis
   - Custom query builder

**Vercel Drains:**
- Stream observability data to external systems
- Supported data types: OpenTelemetry traces, Web Analytics, Speed Insights, logs
- Export pricing: $0.50 per GB
- Available on Pro and Enterprise plans

**Marketplace Integrations:**
- Sentry, Checkly, Dash0, Datadog APM, Honeycomb, Grafana Tempo, New Relic

### 7. CI/CD Integration

**Native Git Integration:**
- GitHub, GitLab, Bitbucket support
- Automatic preview deployments per PR
- Production deployment on merge
- Commit status checks
- PR comments with preview URLs

**Webhooks:**
- Deploy Hooks (trigger deployments via HTTP POST)
- Project Webhooks (listen to project events)
- Deployment Events: `deployment.created`, `deployment.ready`, `deployment.error`
- Project Events: `project.created`, `project.removed`
- Firewall Events: `attack.detected`

**Webhook Security:**
- `x-vercel-signature` header verification
- Client secret comparison
- HMAC validation

---

## Common Operations

### Getting Started

**Installation:**
```bash
# Install Vercel CLI
pnpm add -g vercel

# Authenticate (development)
vercel login

# Token-based authentication (CI/CD)
vercel --token $VERCEL_TOKEN
```

**Project Initialization:**
```bash
# Link local project to Vercel
vercel link

# Initialize new project
vercel init
```

### Deployment Workflows

**Development:**
```bash
# Run local development server
vercel dev

# Specify port
vercel dev --listen 3001

# Pull environment variables for local development
vercel env pull .env.local
```

**Preview Deployment:**
```bash
# Deploy to preview environment
vercel

# Deploy specific directory
vercel ./dist
```

**Production Deployment:**
```bash
# Deploy to production
vercel --prod

# Deploy with build environment variables
vercel --build-env KEY=value --prod

# Deploy and skip confirmations
vercel --prod --yes
```

**Advanced Deployment:**
```bash
# Build locally
vercel build

# Deploy prebuilt output (no source code upload)
vercel deploy --prebuilt --prod

# Deploy and capture URL
URL=$(vercel deploy --yes)

# Promote deployment to production
vercel promote dpl_abc123

# Rollback to previous deployment
vercel rollback
```

### Environment Variable Management

**CLI Commands:**
```bash
# Pull development environment variables
vercel env pull .env.local

# Add environment variable (interactive)
vercel env add SECRET_KEY production

# Add environment variable (non-interactive)
echo "my-secret-value" | vercel env add SECRET_KEY production

# List all environment variables
vercel env ls

# Remove environment variable
vercel env rm SECRET_KEY production
```

**Best Practices:**
- Use `.env.local` for local development (never commit)
- Redeploy after adding new variables
- Set variables before build for static generation
- Use sensitive variables for API keys and secrets
- Organize by environment (prod/preview/dev)

### Domain Management

**Custom Domains:**
```bash
# List domains
vercel domains ls

# Add domain
vercel domains add example.com

# Remove domain
vercel domains rm example.com

# Inspect domain
vercel domains inspect example.com

# Verify domain
vercel domains verify example.com
```

**DNS Management:**
```bash
# List DNS records
vercel dns ls example.com

# Add DNS record
vercel dns add example.com A 76.76.21.21
vercel dns add example.com CNAME www example.com
vercel dns add example.com TXT "verification-token"

# Remove DNS record
vercel dns rm example.com rec_abc123
```

### Deployment Management

**List and Inspect:**
```bash
# List deployments
vercel list

# Inspect deployment
vercel inspect dpl_abc123

# View deployment logs
vercel logs dpl_abc123

# Stream deployment logs
vercel logs dpl_abc123 --follow
```

**Aliases:**
```bash
# Assign alias to deployment
vercel alias set dpl_abc123 example.com

# List aliases
vercel alias ls

# Remove alias
vercel alias rm example.com
```

**Rollback and Removal:**
```bash
# Rollback to previous deployment
vercel rollback

# Remove specific deployment
vercel remove dpl_abc123
```

### Team Management

**Team Operations:**
```bash
# List teams
vercel teams ls

# Switch team
vercel switch team-name

# Show current user/team
vercel whoami
```

### Certificates

**SSL Management:**
```bash
# List certificates
vercel certs ls

# Issue certificate
vercel certs issue example.com

# Remove certificate
vercel certs rm example.com
```

### Build and Cache

**Build Operations:**
```bash
# Build project locally
vercel build

# Pull build cache
vercel cache pull

# Clear build cache
vercel cache clear
```

### Blob Storage

**File Storage:**
```bash
# Upload blob
vercel blob put file.txt

# Download blob
vercel blob get file.txt

# List blobs
vercel blob ls
```

### Rolling Releases

**Gradual Rollout:**
```bash
# Create rolling release (10% traffic)
vercel rolling-release create --target dpl_new --percent 10

# Update rolling release (50% traffic)
vercel rolling-release update rrl_abc123 --percent 50

# Complete rolling release (100% traffic)
vercel rolling-release complete rrl_abc123
```

---

## CLI Commands

### Essential Commands

| Command | Description |
|---------|-------------|
| `vercel login` | Interactive login (development) |
| `vercel --token $TOKEN` | Token-based authentication (CI/CD) |
| `vercel link` | Link local project to Vercel |
| `vercel init` | Initialize new project |
| `vercel dev` | Run local development server |
| `vercel` | Deploy to preview |
| `vercel --prod` | Deploy to production |
| `vercel env pull` | Pull environment variables |
| `vercel env add` | Add environment variable |
| `vercel domains add` | Add custom domain |
| `vercel list` | List deployments |
| `vercel logs` | View deployment logs |
| `vercel rollback` | Rollback to previous deployment |

### Advanced Commands

| Command | Description |
|---------|-------------|
| `vercel build` | Build project locally |
| `vercel deploy --prebuilt` | Deploy prebuilt output |
| `vercel promote` | Promote deployment to production |
| `vercel inspect` | Inspect deployment details |
| `vercel alias set` | Assign alias to deployment |
| `vercel dns add` | Add DNS record |
| `vercel certs issue` | Issue SSL certificate |
| `vercel cache clear` | Clear build cache |
| `vercel blob put` | Upload blob storage |
| `vercel rolling-release` | Gradual deployment rollout |

### Global Options

| Option | Description |
|--------|-------------|
| `--token` | Authentication token |
| `--debug` | Debug mode |
| `--force` | Skip confirmation prompts |
| `--scope` | Team scope |
| `--yes` | Skip confirmations |
| `--build-env` | Build environment variables |

---

## API Integration

### REST API Overview

**Base URL:** `https://api.vercel.com`

**Authentication:**
```bash
Authorization: Bearer <YOUR_TOKEN>
```

**Content Type:** `application/json`

**Versioning:** Per-endpoint versioning (e.g., `/v6/deployments`, `/v10/projects`)

### Common API Operations

**List Projects:**
```bash
curl -H "Authorization: Bearer $VERCEL_TOKEN" \
  https://api.vercel.com/v10/projects
```

**Create Deployment:**
```bash
curl -X POST \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"my-project","target":"production"}' \
  https://api.vercel.com/v13/deployments
```

**Get Deployment:**
```bash
curl -H "Authorization: Bearer $VERCEL_TOKEN" \
  https://api.vercel.com/v13/deployments/dpl_abc123
```

**Add Environment Variable:**
```bash
curl -X POST \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"key":"API_KEY","value":"secret","type":"encrypted","target":["production"]}' \
  https://api.vercel.com/v10/projects/prj_abc123/env
```

**Add Custom Domain:**
```bash
curl -X POST \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"example.com"}' \
  https://api.vercel.com/v10/projects/prj_abc123/domains
```

**Verify Domain:**
```bash
curl -X POST \
  -H "Authorization: Bearer $VERCEL_TOKEN" \
  https://api.vercel.com/v10/projects/prj_abc123/domains/example.com/verify
```

### Pagination

**Default Limit:** 20 items
**Maximum Limit:** 100 items per request

**Pagination Object:**
```json
{
  "pagination": {
    "count": 20,
    "next": 1555072968396,
    "prev": 1555413045188
  }
}
```

**Pagination Example (TypeScript):**
```typescript
import axios from 'axios';

const VERCEL_TOKEN = process.env.VERCEL_TOKEN!;
const API_ENDPOINT = 'https://api.vercel.com/v10/projects';

async function fetchAllProjects() {
  const projects = [];
  let nextCursor = null;

  do {
    const url = nextCursor
      ? `${API_ENDPOINT}?until=${nextCursor}`
      : API_ENDPOINT;

    const response = await axios.get(url, {
      headers: { Authorization: `Bearer ${VERCEL_TOKEN}` }
    });

    projects.push(...response.data.projects);
    nextCursor = response.data.pagination.next;
  } while (nextCursor !== null);

  return projects;
}
```

### Rate Limits

**Rate Limit Headers:**
- `X-RateLimit-Limit` - Maximum requests allowed
- `X-RateLimit-Remaining` - Requests remaining
- `X-RateLimit-Reset` - UTC epoch reset time

**Rate Limit Exceeded:**
- Status: `429 Too Many Requests`

**Rate Limit Handling:**
```typescript
async function apiCallWithRetry(url: string, options: any, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      const response = await fetch(url, options);

      if (response.status === 429) {
        const resetTime = response.headers.get('X-RateLimit-Reset');
        const waitTime = resetTime
          ? parseInt(resetTime) * 1000 - Date.now()
          : 60000;

        await new Promise(resolve => setTimeout(resolve, waitTime));
        continue;
      }

      return response;
    } catch (error) {
      if (i === maxRetries - 1) throw error;
    }
  }
}
```

### Vercel SDK (TypeScript)

**Installation:**
```bash
pnpm add @vercel/sdk
```

**Basic Usage:**
```typescript
import { Vercel } from '@vercel/sdk';

const vercel = new Vercel({
  bearerToken: process.env.VERCEL_TOKEN,
});

// List projects
const projects = await vercel.projects.list();

// Create deployment
const deployment = await vercel.deployments.create({
  name: 'my-project',
  target: 'production',
  files: [
    {
      file: 'index.html',
      data: '<html>...</html>'
    }
  ]
});

// Get deployment status
const status = await vercel.deployments.get({
  idOrUrl: deployment.id
});

// Add environment variable
await vercel.projects.createEnvironmentVariable({
  projectId: 'prj_abc123',
  key: 'API_KEY',
  value: 'secret',
  type: 'encrypted',
  target: ['production']
});

// Add custom domain
await vercel.domains.create({
  projectId: 'prj_abc123',
  name: 'example.com'
});
```

---

## Best Practices

### 1. Function Optimization

**Serverless Function Best Practices:**

**Instance Reuse** - Store database connections outside handler:
```typescript
// ✅ Good - Connection reused across invocations
import { Pool } from 'pg';
const pool = new Pool();

export default async function handler(req, res) {
  const client = await pool.connect();
  // Use client...
  client.release();
}

// ❌ Bad - New connection every invocation
export default async function handler(req, res) {
  const pool = new Pool();
  const client = await pool.connect();
  // Use client...
}
```

**Cold Start Reduction:**
- Minimize dependencies
- Use lightweight packages
- Lazy load heavy modules
- Optimize bundle size

```bash
# Check dependency tree
pnpm ls

# Deduplicate dependencies
pnpm dedupe

# Analyze bundle size
npx @next/bundle-analyzer
```

**Region Configuration:**
- Deploy functions near data sources
- Use multiple regions for global apps
- Configure in project settings

**Fluid Compute:**
- Enable for I/O-bound workloads
- Perfect for AI/LLM calls
- Concurrent request handling
- Significant cost savings

### 2. Edge Function Best Practices

**When to Use Edge:**
- Authentication
- Redirects and rewrites
- Personalization
- A/B testing
- Bot protection

**Edge Limitations Workarounds:**
- No Node.js APIs → Use Web APIs
- No TCP/UDP → Use HTTP/Fetch
- 4MB limit → Keep functions small
- No heavy computation → Use Serverless

**Edge Middleware Pattern:**
```typescript
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const token = request.cookies.get('token');

  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Add custom headers
  const response = NextResponse.next();
  response.headers.set('x-custom-header', 'value');
  return response;
}

export const config = {
  matcher: '/dashboard/:path*',
};
```

### 3. Environment Variable Management

**Never Commit Secrets:**
```bash
# .gitignore
.env
.env.local
.env*.local
```

**Use Sensitive Variables:**
- For API keys and tokens
- Cannot be decrypted after creation
- Protected from accidental exposure

**Environment Separation:**
```typescript
const isDevelopment = process.env.NODE_ENV === 'development';
const apiUrl = isDevelopment
  ? process.env.DEV_API_URL
  : process.env.PROD_API_URL;
```

**Local Development Sync:**
```bash
# Pull latest environment variables
vercel env pull .env.local

# Use in development
vercel dev
```

**Redeploy After Changes:**
- Environment variables locked at build time
- Must redeploy for changes to take effect
- Use preview deployments to test

### 4. Domain and DNS Configuration

**Use Vercel Nameservers:**
- Automatic DNS management
- Wildcard SSL certificates
- Faster propagation
- Integrated domain management

**Domain Verification:**
```bash
# Verify domain ownership
vercel domains verify example.com

# Check domain status
vercel domains inspect example.com
```

**Wildcard Domains for Multi-Tenant:**
- Requires Vercel nameservers
- Individual certs per subdomain
- Automatic SSL renewal

**DNS Record TTL:**
- Use 60 seconds for active changes
- Increase to 300+ for stable configs

### 5. Deployment Strategies

**Preview Deployments:**
- Every git push creates preview URL
- Test changes before production
- Share with stakeholders
- Run integration tests

**Production Deployments:**
```bash
# Standard production deploy
vercel --prod

# With confirmation
vercel --prod --yes

# With custom alias
vercel --prod && vercel alias example.com
```

**Rolling Releases:**
```bash
# Gradual rollout
vercel rolling-release create --target dpl_new --percent 10

# Monitor metrics, then increase
vercel rolling-release update rrl_abc123 --percent 50

# Complete rollout
vercel rolling-release complete rrl_abc123

# Rollback if issues
vercel rollback
```

**Blue-Green Deployments:**
```typescript
import { Vercel } from '@vercel/sdk';

const vercel = new Vercel({ bearerToken: process.env.VERCEL_TOKEN });

// Deploy new version
const deployment = await vercel.deployments.create({
  name: 'my-project',
  target: 'production'
});

// Wait for ready state
await waitForDeployment(deployment.id);

// Run smoke tests
await runSmokeTests(deployment.url);

// Swap production alias
await vercel.aliases.assign({
  alias: 'example.com',
  deploymentId: deployment.id
});
```

### 6. Observability Patterns

**Structured Logging:**
```typescript
export default function handler(req, res) {
  console.log(JSON.stringify({
    level: 'info',
    message: 'Request received',
    method: req.method,
    path: req.url,
    timestamp: new Date().toISOString()
  }));

  // Handle request...
}
```

**Error Tracking:**
```typescript
export default async function handler(req, res) {
  try {
    // Handle request...
  } catch (error) {
    console.error(JSON.stringify({
      level: 'error',
      message: error.message,
      stack: error.stack,
      timestamp: new Date().toISOString()
    }));

    res.status(500).json({ error: 'Internal Server Error' });
  }
}
```

**Performance Monitoring:**
```typescript
export default async function handler(req, res) {
  const start = Date.now();

  // Handle request...

  const duration = Date.now() - start;
  console.log(JSON.stringify({
    level: 'info',
    message: 'Request completed',
    duration,
    timestamp: new Date().toISOString()
  }));
}
```

**Drains Configuration:**
```bash
# Export logs to Datadog
vercel drains add datadog --token $DATADOG_TOKEN

# Export to custom endpoint
vercel drains add webhook --url https://logs.example.com/ingest
```

### 7. Security Best Practices

**Firewall Configuration:**
```bash
# Enable WAF
vercel firewall enable

# Add rate limiting
vercel firewall rate-limit --limit 100 --window 60

# Configure bypass rules
vercel firewall bypass add --ip 203.0.113.0/24
```

**Edge Authentication:**
```typescript
import { jwtVerify } from 'jose';

export async function middleware(request) {
  const token = request.cookies.get('token');

  try {
    await jwtVerify(token, new TextEncoder().encode(secret));
    return NextResponse.next();
  } catch {
    return new Response('Unauthorized', { status: 401 });
  }
}
```

**Security Headers:**
```typescript
export function middleware(request) {
  const response = NextResponse.next();

  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('Permissions-Policy', 'geolocation=(), microphone=()');

  return response;
}
```

**Sensitive Data Protection:**
- Use sensitive environment variables
- Enable secret redaction in logs
- Implement request validation
- Sanitize user inputs
- Use HTTPS only

### 8. Cost Optimization

**Reduce Function Costs:**
1. Enable Fluid Compute for concurrency
2. Optimize function memory allocation
3. Implement response caching
4. Use Edge Functions where possible
5. Monitor and optimize cold starts

**Reduce Bandwidth Costs:**
1. Enable caching headers
2. Optimize image delivery
3. Use CDN effectively
4. Compress responses
5. Implement stale-while-revalidate

**Monitor Usage:**
```bash
# Check project usage
vercel usage

# View detailed metrics
vercel metrics dpl_abc123
```

**Set Spending Limits:**
- Configure on-demand budget
- Set up usage alerts
- Enable project pause at limits
- Monitor overage notifications

---

## Troubleshooting

### Common Issues and Solutions

**1. Build Failures**

**Issue:** Build times out or fails
```bash
# Check build logs
vercel logs dpl_abc123

# Inspect deployment
vercel inspect dpl_abc123
```

**Solutions:**
- Optimize dependencies
- Use build caching
- Reduce build complexity
- Check memory limits

**2. Environment Variable Not Found**

**Issue:** `process.env.VAR_NAME` is undefined

**Solutions:**
- Verify variable is set in dashboard
- Check environment type (production/preview/development)
- Redeploy after adding variables
- Pull variables locally: `vercel env pull .env.local`

**3. Domain Verification Failed**

**Issue:** Custom domain not verified

**Solutions:**
```bash
# Check domain status
vercel domains inspect example.com

# Verify domain
vercel domains verify example.com

# Check DNS records
vercel dns ls example.com
```

- Add TXT verification record
- Use Vercel nameservers
- Wait for DNS propagation (up to 48 hours)

**4. Function Timeout**

**Issue:** Serverless function exceeds timeout

**Solutions:**
- Optimize function logic
- Use async/await properly
- Implement connection pooling
- Increase timeout in project settings (Pro plan)
- Break into smaller functions

**5. Cold Start Performance**

**Issue:** Slow first request after idle period

**Solutions:**
- Minimize dependencies
- Use lightweight packages
- Implement connection pooling
- Use Edge Functions for latency-sensitive operations
- Enable Fluid Compute

**6. Rate Limit Exceeded**

**Issue:** API returns 429 status code

**Solutions:**
```typescript
// Implement retry with exponential backoff
async function apiCallWithRetry(url, options, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    const response = await fetch(url, options);

    if (response.status === 429) {
      const resetTime = response.headers.get('X-RateLimit-Reset');
      const waitTime = resetTime
        ? parseInt(resetTime) * 1000 - Date.now()
        : 60000;

      await new Promise(resolve => setTimeout(resolve, waitTime));
      continue;
    }

    return response;
  }
}
```

**7. SSL Certificate Issues**

**Issue:** SSL certificate not issued or expired

**Solutions:**
```bash
# List certificates
vercel certs ls

# Issue new certificate
vercel certs issue example.com

# Remove old certificate
vercel certs rm example.com
```

- Verify domain ownership
- Check nameserver configuration
- Wait for automatic renewal
- Contact support for enterprise domains

**8. Preview Deployment Not Created**

**Issue:** Git push doesn't create preview deployment

**Solutions:**
- Check git integration in dashboard
- Verify branch is not ignored
- Check deployment logs
- Ensure build command succeeds
- Verify framework detection

**9. Edge Function Limitations**

**Issue:** Node.js APIs not available in Edge Functions

**Solutions:**
- Use Web APIs instead of Node.js APIs
- Move heavy computation to Serverless Functions
- Use HTTP fetch instead of TCP/UDP
- Keep function size under 4MB
- Use middleware for simple operations

**10. Team Access Issues**

**Issue:** Team member cannot access resources

**Solutions:**
```bash
# Check team membership
vercel teams ls

# Verify user role
# (via dashboard: Team Settings → Members)
```

- Verify role permissions
- Check project-level access
- Use team-scoped tokens
- Review RBAC configuration

---

## Examples

### 1. Basic Next.js Deployment

**Deploy Next.js application:**
```bash
# Initialize project
npx create-next-app@latest my-app
cd my-app

# Link to Vercel
vercel link

# Deploy to preview
vercel

# Deploy to production
vercel --prod
```

**vercel.json configuration:**
```json
{
  "buildCommand": "pnpm build",
  "devCommand": "pnpm dev",
  "installCommand": "pnpm install",
  "framework": "nextjs"
}
```

### 2. Serverless API Function

**Create API endpoint:**
```typescript
// api/hello.ts
import type { VercelRequest, VercelResponse } from '@vercel/node';

export default function handler(req: VercelRequest, res: VercelResponse) {
  const { name = 'World' } = req.query;
  res.status(200).json({ message: `Hello, ${name}!` });
}
```

**Database connection with pooling:**
```typescript
// api/users.ts
import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
});

export default async function handler(req, res) {
  const client = await pool.connect();

  try {
    const { rows } = await client.query('SELECT * FROM users');
    res.status(200).json(rows);
  } finally {
    client.release();
  }
}
```

### 3. Edge Middleware Authentication

**JWT authentication middleware:**
```typescript
// middleware.ts
import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

export async function middleware(request: NextRequest) {
  const token = request.cookies.get('user-token');

  if (!token) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  try {
    const secret = new TextEncoder().encode(process.env.JWT_SECRET);
    await jwtVerify(token.value, secret);
    return NextResponse.next();
  } catch {
    return NextResponse.redirect(new URL('/login', request.url));
  }
}

export const config = {
  matcher: '/protected/:path*',
};
```

### 4. CI/CD with GitHub Actions

**Deploy on push:**
```yaml
# .github/workflows/deploy.yml
name: Vercel Deployment
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Vercel CLI
        run: pnpm add -g vercel

      - name: Pull Vercel Environment
        run: vercel pull --yes --environment=production --token=${{ secrets.VERCEL_TOKEN }}

      - name: Build Project
        run: vercel build --prod --token=${{ secrets.VERCEL_TOKEN }}

      - name: Deploy to Vercel
        run: vercel deploy --prebuilt --prod --token=${{ secrets.VERCEL_TOKEN }}
```

### 5. Multi-Tenant Domain Management

**Programmatic tenant onboarding:**
```typescript
import { Vercel } from '@vercel/sdk';

const vercel = new Vercel({ bearerToken: process.env.VERCEL_TOKEN });

async function onboardTenant(tenantId: string, domain: string) {
  // Create tenant project
  const project = await vercel.projects.create({
    name: `tenant-${tenantId}`,
    framework: 'nextjs',
    environmentVariables: [
      {
        key: 'TENANT_ID',
        value: tenantId,
        target: ['production', 'preview']
      }
    ]
  });

  // Add custom domain
  await vercel.domains.create({
    projectId: project.id,
    name: domain
  });

  // Verify domain
  const verification = await vercel.domains.verify({
    projectId: project.id,
    domain
  });

  return { project, domain, verification };
}
```

### 6. Vercel AI SDK Integration

**Streaming chat with AI SDK:**
```typescript
// app/api/chat/route.ts
import { streamText } from 'ai';
import { openai } from '@ai-sdk/openai';

export async function POST(req: Request) {
  const { messages } = await req.json();

  const result = streamText({
    model: openai('gpt-4o'),
    messages,
    system: 'You are a helpful assistant.',
  });

  return result.toDataStreamResponse();
}
```

**Client-side chat component:**
```typescript
// app/chat/page.tsx
'use client';
import { useChat } from '@ai-sdk/react';

export default function ChatPage() {
  const { messages, input, handleSubmit, handleInputChange, isLoading } = useChat();

  return (
    <div>
      {messages.map(message => (
        <div key={message.id}>
          <strong>{message.role}:</strong> {message.content}
        </div>
      ))}

      <form onSubmit={handleSubmit}>
        <input
          value={input}
          onChange={handleInputChange}
          disabled={isLoading}
          placeholder="Type your message..."
        />
        <button type="submit" disabled={isLoading}>Send</button>
      </form>
    </div>
  );
}
```

### 7. Database Integration

**Vercel Postgres:**
```typescript
import { sql } from '@vercel/postgres';

export default async function handler(req, res) {
  const { rows } = await sql`SELECT * FROM users WHERE id = ${req.query.id}`;
  res.json(rows[0]);
}
```

**Vercel KV (Redis):**
```typescript
import { kv } from '@vercel/kv';

export default async function handler(req, res) {
  const value = await kv.get('key');

  if (!value) {
    await kv.set('key', 'value', { ex: 3600 }); // 1 hour expiry
  }

  res.json({ value });
}
```

**Vercel Blob (Object Storage):**
```typescript
import { put, list, del } from '@vercel/blob';

export default async function handler(req, res) {
  // Upload file
  const blob = await put('file.txt', 'Hello, World!', {
    access: 'public',
  });

  // List files
  const { blobs } = await list();

  // Delete file
  await del(blob.url);

  res.json({ url: blob.url });
}
```

### 8. Custom Workflow Automation

**Deploy and test workflow:**
```bash
#!/bin/bash

# Deploy to preview
URL=$(vercel deploy --yes)

# Run tests against preview
pnpm test -- --url=$URL

# If tests pass, promote to production
if [ $? -eq 0 ]; then
  vercel promote $URL
  echo "Deployed to production: $URL"
else
  echo "Tests failed, deployment not promoted"
  exit 1
fi
```

### 9. Observability with Drains

**Export logs to Datadog:**
```bash
# Add Datadog drain
vercel drains add datadog --token $DATADOG_TOKEN --project my-project
```

**Custom webhook drain:**
```bash
# Add custom webhook
vercel drains add webhook \
  --url https://logs.example.com/ingest \
  --project my-project
```

### 10. Performance Optimization

**Caching headers:**
```json
{
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "s-maxage=60, stale-while-revalidate"
        }
      ]
    }
  ]
}
```

**Function configuration:**
```json
{
  "functions": {
    "api/expensive-function.ts": {
      "memory": 3008,
      "maxDuration": 60
    }
  }
}
```

---

## 2025 Innovations

### 1. Unified Runtime

**Combined Edge Middleware and Functions:**
- Single runtime for edge computing
- Simplified architecture
- Better performance
- Reduced complexity

### 2. Vercel for Platforms

**Multi-Tenant and Multi-Project Deployment:**
- Create customer projects via API
- Two modes: Multi-Tenant, Multi-Project
- Automated domain verification
- Per-tenant SSL certificates

### 3. Vercel Drains

**OpenTelemetry Export:**
- Stream observability data to external systems
- Supported data types: traces, analytics, logs
- Integration with major observability platforms
- Pricing: $0.50 per GB

### 4. Domain Connect

**One-Click DNS Configuration:**
- Automated DNS setup
- Faster domain onboarding
- Improved user experience
- Reduced configuration errors

### 5. Active CPU Pricing

**Pay for Execution Time:**
- Active CPU usage charges
- Provisioned memory at 1/11th rate
- Cost savings with Fluid Compute
- More predictable pricing

### 6. Fluid Compute

**Concurrent Request Handling:**
- Multiple requests per instance
- Significant cost savings
- Perfect for I/O-bound workloads
- Ideal for AI/LLM applications

---

## Limitations

### Function Limitations

**Serverless Functions:**
- Maximum uncompressed size: 250 MB
- Timeout: 10 seconds (Hobby), 300 seconds (Pro)
- No persistent storage between invocations
- No WebSocket support

**Edge Functions:**
- Maximum function size: 4 MB (including bundled code)
- Maximum request size: 1 MB
- Maximum response size: 4 MB
- No native Node.js APIs
- No TCP/UDP connections
- No file system access

### Build Limitations

- Maximum build time: 45 minutes
- Build container resources (Pro): 8192 MB memory, 23 GB disk, 4 CPUs
- No persistent build state

### Environment Variables

- Total size per deployment: 64 KB
- Edge Functions/Middleware: 5 KB per variable
- Changes require redeployment

### Domain and DNS

- DNS record propagation: Minutes to hours
- Wildcard domains require Vercel nameservers

---

## References

- [Vercel Documentation](https://vercel.com/docs)
- [Vercel CLI](https://vercel.com/docs/cli)
- [Vercel REST API](https://vercel.com/docs/rest-api)
- [Vercel Functions](https://vercel.com/docs/functions)
- [Edge Middleware](https://vercel.com/docs/functions/edge-middleware)
- [Vercel AI SDK](https://ai-sdk.dev/docs/introduction)
- [Environment Variables](https://vercel.com/docs/environment-variables)
- [Domain Management](https://vercel.com/docs/domains)
- [Vercel Observability](https://vercel.com/products/observability)
- [Vercel for Platforms](https://vercel.com/changelog/introducing-vercel-for-platforms)

---

**Skill Version:** 2.0.0
**Last Updated:** 2025-12-09
**Maintained By:** Infrastructure Team
