#!/bin/bash
# Wrapper for memory health check
# Usage: health.sh

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

bash "$PROJECT_DIR/.claude/skills/memory-sync/scripts/memory-stats.sh"
