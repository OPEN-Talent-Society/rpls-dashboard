#!/bin/bash
# Wrapper for memory sync operations
# Usage: sync.sh [--incremental|--force]

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

bash "$PROJECT_DIR/.claude/skills/memory-sync/scripts/sync-all.sh" "$@"
