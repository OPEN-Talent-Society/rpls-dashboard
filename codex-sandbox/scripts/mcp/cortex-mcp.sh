#!/usr/bin/env bash
set -euo pipefail

# Launch the Cortex (SiYuan) MCP server from the monorepo root.
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repository root (codebuild), one level above codex-sandbox.
ROOT_DIR="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
BASE_DIR="$ROOT_DIR/mcp-servers/cortex"
CREDENTIALS_FILE="$ROOT_DIR/.credentials/mcp-configs/cortex.json"

# Load credentials from the central credentials file if present.
if [[ -f "$CREDENTIALS_FILE" ]]; then
  load_val() {
    node -e '
      const fs = require("fs");
      const file = process.argv[1];
      const key = process.argv[2];
      try {
        const data = JSON.parse(fs.readFileSync(file, "utf8"));
        const val = data?.mcp_config?.env?.[key];
        if (val) process.stdout.write(String(val));
      } catch {}
    ' "$CREDENTIALS_FILE" "$1"
  }

  for key in SIYUAN_BASE_URL SIYUAN_API_TOKEN CF_ACCESS_CLIENT_ID CF_ACCESS_CLIENT_SECRET CF_ACCESS_JWT; do
    val="$(load_val "$key")"
    if [[ -n "$val" ]]; then
      export "$key"="$val"
    fi
  done
fi

exec node "$BASE_DIR/index.js"
