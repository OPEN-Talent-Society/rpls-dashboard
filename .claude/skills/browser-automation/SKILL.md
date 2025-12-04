---
name: browser-automation
description: "Browser automation for screenshots, testing, and web scraping. Uses Playwright CLI for simple ops, enables MCP for complex multi-step browser sessions. Saves ~14.5k tokens when MCP is disabled."
---

# Browser Automation Skill

## Overview

This skill provides browser automation capabilities with a **two-tier approach**:
1. **Simple ops**: Use Playwright CLI directly (no MCP needed)
2. **Complex ops**: Enable Playwright MCP temporarily for multi-step sessions

## Token Savings

- **MCP disabled**: Saves ~14,545 tokens at startup
- **MCP enabled**: Full 22 tools available when needed

---

## Tier 1: Simple Operations (No MCP)

### Take Screenshot
```bash
# Screenshot a URL
pnpm dlx playwright screenshot https://example.com screenshot.png

# Full page screenshot
pnpm dlx playwright screenshot --full-page https://example.com full-page.png

# Mobile viewport
pnpm dlx playwright screenshot --viewport-size=375,667 https://example.com mobile.png
```

### Generate PDF
```bash
pnpm dlx playwright pdf https://example.com output.pdf
```

### Run Test File
```bash
pnpm dlx playwright test tests/example.spec.ts
```

### Install Browsers
```bash
pnpm dlx playwright install chromium
pnpm dlx playwright install firefox
pnpm dlx playwright install webkit
```

### Open Browser Inspector
```bash
pnpm dlx playwright open https://example.com
```

### Code Generation (Record)
```bash
# Record interactions and generate code
pnpm dlx playwright codegen https://example.com
```

---

## Tier 2: Complex Operations (Enable MCP)

For multi-step browser sessions requiring:
- Form filling
- Multi-page navigation
- Element interactions
- Console/network monitoring
- File uploads

### Enable MCP Temporarily

**Option 1: Via Claude Code CLI**
```bash
# Add playwright MCP to current session
claude mcp add playwright -- pnpm dlx @playwright/mcp@latest

# After task, remove if desired
claude mcp remove playwright
```

**Option 2: Via settings.json**
Add to `.claude/settings.json` → `enabledMcpjsonServers`:
```json
{
  "enabledMcpjsonServers": [
    "playwright"  // Add this
  ]
}
```

**Option 3: Temporary mcp.json entry**
The MCP config already exists in `.claude/mcp.json`:
```json
{
  "playwright": {
    "type": "stdio",
    "command": "pnpm",
    "args": ["dlx", "@playwright/mcp@latest"]
  }
}
```

### MCP Tools Available (When Enabled)

| Tool | Purpose |
|------|---------|
| `browser_navigate` | Go to URL |
| `browser_click` | Click elements |
| `browser_type` | Type into fields |
| `browser_fill_form` | Fill multiple fields |
| `browser_snapshot` | Accessibility tree (better than screenshot) |
| `browser_take_screenshot` | Visual screenshot |
| `browser_evaluate` | Run JavaScript |
| `browser_console_messages` | Get console logs |
| `browser_network_requests` | Monitor network |
| `browser_file_upload` | Upload files |
| `browser_tabs` | Manage tabs |
| `browser_wait_for` | Wait for elements/text |

---

## Common Workflows

### 1. Quick Screenshot (Tier 1)
```bash
# No MCP needed
pnpm dlx playwright screenshot https://mysite.com page.png
```

### 2. E2E Test Development (Tier 1)
```bash
# Record test
pnpm dlx playwright codegen https://mysite.com --output tests/recorded.spec.ts

# Run test
pnpm dlx playwright test tests/recorded.spec.ts
```

### 3. Complex Form Submission (Tier 2 - Enable MCP)
```
1. Enable MCP: claude mcp add playwright -- pnpm dlx @playwright/mcp@latest
2. Use browser_navigate to go to form
3. Use browser_fill_form for all fields
4. Use browser_click to submit
5. Use browser_snapshot to verify result
6. Disable MCP when done: claude mcp remove playwright
```

### 4. Debug Web App (Tier 2 - Enable MCP)
```
1. Enable MCP
2. browser_navigate to app
3. browser_console_messages to check errors
4. browser_network_requests to monitor API calls
5. browser_evaluate to inspect state
```

---

## Helper Scripts

### scripts/screenshot.sh
```bash
#!/bin/bash
# Quick screenshot helper
URL="${1:-https://example.com}"
OUTPUT="${2:-screenshot.png}"
FULL_PAGE="${3:-false}"

if [ "$FULL_PAGE" = "true" ]; then
  pnpm dlx playwright screenshot --full-page "$URL" "$OUTPUT"
else
  pnpm dlx playwright screenshot "$URL" "$OUTPUT"
fi

echo "Screenshot saved to $OUTPUT"
```

### scripts/enable-mcp.sh
```bash
#!/bin/bash
# Enable Playwright MCP for current session
echo "Enabling Playwright MCP..."
claude mcp add playwright -- pnpm dlx @playwright/mcp@latest
echo "Playwright MCP enabled. Use 'claude mcp remove playwright' when done."
```

### scripts/disable-mcp.sh
```bash
#!/bin/bash
# Disable Playwright MCP
echo "Disabling Playwright MCP..."
claude mcp remove playwright
echo "Playwright MCP disabled. Token savings restored."
```

---

## Best Practices

1. **Default to Tier 1** - Use CLI for screenshots, PDFs, simple tests
2. **Enable MCP sparingly** - Only for multi-step browser sessions
3. **Disable after use** - Remove MCP to restore token savings
4. **Use snapshots over screenshots** - `browser_snapshot` gives semantic info

## Related Skills

- `zai-vision` - For AI image analysis of screenshots
- `verification-quality` - For visual regression testing
