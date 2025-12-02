---
name: zai-vision
description: "Z.AI GLM-4.5V vision analysis using the working Anthropic-compatible endpoint. Use for image analysis when the Z.AI MCP server fails. Workaround for MCP server bug that ignores Z_AI_MODE=ZAI."
license: MIT
---

# Z.AI Vision Analysis (Workaround)

## Overview

This skill provides GLM-4.5V vision analysis using the Z.AI Anthropic-compatible endpoint directly. It's a workaround for the @z_ai/mcp-server bug where Z_AI_MODE=ZAI is ignored and the server defaults to ZHIPU mode (which returns "insufficient balance" errors).

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
.claude/skills/zai-vision/scripts/analyze-image.sh /path/to/image.png "Describe this image"
```

### Analyze URL Image
```bash
.claude/skills/zai-vision/scripts/analyze-url.sh "https://example.com/image.jpg" "What's in this image?"
```

## Environment Variables

- `Z_AI_API_KEY` - Your Z.AI API key (from .env or environment)

## Supported Formats

- **Local files**: PNG, JPG, JPEG, GIF, WEBP (max 5MB)
- **URLs**: Any publicly accessible image URL

## Model

Uses **GLM-4.5V** - Z.AI's vision-language model with excellent image understanding.

## Bug Report

The @z_ai/mcp-server bug should be reported to Z.AI. The fix would be:
1. Properly read Z_AI_MODE environment variable
2. Use `https://api.z.ai/api/anthropic` when mode is "ZAI"
3. Use `https://open.bigmodel.cn` only when mode is "ZHIPU"
