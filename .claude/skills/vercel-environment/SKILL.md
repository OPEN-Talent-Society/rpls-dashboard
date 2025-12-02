# Vercel Environment Variables Skill

Manage environment variables across Development, Preview, and Production environments in Vercel.

## When to Use

Use this skill when:
- Adding or updating environment variables
- Syncing env vars between Vercel and local development
- Managing secrets for different environments
- Configuring framework-specific variables
- Setting up CI/CD environment configuration

## Prerequisites

Required environment variables:
- `VERCEL_TOKEN` - Vercel access token

## Vercel CLI Commands

### Pull Environment Variables

```bash
# Pull all env vars to .env.local
vercel env pull

# Pull to specific file
vercel env pull .env.development.local

# Pull from specific environment
vercel env pull --environment=production

# Pull specific project
vercel env pull --project=my-project
```

### Add Environment Variables

```bash
# Interactive add
vercel env add

# Add with specific name and value
vercel env add MY_VAR

# Add for specific environment
vercel env add MY_VAR production

# Add for multiple environments
vercel env add MY_VAR production preview development

# Add sensitive value (reads from stdin)
echo "secret-value" | vercel env add SECRET_KEY production

# Add from file
cat .env.production | while read line; do
  key=$(echo "$line" | cut -d'=' -f1)
  value=$(echo "$line" | cut -d'=' -f2-)
  vercel env add "$key" production <<< "$value"
done
```

### List Environment Variables

```bash
# List all env vars
vercel env ls

# List for specific environment
vercel env ls production

# List with decrypted values (requires confirmation)
vercel env ls --decrypt
```

### Remove Environment Variables

```bash
# Interactive remove
vercel env rm MY_VAR

# Remove from specific environment
vercel env rm MY_VAR production

# Remove from all environments
vercel env rm MY_VAR production preview development
```

## Environment Types

### 1. Development
- Used during `vercel dev`
- Typically for local API keys and debug settings
- Not deployed to any URL

### 2. Preview
- Used in preview deployments (PR branches)
- Good for staging configurations
- Each preview has isolated environment

### 3. Production
- Used in production deployments
- Only applies to production branch
- Most restrictive access

## Vercel SDK Usage

```typescript
import { Vercel } from "@vercel/sdk";

const vercel = new Vercel({ bearerToken: process.env.VERCEL_TOKEN });

// List environment variables
async function listEnvVars(projectId: string) {
  const response = await vercel.projects.getProjectEnvs({
    idOrName: projectId
  });
  return response.envs;
}

// Add environment variable
async function addEnvVar(
  projectId: string,
  key: string,
  value: string,
  target: ("production" | "preview" | "development")[]
) {
  return await vercel.projects.createProjectEnv({
    idOrName: projectId,
    requestBody: {
      key,
      value,
      type: "encrypted", // or "plain", "secret"
      target
    }
  });
}

// Update environment variable
async function updateEnvVar(projectId: string, envId: string, value: string) {
  return await vercel.projects.editProjectEnv({
    idOrName: projectId,
    id: envId,
    requestBody: { value }
  });
}

// Delete environment variable
async function deleteEnvVar(projectId: string, envId: string) {
  return await vercel.projects.removeProjectEnv({
    idOrName: projectId,
    id: envId
  });
}
```

## REST API

```bash
# List environment variables
GET /v9/projects/{projectId}/env

# Create environment variable
POST /v10/projects/{projectId}/env
{
  "key": "DATABASE_URL",
  "value": "postgres://...",
  "type": "encrypted",
  "target": ["production", "preview"]
}

# Update environment variable
PATCH /v9/projects/{projectId}/env/{envId}
{
  "value": "new-value"
}

# Delete environment variable
DELETE /v9/projects/{projectId}/env/{envId}
```

## Framework-Specific Variables

### Next.js

```bash
# Public variables (exposed to browser)
NEXT_PUBLIC_APP_URL=https://example.com
NEXT_PUBLIC_API_URL=https://api.example.com

# Server-only variables
DATABASE_URL=postgres://...
NEXTAUTH_SECRET=xxx
NEXTAUTH_URL=https://example.com
```

### Payload CMS + Next.js

```bash
# Database
DATABASE_URL=postgres://...
PAYLOAD_SECRET=xxx

# Auth
NEXTAUTH_SECRET=xxx
NEXTAUTH_URL=${VERCEL_URL}

# Public URLs
NEXT_PUBLIC_APP_URL=${VERCEL_URL}
NEXT_PUBLIC_SERVER_URL=${VERCEL_URL}
```

## System Environment Variables

Vercel provides automatic system variables:

| Variable | Description |
|----------|-------------|
| `VERCEL` | Always "1" when running on Vercel |
| `VERCEL_ENV` | "production", "preview", or "development" |
| `VERCEL_URL` | Deployment URL (without protocol) |
| `VERCEL_BRANCH_URL` | Branch-specific URL |
| `VERCEL_PROJECT_PRODUCTION_URL` | Production domain |
| `VERCEL_GIT_COMMIT_SHA` | Git commit SHA |
| `VERCEL_GIT_COMMIT_MESSAGE` | Git commit message |
| `VERCEL_GIT_REPO_SLUG` | Repository slug |
| `VERCEL_GIT_REPO_OWNER` | Repository owner |
| `VERCEL_GIT_COMMIT_REF` | Git branch name |

### Using System Variables

```typescript
// next.config.js
module.exports = {
  env: {
    APP_URL: process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'http://localhost:3000'
  }
}
```

## Environment Variable Patterns

### Dynamic URL Configuration

```bash
# Use Vercel's automatic URL
NEXTAUTH_URL=${VERCEL_URL:+https://$VERCEL_URL}
NEXT_PUBLIC_APP_URL=${VERCEL_PROJECT_PRODUCTION_URL:+https://$VERCEL_PROJECT_PRODUCTION_URL}
```

### Conditional Per Environment

```bash
# Development
DATABASE_URL=postgres://localhost:5432/dev

# Preview
DATABASE_URL=postgres://staging-db.example.com/preview

# Production
DATABASE_URL=postgres://prod-db.example.com/production
```

## Best Practices

### 1. Use Encrypted Variables
```bash
# Sensitive data should use "encrypted" type
vercel env add DATABASE_URL production
# Type: encrypted (default for secrets)
```

### 2. Never Commit .env Files
```gitignore
# .gitignore
.env
.env.local
.env.*.local
```

### 3. Use .env.example for Documentation
```bash
# .env.example (committed to git)
DATABASE_URL=postgres://user:pass@host:5432/db
NEXTAUTH_SECRET=generate-with-openssl-rand-base64-32
NEXTAUTH_URL=https://your-domain.com
```

### 4. Environment-Specific Defaults
```typescript
// lib/config.ts
export const config = {
  appUrl: process.env.NEXT_PUBLIC_APP_URL
    || (process.env.VERCEL_URL ? `https://${process.env.VERCEL_URL}` : 'http://localhost:3000'),
  isDev: process.env.NODE_ENV === 'development',
  isProd: process.env.VERCEL_ENV === 'production'
};
```

## Migration from DigitalOcean

### Mapping DO App Spec to Vercel

| DigitalOcean (app-spec.yaml) | Vercel |
|------------------------------|--------|
| `envs[].value` | Plain env var |
| `envs[].type: SECRET` | Encrypted env var |
| `envs[].scope: RUN_TIME` | Server-side only |
| `envs[].scope: BUILD_TIME` | Available at build |
| `envs[].scope: RUN_AND_BUILD_TIME` | Both (default in Vercel) |

### Migration Script

```bash
#!/bin/bash
# migrate-env-to-vercel.sh

# Required env vars from DigitalOcean
VARS=(
  "DATABASE_URL"
  "NEXTAUTH_SECRET"
  "AUTH_SECRET"
  "PAYLOAD_SECRET"
  "BREVO_API_KEY"
)

for var in "${VARS[@]}"; do
  echo "Adding $var to Vercel..."
  vercel env add "$var" production preview
done
```

## Troubleshooting

### Variable Not Available at Build
- Check `target` includes the correct environment
- Verify variable name doesn't have typos
- Ensure redeployment after adding vars

### Variable Shows as [hidden]
- This is expected for encrypted variables
- Use `vercel env ls --decrypt` to see values

### NEXT_PUBLIC_ Not Working
- Must start with `NEXT_PUBLIC_` exactly
- Must redeploy after adding
- Check it's set for the correct environment

## Sources
- [Vercel Environment Variables](https://vercel.com/docs/projects/environment-variables)
- [System Environment Variables](https://vercel.com/docs/projects/environment-variables/system-environment-variables)
- [Framework Environment Variables](https://vercel.com/docs/projects/environment-variables/framework-environment-variables)
