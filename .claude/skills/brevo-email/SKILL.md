---
name: "Brevo Email Operations"
description: "Send transactional emails, manage contacts, and handle email campaigns using Brevo API. Uses curl for simple ops, enables MCP for complex workflows. Saves ~8.5k tokens when MCP is disabled."
---

# Brevo Email Operations

## Overview

This skill provides email operations with a **two-tier approach**:
1. **Simple ops (Tier 1)**: Use curl API calls directly (no MCP needed)
2. **Complex ops (Tier 2)**: Enable Brevo MCP for multi-step workflows

## Token Savings

- **MCP disabled**: Saves ~8,559 tokens at startup
- **MCP enabled**: Full 13 tools available when needed

---

## What This Skill Does

Manage all Brevo email operations using direct API calls and CLI commands:
1. Send transactional emails via API
2. Manage contacts and lists
3. Configure SMTP for applications
4. Monitor email delivery status

## Credentials Location

**CRITICAL: Always check this file first for Brevo credentials:**
```
/Users/adamkovacs/Documents/codebuild/.credentials/brevo/api.env
```

If not exists, check Formbricks for SMTP credentials or request new API key from Brevo dashboard.

## Quick Reference

### Environment Variables
```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/brevo/api.env
# Sets: BREVO_API_KEY, BREVO_SMTP_USER, BREVO_SMTP_PASS
```

### SMTP Configuration
- **Host**: smtp-relay.brevo.com
- **Port**: 587 (TLS)
- **User**: Check credentials file or Formbricks `.env`
- **Password**: Check credentials file or Formbricks `.env`

---

## Common Operations

### Send Transactional Email

```bash
source /Users/adamkovacs/Documents/codebuild/.credentials/brevo/api.env

curl --request POST \
  --url https://api.brevo.com/v3/smtp/email \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data '{
    "sender": {"name": "AI Enablement Academy", "email": "noreply@aienablement.academy"},
    "to": [{"email": "recipient@example.com", "name": "John Doe"}],
    "subject": "Your Subject Here",
    "htmlContent": "<html><body><h1>Hello!</h1><p>Your message here.</p></body></html>"
  }'
```

### Send Email with Template

```bash
curl --request POST \
  --url https://api.brevo.com/v3/smtp/email \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data '{
    "to": [{"email": "recipient@example.com", "name": "John Doe"}],
    "templateId": 8,
    "params": {"name": "John", "verification_code": "123456"}
  }'
```

### Create Contact

```bash
curl --request POST \
  --url https://api.brevo.com/v3/contacts \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data '{
    "email": "newcontact@example.com",
    "attributes": {"FNAME": "John", "LNAME": "Doe"},
    "listIds": [1],
    "updateEnabled": true
  }'
```

### Get Contact Info

```bash
curl --request GET \
  --url "https://api.brevo.com/v3/contacts/user@example.com" \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY"
```

### List All Contact Lists

```bash
curl --request GET \
  --url "https://api.brevo.com/v3/contacts/lists" \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY"
```

### Add Contact to List

```bash
curl --request POST \
  --url "https://api.brevo.com/v3/contacts/lists/{listId}/contacts/add" \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data '{"emails": ["user1@example.com", "user2@example.com"]}'
```

### Get Account Info

```bash
curl --request GET \
  --url "https://api.brevo.com/v3/account" \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY"
```

### Get Transactional Email Stats

```bash
curl --request GET \
  --url "https://api.brevo.com/v3/smtp/statistics/events?limit=50&startDate=2025-01-01" \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY"
```

---

## Application SMTP Configuration

### Cal.com Configuration
```env
EMAIL_FROM=calendar@aienablement.academy
EMAIL_SERVER_HOST=smtp-relay.brevo.com
EMAIL_SERVER_PORT=587
EMAIL_SERVER_USER=99a389001@smtp-brevo.com
EMAIL_SERVER_PASSWORD=<from-credentials-file>
```

### Formbricks Configuration
```env
MAIL_FROM=forms@aienablement.academy
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=99a389001@smtp-brevo.com
SMTP_PASSWORD=<from-credentials-file>
```

### Generic Node.js/Nodemailer
```javascript
const transporter = nodemailer.createTransport({
  host: 'smtp-relay.brevo.com',
  port: 587,
  secure: false, // TLS
  auth: {
    user: process.env.BREVO_SMTP_USER,
    pass: process.env.BREVO_SMTP_PASS
  }
});
```

---

## Helper Scripts

### Test Email Script
Create and run: `scripts/test-email.sh`
```bash
#!/bin/bash
source /Users/adamkovacs/Documents/codebuild/.credentials/brevo/api.env

EMAIL_TO="${1:-adam@aienablement.academy}"
SUBJECT="${2:-Test Email from Brevo API}"

curl --request POST \
  --url https://api.brevo.com/v3/smtp/email \
  --header 'accept: application/json' \
  --header "api-key: $BREVO_API_KEY" \
  --header 'content-type: application/json' \
  --data "{
    \"sender\": {\"name\": \"AI Enablement Academy\", \"email\": \"noreply@aienablement.academy\"},
    \"to\": [{\"email\": \"$EMAIL_TO\"}],
    \"subject\": \"$SUBJECT\",
    \"htmlContent\": \"<html><body><h1>Test Email</h1><p>This is a test email sent at $(date).</p></body></html>\"
  }"

echo ""
echo "Test email sent to $EMAIL_TO"
```

---

## Troubleshooting

### Issue: 401 Unauthorized
**Symptoms**: API returns 401 error
**Cause**: Invalid or expired API key
**Solution**: Generate new API key from Brevo dashboard → Settings → API Keys

### Issue: Email Not Delivered
**Symptoms**: API returns success but email not received
**Cause**: Email may be in spam, or sender not verified
**Solution**:
1. Check spam folder
2. Verify sender domain in Brevo dashboard
3. Check transactional logs: `GET /v3/smtp/statistics/events`

### Issue: SMTP Connection Refused
**Symptoms**: Connection timeout to smtp-relay.brevo.com
**Cause**: Firewall blocking port 587
**Solution**: Ensure outbound port 587 is open, try port 465 (SSL)

---

## Tier 2: Enable MCP for Complex Workflows

For multi-step email workflows requiring:
- Bulk contact operations
- Campaign management
- Complex list management
- Detailed statistics queries

### Enable MCP Temporarily

**Option 1: Via Claude Code CLI**
```bash
# Add brevo MCP to current session
claude mcp add brevo-mcp -- node /Users/adamkovacs/Documents/codebuild/mcp-servers/brevo-mcp/dist/index.js

# After task, remove to restore token savings
claude mcp remove brevo-mcp
```

**Option 2: Add to mcp.json temporarily**
```json
{
  "brevo-mcp": {
    "type": "stdio",
    "command": "node",
    "args": ["/Users/adamkovacs/Documents/codebuild/mcp-servers/brevo-mcp/dist/index.js"],
    "env": {
      "BREVO_API_KEY": "${BREVO_API_KEY}"
    }
  }
}
```

### MCP Tools Available (When Enabled)

| Tool | Purpose |
|------|---------|
| `send_transactional_email` | Send HTML emails |
| `send_template_email` | Send using Brevo templates |
| `create_contact` | Add new contact |
| `update_contact` | Update contact attributes |
| `get_contact` | Get contact info |
| `delete_contact` | Remove contact |
| `get_lists` | List all contact lists |
| `create_list` | Create new list |
| `get_email_campaigns` | List campaigns |
| `get_campaign_stats` | Campaign statistics |
| `get_transactional_emails` | Email logs |
| `get_account_info` | Account details |
| `get_senders` | Verified senders |

### When to Use MCP vs Curl

| Use Case | Recommendation |
|----------|----------------|
| Send single email | Tier 1 (curl) |
| Bulk contact import | Tier 2 (MCP) |
| Get contact info | Tier 1 (curl) |
| Campaign analytics | Tier 2 (MCP) |
| SMTP configuration | Tier 1 (curl) |
| Complex list management | Tier 2 (MCP) |

---

## Related Documentation

- API Reference: https://developers.brevo.com/reference
- SMTP Setup: https://help.brevo.com/hc/en-us/articles/360001225580
- OCI Server Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/oci-server/SKILL.md`
- Cloudflare DNS Skill: `/Users/adamkovacs/Documents/codebuild/.claude/skills/cloudflare-dns/SKILL.md`
