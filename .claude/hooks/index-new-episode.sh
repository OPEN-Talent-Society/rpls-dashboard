#!/bin/bash
# Index new episode to AgentDB embeddings
# Called by PostToolUse hook after agentdb_pattern_store
# Uses AgentDB's built-in Transformers.js for embeddings

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
AGENTDB="$PROJECT_DIR/agentdb.db"
LOG_FILE="/tmp/claude-embedding-index.log"

log() {
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1" >> "$LOG_FILE"
}

# Get the latest episode that doesn't have an embedding
LATEST=$(sqlite3 "$AGENTDB" "
SELECT e.id, e.task
FROM episodes e
LEFT JOIN episode_embeddings ee ON e.id = ee.episode_id
WHERE ee.episode_id IS NULL
ORDER BY e.id DESC
LIMIT 1;
" 2>/dev/null)

if [ -z "$LATEST" ]; then
    log "No new episodes to index"
    exit 0
fi

EPISODE_ID=$(echo "$LATEST" | cut -d'|' -f1)
TASK=$(echo "$LATEST" | cut -d'|' -f2)

log "Indexing episode #$EPISODE_ID: $TASK"

# Use AgentDB MCP to generate and store embedding
# This runs async/in background to not block
(
    /opt/homebrew/bin/claude-flow agentdb pattern-store \
        --sessionId "embedding-index" \
        --task "$TASK" \
        --reward 0 \
        --success false \
        --critique "Embedding index placeholder" \
        2>/dev/null || log "Failed to index episode #$EPISODE_ID"

    log "Indexed episode #$EPISODE_ID"
) &

echo "indexing_started"
