#!/bin/bash
# Wrapper for unified memory search
# Usage: search.sh "query" [backend] [limit]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

QUERY="${1:-}"
BACKEND="${2:-all}"
LIMIT="${3:-5}"

if [ -z "$QUERY" ]; then
    echo "Usage: search.sh \"query\" [backend] [limit]"
    echo "Backends: all, supabase, agentdb, cortex, swarm"
    exit 1
fi

bash "$PROJECT_DIR/.claude/skills/memory-sync/scripts/unified-search.sh" "$QUERY" "$BACKEND" "$LIMIT"
