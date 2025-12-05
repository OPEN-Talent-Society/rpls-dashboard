---
name: zai-vision
description: "Z.AI GLM-4.5V vision analysis using curl API calls. Uses Tier 1 curl for simple analysis, enables MCP for complex multi-image workflows. Saves ~1.4k tokens when MCP is disabled."
license: MIT
---

# Z.AI Vision Analysis

## Overview

This skill provides vision analysis with a **two-tier approach**:
1. **Simple ops (Tier 1)**: Use curl API calls directly (no MCP needed)
2. **Complex ops (Tier 2)**: Enable Z.AI MCP for multi-image workflows

## Token Savings

- **MCP disabled**: Saves ~1,436 tokens at startup
- **MCP enabled**: Full 2 tools (analyze_image, analyze_video) available

---

## Note on MCP Server Bug

The @z_ai/mcp-server has a bug where Z_AI_MODE=ZAI is ignored, defaulting to ZHIPU mode (which returns "insufficient balance" errors). The Tier 1 curl approach works reliably.

## Why This Skill Exists

The official Z.AI MCP server has a bug:
- Setting `Z_AI_MODE=ZAI` is ignored
- Server defaults to ZHIPU mode (`open.bigmodel.cn`)
- ZHIPU endpoint returns error 1113 "Insufficient balance" for Coding Plan users
- Coding Plan users should use `api.z.ai/api/anthropic` endpoint instead

## Working Endpoint

**IMPORTANT**: Use URL format for images, NOT base64. GLM-4.5V has poor accuracy with base64.

```bash
# This works for Coding Plan users (URL format):
curl -X POST "https://api.z.ai/api/anthropic/v1/messages" \
  -H "x-api-key: ${Z_AI_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "glm-4.5v",
    "max_tokens": 1024,
    "messages": [{
      "role": "user",
      "content": [
        {"type": "image", "source": {"type": "url", "url": "https://example.com/image.png"}},
        {"type": "text", "text": "Describe this image"}
      ]
    }]
  }'
```

For local files, upload to a temporary URL service or use analyze-image.sh (less accurate).

## Usage

### Analyze Local Image
```bash
/Users/adamkovacs/Documents/codebuild/.claude/skills/zai-vision/scripts/analyze-image.sh /path/to/image.png "Describe this image"
```

### Analyze URL Image
```bash
/Users/adamkovacs/Documents/codebuild/.claude/skills/zai-vision/scripts/analyze-url.sh "https://example.com/image.jpg" "What's in this image?"
```

## Environment Variables

- `Z_AI_API_KEY` - Your Z.AI API key (from .env or environment)

## Supported Formats

- **Local files**: PNG, JPG, JPEG, GIF, WEBP (max 5MB)
- **URLs**: Any publicly accessible image URL

## Model

Uses **GLM-4.5V** - Z.AI's vision-language model with excellent image understanding.

## Tier 2: Enable MCP for Complex Workflows

For multi-image or video analysis workflows:

### Enable MCP Temporarily

**Option 1: Via Claude Code CLI**
```bash
# Add Z.AI MCP to current session
claude mcp add zai-mcp-server -- pnpm dlx @z_ai/mcp-server

# After task, remove to restore token savings
claude mcp remove zai-mcp-server
```

**Option 2: Add to mcp.json temporarily**
```json
{
  "zai-mcp-server": {
    "type": "stdio",
    "command": "pnpm",
    "args": ["dlx", "@z_ai/mcp-server"],
    "env": {
      "Z_AI_API_KEY": "${Z_AI_VISION_KEY}",
      "Z_AI_MODE": "ZAI"
    }
  }
}
```

### MCP Tools Available (When Enabled)

| Tool | Purpose |
|------|---------|
| `analyze_image` | AI image analysis (PNG, JPG, max 5MB) |
| `analyze_video` | AI video analysis (MP4, MOV, max 8MB) |

### When to Use MCP vs Curl

| Use Case | Recommendation |
|----------|----------------|
| Single image analysis | Tier 1 (curl) |
| Screenshot analysis | Tier 1 (curl) |
| Video analysis | Tier 2 (MCP) |
| Batch image processing | Tier 2 (MCP) |
| Complex prompts | Either works |

---

## Bug Report

The @z_ai/mcp-server bug should be reported to Z.AI. The fix would be:
1. Properly read Z_AI_MODE environment variable
2. Use `https://api.z.ai/api/anthropic` when mode is "ZAI"
3. Use `https://open.bigmodel.cn` only when mode is "ZHIPU"
