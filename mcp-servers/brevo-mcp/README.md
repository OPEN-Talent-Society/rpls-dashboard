# Brevo MCP Server

A Model Context Protocol (MCP) server for [Brevo](https://www.brevo.com/) (formerly Sendinblue) email marketing platform. This server enables AI assistants like Claude to send transactional emails, manage contacts, lists, and campaigns directly through the Brevo API.

## Features

- **Transactional Emails**: Send custom HTML emails or use pre-defined templates
- **Contact Management**: Create, update, delete, and retrieve contacts
- **List Management**: Organize contacts into lists for targeted campaigns
- **Campaign Analytics**: View email campaigns and their performance statistics
- **Account Info**: Access account details and usage information

## Installation

```bash
cd /path/to/brevo-mcp
pnpm install
pnpm run build
```

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `BREVO_API_KEY` | Yes | Your Brevo API key |
| `BREVO_MCP_TOKEN` | No | Brevo MCP token (alternative auth) |
| `BREVO_SENDER_EMAIL` | No | Default sender email address |
| `BREVO_SENDER_NAME` | No | Default sender name |

### Claude Code Setup

Add to your Claude Code MCP configuration:

```bash
claude mcp add brevo-mcp node /path/to/brevo-mcp/build/index.js
```

Or add to `.claude/settings.json`:

```json
{
  "mcpServers": {
    "brevo-mcp": {
      "command": "node",
      "args": ["/path/to/brevo-mcp/build/index.js"],
      "env": {
        "BREVO_API_KEY": "your-api-key-here"
      }
    }
  }
}
```

## Available Tools

### Email Operations

| Tool | Description |
|------|-------------|
| `send_transactional_email` | Send custom HTML transactional emails |
| `send_template_email` | Send emails using Brevo templates |
| `get_transactional_emails` | List sent transactional emails |

### Contact Management

| Tool | Description |
|------|-------------|
| `create_contact` | Create a new contact |
| `update_contact` | Update contact attributes |
| `get_contact` | Get contact information |
| `delete_contact` | Remove a contact |

### List Management

| Tool | Description |
|------|-------------|
| `get_lists` | Get all contact lists |
| `create_list` | Create a new list |

### Campaign Operations

| Tool | Description |
|------|-------------|
| `get_email_campaigns` | List email campaigns |
| `get_campaign_stats` | Get campaign statistics |

### Account

| Tool | Description |
|------|-------------|
| `get_account_info` | Get account details |
| `get_senders` | List verified sender addresses |

## Example Usage

### Send a Verification Code Email

```typescript
// Using template
mcp__brevo-mcp__send_template_email({
  to: [{ email: "user@example.com" }],
  templateId: 2,
  params: {
    code: "123456",
    expiryMinutes: 10,
    appName: "My App"
  }
})

// Using custom HTML
mcp__brevo-mcp__send_transactional_email({
  to: [{ email: "user@example.com", name: "John Doe" }],
  subject: "Your verification code",
  htmlContent: "<p>Your code is: <strong>123456</strong></p>",
  tags: ["auth", "verification"]
})
```

### Create a Contact

```typescript
mcp__brevo-mcp__create_contact({
  email: "newuser@example.com",
  attributes: {
    FIRSTNAME: "John",
    LASTNAME: "Doe",
    SIGNUP_DATE: "2024-01-15"
  },
  listIds: [1, 2]
})
```

## API Reference

- [Brevo API Documentation](https://developers.brevo.com/)
- [Brevo MCP Protocol](https://developers.brevo.com/docs/mcp-protocol)

## License

MIT
