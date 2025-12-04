#!/bin/bash
# Disable Playwright MCP to restore token savings (~14.5k tokens)

echo "Disabling Playwright MCP..."
claude mcp remove playwright 2>/dev/null || echo "Playwright MCP was not enabled"

echo "Playwright MCP disabled. Token savings restored."
echo "Use Tier 1 CLI commands for simple operations:"
echo "  pnpm dlx playwright screenshot <url> <output.png>"
echo "  pnpm dlx playwright pdf <url> <output.pdf>"
echo "  pnpm dlx playwright codegen <url>"
