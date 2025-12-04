#!/usr/bin/env bash
# Wrapper for Docmost Markdown export automation.
# This delegates to ops/docmost/export-markdown.sh so the skill can be
# executed from any working directory while keeping logs local to the caller.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TARGET_SCRIPT="$REPO_ROOT/ops/docmost/export-markdown.sh"

if [[ ! -x "$TARGET_SCRIPT" ]]; then
  echo "Expected automation script not found or not executable: $TARGET_SCRIPT" >&2
  exit 1
fi

exec "$TARGET_SCRIPT" "$@"
