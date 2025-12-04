# MCP Token Optimization Guide

## Overview

MCP tools consume tokens at startup. This guide documents the **ultra-lean** optimization strategy that reduces token usage from ~38k to ~12k while maintaining full functionality through on-demand skills.

## Token Savings Summary

| MCP Server | Tokens | Status | Replacement | Tested |
|------------|--------|--------|-------------|--------|
| Playwright | ~14,545 | **Disabled** | `browser-automation` skill | ✅ WORKS |
| Brevo | ~8,559 | **Disabled** | `brevo-email` skill | ✅ WORKS |
| NocoDB | ~3,000+ | **Disabled** | `nocodb-tasks` skill | ✅ WORKS |
| ZAI | ~1,436 | **Disabled** | `zai-vision` skill | ✅ WORKS |
| Cortex | ~1,306 | **Disabled** | `cortex-knowledge` skill | ✅ WORKS |
| Flow-Nexus | ~5,000+ | **Disabled** | On-demand only | - |
| **Total Saved** | **~34,000+** | | | |

## Current Ultra-Lean Configuration

### Enabled MCPs (Always Loaded in `.mcp.json`)
```json
{
  "mcpServers": {
    "claude-flow": {},    // Core orchestration (~10.6k tokens, 72 agents)
    "context7": {}        // Docs lookup (~1.8k tokens)
  }
}
```

**Estimated Token Usage**: ~12k tokens (down from ~38k = **68% reduction**)

### Disabled MCPs (On-Demand via Skills)
All other MCPs are disabled by default and replaced with skills that use direct API calls.

---

## Skills Reference

### `nocodb-tasks` - Task Management ✅ TESTED
**Replaces**: nocodb-base-ops MCP (~3k tokens)

**Important**: NocoDB uses TWO different token types:
- `NOCODB_API_TOKEN` → For REST API calls (Tier 1)
- `NOCODB_MCP_TOKEN` → For MCP remote protocol only (Tier 2)

**Tier 1 (No MCP)**:
```bash
# Create task
bash .claude/skills/nocodb-tasks/scripts/create-task.sh "Task title" "To Do" "P2"

# Update status
bash .claude/skills/nocodb-tasks/scripts/update-status.sh 123 "Done"

# List tasks
bash .claude/skills/nocodb-tasks/scripts/list-tasks.sh "In Progress"
```

**Tier 2 (Enable MCP for batch ops)**:
```bash
claude mcp add nocodb-base-ops -- pnpm dlx mcp-remote "${NOCODB_URL}/mcp/ncmvk15tvewrerlg" --header "xc-mcp-token: ${NOCODB_MCP_TOKEN}"
```

### `cortex-knowledge` - Knowledge Management ✅ TESTED
**Replaces**: cortex MCP (~1.3k tokens)

**Tier 1 (No MCP)**:
```bash
# Search documents
bash .claude/skills/cortex-knowledge/scripts/search.sh "keyword"

# Create learning
bash .claude/skills/cortex-knowledge/scripts/create-learning.sh "Title" "Content"

# Export document
bash .claude/skills/cortex-knowledge/scripts/export-doc.sh "doc-id"
```

**Tier 2 (Enable MCP)**:
```bash
claude mcp add cortex -- node /Users/adamkovacs/Documents/codebuild/mcp-servers/cortex/index.js
```

### `browser-automation` - Screenshots & Testing ✅ TESTED
**Replaces**: playwright MCP (~14.5k tokens)

**Tier 1 (No MCP)**:
```bash
pnpm dlx playwright screenshot https://example.com output.png
pnpm dlx playwright screenshot --full-page https://example.com full.png
pnpm dlx playwright pdf https://example.com output.pdf
```

**Tier 2 (Enable MCP)**:
```bash
claude mcp add playwright -- pnpm dlx @playwright/mcp@latest
```

### `brevo-email` - Email Operations ✅ TESTED
**Replaces**: brevo-mcp (~8.5k tokens)

**Tier 1 (No MCP)**:
```bash
source .env
curl -X POST https://api.brevo.com/v3/smtp/email \
  -H "api-key: $BREVO_API_KEY" \
  -H "content-type: application/json" \
  -d '{"sender":{"email":"noreply@example.com"},"to":[{"email":"user@example.com"}],"subject":"Test","htmlContent":"<p>Hello</p>"}'
```

**Tier 2 (Enable MCP)**:
```bash
claude mcp add brevo-mcp -- node /Users/adamkovacs/Documents/codebuild/mcp-servers/brevo-mcp/build/index.js
```

### `zai-vision` - AI Vision Analysis ✅ TESTED
**Replaces**: zai-mcp-server (~1.4k tokens)

**Tier 1 (No MCP)**:
```bash
bash .claude/skills/zai-vision/scripts/analyze-url.sh "https://example.com/image.png" "Describe this"
```

---

## How to Enable Disabled MCPs On-Demand

### Method 1: Claude Code CLI (Recommended)
```bash
# Enable for current session
claude mcp add <name> -- <command>

# Disable when done
claude mcp remove <name>
```

### Method 2: Edit .mcp.json
Add the server definition temporarily, then remove when done.

---

## Required Environment Variables

All skills require these variables in `.env`:

```bash
# NocoDB (TWO tokens required)
NOCODB_URL=https://ops.aienablement.academy
NOCODB_API_TOKEN=<api-token>         # For REST API (Tier 1)
NOCODB_MCP_TOKEN=<mcp-token>         # For MCP protocol (Tier 2)
NOCODB_DATABASE_ID=pz7wdven8yqgx3r
NOCODB_TASKS_TABLE_ID=mmx3z4zxdj9ysfk
NOCODB_SPRINTS_TABLE_ID=mtkfphwlmiv8mzp

# Cortex
CORTEX_TOKEN=<token>
CF_ACCESS_CLIENT_ID=<id>
CF_ACCESS_CLIENT_SECRET=<secret>

# Brevo
BREVO_API_KEY=<key>

# ZAI
Z_AI_API_KEY=<key>
```

---

## Best Practices

1. **Start ultra-lean** - Only claude-flow + context7 by default
2. **Use skills first** - Tier 1 curl/CLI operations work without MCP
3. **Enable MCP sparingly** - Only for batch/complex operations
4. **Disable after use** - Remove MCPs to restore token savings
5. **Monitor `/context`** - Check MCP tool token usage
6. **Batch operations** - If you need MCP, do all operations at once

---

## Security: No Hardcoded Credentials

All skills and scripts load credentials from `.env`:
```bash
# Proper pattern in scripts:
if [ -f "/Users/adamkovacs/Documents/codebuild/.env" ]; then
    set -a; source "/Users/adamkovacs/Documents/codebuild/.env"; set +a
fi

# Always validate required vars:
[ -z "$API_KEY" ] && { echo "Error: API_KEY not set"; exit 1; }
```

**NEVER** hardcode tokens in code files. All credentials are gitignored in `.env`.

---

## Configuration Files

- **Project MCP Config**: `.mcp.json` (what gets loaded)
- **Settings**: `.claude/settings.json` (enabledMcpjsonServers, disabledMcpjsonServers)
- **Skills**: `.claude/skills/*/SKILL.md` (documentation with API patterns)

---

## Verification

After restart, check token reduction:
```
/context
```

Expected MCP tools section should show ~12k tokens instead of ~38k.

### Test Commands

```bash
# Test NocoDB skill
bash .claude/skills/nocodb-tasks/scripts/list-tasks.sh "Done"

# Test Cortex skill
bash .claude/skills/cortex-knowledge/scripts/search.sh "test"

# Test browser automation
pnpm dlx playwright screenshot https://example.com /tmp/test.png

# Test ZAI vision
bash .claude/skills/zai-vision/scripts/analyze-url.sh "https://example.com/image.png" "describe"

# Test Brevo (account info)
source .env && curl -s https://api.brevo.com/v3/account -H "api-key: $BREVO_API_KEY"

# Test claude-flow MCP
# Use: mcp__claude-flow__agentic_flow_list_agents
```

---

## Last Updated

2025-12-04 - All skills tested and working
