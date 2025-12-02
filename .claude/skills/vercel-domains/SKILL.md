# Vercel Domains Skill

Manage custom domains, DNS configuration, and SSL certificates for Vercel deployments.

## When to Use

Use this skill when:
- Adding custom domains to projects
- Configuring DNS records
- Managing SSL/TLS certificates
- Setting up domain redirects
- Configuring wildcard domains

## Prerequisites

Required environment variables:
- `VERCEL_TOKEN` - Vercel access token

## Vercel CLI Commands

### Domain Management

```bash
# List all domains
vercel domains ls

# Add domain to account
vercel domains add example.com

# Add domain to specific project
vercel domains add example.com --project my-project

# Remove domain
vercel domains rm example.com

# Inspect domain configuration
vercel domains inspect example.com

# Transfer domain to another team
vercel domains transfer example.com --to other-team

# Buy domain (if available)
vercel domains buy example.com
```

### DNS Configuration

```bash
# List DNS records
vercel dns ls example.com

# Add DNS record
vercel dns add example.com @ A 76.76.21.21
vercel dns add example.com www CNAME cname.vercel-dns.com
vercel dns add example.com @ MX 10 mail.example.com

# Add TXT record (for verification)
vercel dns add example.com @ TXT "v=spf1 include:_spf.example.com ~all"

# Remove DNS record
vercel dns rm <record-id>
```

### Certificate Management

```bash
# List certificates
vercel certs ls

# Issue certificate
vercel certs issue example.com

# Remove certificate
vercel certs rm example.com
```

## Adding Custom Domain

### Step 1: Add Domain to Project

```bash
# Link project first
vercel link

# Add domain
vercel domains add aienablement.academy
```

### Step 2: Configure DNS

**Option A: Vercel Nameservers (Recommended)**

Point your domain's nameservers to Vercel:
```
ns1.vercel-dns.com
ns2.vercel-dns.com
```

**Option B: External DNS**

Add these records at your DNS provider:

```dns
# Root domain (A record)
@ A 76.76.21.21

# www subdomain (CNAME)
www CNAME cname.vercel-dns.com
```

### Step 3: Verify & SSL

Vercel automatically:
1. Verifies domain ownership
2. Issues Let's Encrypt SSL certificate
3. Enables HTTPS

## Vercel SDK Usage

```typescript
import { Vercel } from "@vercel/sdk";

const vercel = new Vercel({ bearerToken: process.env.VERCEL_TOKEN });

// List domains
async function listDomains() {
  const response = await vercel.domains.getDomains({});
  return response.domains;
}

// Add domain to project
async function addDomain(projectId: string, domain: string) {
  return await vercel.projects.addProjectDomain({
    idOrName: projectId,
    requestBody: { name: domain }
  });
}

// Get domain configuration
async function getDomainConfig(domain: string) {
  return await vercel.domains.getDomain({ domain });
}

// Verify domain
async function verifyDomain(projectId: string, domain: string) {
  return await vercel.projects.verifyProjectDomain({
    idOrName: projectId,
    domain
  });
}

// Remove domain from project
async function removeDomain(projectId: string, domain: string) {
  return await vercel.projects.removeProjectDomain({
    idOrName: projectId,
    domain
  });
}
```

## REST API

```bash
# List domains
GET /v5/domains

# Add domain
POST /v5/domains
{
  "name": "example.com"
}

# Get domain info
GET /v5/domains/{domain}

# Add domain to project
POST /v9/projects/{projectId}/domains
{
  "name": "example.com"
}

# Verify domain
POST /v9/projects/{projectId}/domains/{domain}/verify

# Get domain configuration
GET /v6/domains/{domain}/config

# List DNS records
GET /v4/domains/{domain}/records

# Add DNS record
POST /v2/domains/{domain}/records
{
  "name": "@",
  "type": "A",
  "value": "76.76.21.21"
}
```

## Domain Configuration Patterns

### Production + Preview Domains

```json
// vercel.json
{
  "alias": ["aienablement.academy", "www.aienablement.academy"]
}
```

### Redirect www to apex

```json
// vercel.json
{
  "redirects": [
    {
      "source": "/:path*",
      "has": [{ "type": "host", "value": "www.aienablement.academy" }],
      "destination": "https://aienablement.academy/:path*",
      "permanent": true
    }
  ]
}
```

### Redirect apex to www

```json
{
  "redirects": [
    {
      "source": "/:path*",
      "has": [{ "type": "host", "value": "aienablement.academy" }],
      "destination": "https://www.aienablement.academy/:path*",
      "permanent": true
    }
  ]
}
```

### Multiple Domains

```json
{
  "alias": [
    "aienablement.academy",
    "www.aienablement.academy",
    "app.aienablement.academy"
  ]
}
```

## Wildcard Domains

```bash
# Add wildcard domain
vercel domains add "*.aienablement.academy"

# Configure DNS
vercel dns add aienablement.academy "*" CNAME cname.vercel-dns.com
```

### Using Wildcards

```typescript
// middleware.ts
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
  const hostname = request.headers.get('host') || '';
  const subdomain = hostname.split('.')[0];

  if (subdomain !== 'www' && subdomain !== 'aienablement') {
    // Rewrite to tenant-specific page
    return NextResponse.rewrite(
      new URL(`/tenants/${subdomain}${request.nextUrl.pathname}`, request.url)
    );
  }
}

export const config = {
  matcher: ['/((?!api|_next/static|_next/image|favicon.ico).*)']
};
```

## SSL/TLS Configuration

### Automatic SSL (Default)

Vercel automatically provisions SSL certificates:
- Let's Encrypt certificates
- Auto-renewal
- HTTP/2 and HTTP/3 support
- HTTPS redirect enabled by default

### Force HTTPS

```json
// vercel.json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Strict-Transport-Security",
          "value": "max-age=31536000; includeSubDomains"
        }
      ]
    }
  ]
}
```

## Domain Verification

### Methods

1. **DNS TXT Record** (Most common)
```bash
vercel domains add example.com
# Follow instructions to add TXT record
```

2. **CNAME Record**
```bash
# Add CNAME record pointing to cname.vercel-dns.com
```

3. **Nameserver Transfer**
```bash
# Point nameservers to Vercel
ns1.vercel-dns.com
ns2.vercel-dns.com
```

### Check Verification Status

```bash
vercel domains inspect example.com
```

## Cloudflare Integration

If using Cloudflare as DNS provider:

### DNS Records

```
Type: A
Name: @
Content: 76.76.21.21
Proxy: DNS only (gray cloud) ⚠️

Type: CNAME
Name: www
Content: cname.vercel-dns.com
Proxy: DNS only (gray cloud) ⚠️
```

**Important**: Disable Cloudflare proxy (orange cloud) to let Vercel handle SSL.

### SSL Configuration

1. In Cloudflare: Set SSL mode to "Full (strict)"
2. Vercel handles edge SSL termination
3. Cloudflare provides additional DDoS protection

## Best Practices

### 1. Use Apex Domain as Primary
- `aienablement.academy` → Primary
- `www.aienablement.academy` → Redirects to apex

### 2. Enable HSTS
```json
{
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "Strict-Transport-Security",
          "value": "max-age=31536000; includeSubDomains; preload"
        }
      ]
    }
  ]
}
```

### 3. Configure Canonical URLs
```typescript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'Link',
            value: '<https://aienablement.academy/:path*>; rel="canonical"'
          }
        ]
      }
    ];
  }
};
```

## Troubleshooting

### Domain Not Verifying
- Check DNS propagation: `dig example.com +short`
- Ensure TXT record is at root (@)
- Wait up to 48 hours for DNS propagation

### SSL Certificate Not Issuing
- Verify DNS is pointing to Vercel
- Disable proxy if using Cloudflare
- Check domain verification status

### Mixed Content Warnings
- Ensure all resources use HTTPS
- Update hardcoded HTTP URLs
- Use protocol-relative URLs: `//example.com/resource`

## Sources
- [Vercel Domains Documentation](https://vercel.com/docs/projects/domains)
- [Adding Custom Domains](https://vercel.com/docs/projects/domains/add-a-domain)
- [DNS Configuration](https://vercel.com/docs/projects/domains/dns)
- [SSL Certificates](https://vercel.com/docs/security/ssl)
