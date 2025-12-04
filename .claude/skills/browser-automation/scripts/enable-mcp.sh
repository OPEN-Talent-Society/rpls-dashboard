#!/bin/bash
# Enable Playwright MCP for complex browser operations
# This adds ~14.5k tokens but gives access to 22 browser tools

echo "Enabling Playwright MCP..."
claude mcp add playwright -- pnpm dlx @playwright/mcp@latest

echo ""
echo "Playwright MCP enabled. Available tools:"
echo "  - browser_navigate, browser_click, browser_type"
echo "  - browser_fill_form, browser_snapshot, browser_take_screenshot"
echo "  - browser_evaluate, browser_console_messages, browser_network_requests"
echo "  - browser_file_upload, browser_tabs, browser_wait_for"
echo ""
echo "Run 'claude mcp remove playwright' when done to restore token savings."
