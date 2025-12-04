#!/usr/bin/env bash
# Wrapper for the NocoDB CSV export automation.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
TARGET_SCRIPT="$REPO_ROOT/ops/backup/export-nocodb-csv.sh"

if [[ ! -x "$TARGET_SCRIPT" ]]; then
  echo "Expected automation script not found or not executable: $TARGET_SCRIPT" >&2
  exit 1
fi

exec "$TARGET_SCRIPT" "$@"
