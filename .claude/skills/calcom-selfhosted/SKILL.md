---
name: "Cal.com Self-Hosted"
description: "Deploy and troubleshoot Cal.com self-hosted instances. Use when deploying Cal.com, fixing configuration errors, or managing calendar booking systems on OCI/Docker."
---

# Cal.com Self-Hosted Operations

## What This Skill Does

Manage Cal.com self-hosted deployments:
1. Docker Compose configuration
2. Environment variable troubleshooting
3. Database operations
4. SSL/DNS integration with Caddy

## Quick Reference

### Server Location
- **Host**: 163.192.41.116 (OCI Docker host)
- **Directory**: /srv/calcom
- **Container**: calcom-app
- **Database**: calcom-db (PostgreSQL 15)
- **URL**: https://calendar.aienablement.academy

### SSH Access
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116
cd /srv/calcom
```

---

## CRITICAL: Environment Variables

### ALLOWED_HOSTNAMES (JSON Array Required)
```yaml
# CORRECT - JSON array in single quotes
ALLOWED_HOSTNAMES: '["calendar.aienablement.academy"]'
NEXT_PUBLIC_ALLOWED_HOSTNAMES: '["calendar.aienablement.academy"]'

# WRONG - Plain string causes JSON parse error
ALLOWED_HOSTNAMES: calendar.aienablement.academy
```

### Stripe Keys (Required Even Self-Hosted)
```yaml
# Use placeholder values to prevent API errors
STRIPE_PRIVATE_KEY: sk_test_placeholder_not_real
STRIPE_WEBHOOK_SECRET: whsec_placeholder_not_real
```

### Encryption Key (Exactly 32 Hex Chars)
```yaml
# CORRECT - 32 characters
CALENDSO_ENCRYPTION_KEY: 0123456789abcdef0123456789abcdef

# WRONG - Will cause "Invalid key length" error
CALENDSO_ENCRYPTION_KEY: too-short
```

### Self-Hosted Flags
```yaml
NEXT_PUBLIC_IS_SELF_HOSTED: "true"
CALCOM_TELEMETRY_DISABLED: "1"
```

---

## Complete docker-compose.yml Template

```yaml
services:
  calcom-app:
    image: calcom/cal.com:latest
    container_name: calcom-app
    environment:
      # Database
      DATABASE_URL: postgresql://calcom:PASSWORD@calcom-db:5432/calcom
      DATABASE_DIRECT_URL: postgresql://calcom:PASSWORD@calcom-db:5432/calcom
      REDIS_URL: redis://calcom-redis:6379

      # Auth
      NEXTAUTH_SECRET: <generate-32-char-secret>
      NEXTAUTH_URL: https://calendar.aienablement.academy
      NEXT_PUBLIC_WEBAPP_URL: https://calendar.aienablement.academy
      NEXT_PUBLIC_LICENSE_CONSENT: agree

      # CRITICAL: Must be JSON array
      ALLOWED_HOSTNAMES: '["calendar.aienablement.academy"]'
      NEXT_PUBLIC_ALLOWED_HOSTNAMES: '["calendar.aienablement.academy"]'

      # CRITICAL: Must be exactly 32 hex chars
      CALENDSO_ENCRYPTION_KEY: 0123456789abcdef0123456789abcdef

      # CRITICAL: Required even with placeholders
      STRIPE_PRIVATE_KEY: sk_test_placeholder_not_real
      STRIPE_WEBHOOK_SECRET: whsec_placeholder_not_real

      # Self-hosted flags
      NEXT_PUBLIC_IS_SELF_HOSTED: "true"
      CALCOM_TELEMETRY_DISABLED: "1"

      # Email (Brevo SMTP)
      EMAIL_FROM: calendar@aienablement.academy
      EMAIL_SERVER_HOST: smtp-relay.brevo.com
      EMAIL_SERVER_PORT: "587"
      EMAIL_SERVER_USER: <brevo-user>
      EMAIL_SERVER_PASSWORD: <brevo-password>
```

---

## Common Operations

### View Logs
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "docker logs --tail 50 calcom-app"
```

### Restart Container
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "cd /srv/calcom && docker compose restart calcom-app"
```

### Check Environment Variables
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "docker exec calcom-app printenv | grep -E '(ALLOWED|STRIPE|NEXT)'"
```

### Database Access
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "docker exec calcom-db psql -U calcom -d calcom"
```

### Skip Onboarding
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "docker exec calcom-db psql -U calcom -d calcom -c \"UPDATE users SET \\\"completedOnboarding\\\" = true WHERE id = 1;\""
```

### Fix Username
```bash
ssh -i ~/Downloads/ssh-key-2025-10-17.key ubuntu@163.192.41.116 \
  "docker exec calcom-db psql -U calcom -d calcom -c \"UPDATE users SET username = 'adam' WHERE id = 1;\""
```

---

## Troubleshooting

### Error: STRIPE_PRIVATE_KEY is not set
**Cause**: Cal.com checks for Stripe keys even in self-hosted mode
**Fix**: Add placeholder values:
```yaml
STRIPE_PRIVATE_KEY: sk_test_placeholder_not_real
STRIPE_WEBHOOK_SECRET: whsec_placeholder_not_real
```

### Error: Match of WEBAPP_URL with ALLOWED_HOSTNAMES failed
**Cause**: ALLOWED_HOSTNAMES not in JSON array format
**Fix**: Use JSON array with single quotes:
```yaml
ALLOWED_HOSTNAMES: '["calendar.aienablement.academy"]'
```

### Error: Invalid key length
**Cause**: CALENDSO_ENCRYPTION_KEY not exactly 32 hex characters
**Fix**: Use exactly 32 hex chars:
```yaml
CALENDSO_ENCRYPTION_KEY: 0123456789abcdef0123456789abcdef
```

### Error: Something went wrong (generic)
**Check**:
1. All three critical env vars above
2. Docker logs: `docker logs calcom-app`
3. Database connectivity

### Stuck on Onboarding
**Fix**: Mark onboarding complete in database:
```sql
UPDATE users SET "completedOnboarding" = true WHERE id = 1;
```

---

## Google Calendar Integration

### Current Configuration (Active)
- **GCP Project**: `calcom-oauth-aea`
- **Client ID**: `35519749364-dml42gbm9thto1b36lf322ncuu57h2jo.apps.googleusercontent.com`
- **Redirect URI**: `https://calendar.aienablement.academy/api/integrations/googlecalendar/callback`

### Environment Variable (Already Configured)
```yaml
GOOGLE_API_CREDENTIALS: '{"web":{"client_id":"35519749364-dml42gbm9thto1b36lf322ncuu57h2jo.apps.googleusercontent.com","project_id":"calcom-oauth-aea","auth_uri":"https://accounts.google.com/o/oauth2/auth","token_uri":"https://oauth2.googleapis.com/token","auth_provider_x509_cert_url":"https://www.googleapis.com/oauth2/v1/certs","client_secret":"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","redirect_uris":["https://calendar.aienablement.academy/api/integrations/googlecalendar/callback"]}}'
```

### Setup New Google Calendar OAuth (if needed)
1. Install gcloud: `brew install --cask google-cloud-sdk`
2. Auth: `gcloud auth login`
3. Create project: `gcloud projects create calcom-oauth-NEW --name="Calcom OAuth"`
4. Enable API: `gcloud services enable calendar-json.googleapis.com --project=calcom-oauth-NEW`
5. Create OAuth credentials in Console (CLI doesn't support web app OAuth creation)
6. Download JSON and add to docker-compose.yml

---

## Related Documentation

- OCI Server Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/oci-server/SKILL.md`
- Cloudflare DNS Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/cloudflare-dns/SKILL.md`
- Brevo Email Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/brevo-email/SKILL.md`
