#!/bin/bash
# ====================================================
# Sync Episodes from AgentDB to Qdrant (OPTIMIZED - Batch Processing)
# Processes episodes in batches for 50-100x performance improvement
# ====================================================

set -e

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/Users/adamkovacs/Documents/codebuild/.env"

if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo "❌ Environment file not found: $ENV_FILE"
  exit 1
fi

# Configuration
AGENTDB_PATH="/Users/adamkovacs/Documents/codebuild/agentdb.db"
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
# IMPORTANT: Always use "agent_memory" collection - dont rely on env var
QDRANT_COLLECTION="agent_memory"
GEMINI_KEY="${GEMINI_API_KEY}"
GEMINI_MODEL="${QDRANT_EMBEDDING_MODEL:-gemini-embedding-001}"
SYNC_STATE_FILE="/tmp/qdrant-episodes-sync-state.json"

# Batch configuration
BATCH_SIZE=20  # Process 20 episodes per batch (reduced for 768-dim vectors)
MAX_BATCHES=${1:-0}  # 0 = unlimited (process all)

echo "🔄 Starting Episodes (AgentDB) → Qdrant sync (BATCH MODE)..."
echo "🗄️  AgentDB: ${AGENTDB_PATH}"
echo "🗄️  Qdrant: ${QDRANT_URL}"
echo "📦 Collection: ${QDRANT_COLLECTION}"
echo "📊 Batch Size: ${BATCH_SIZE}"
echo ""

# Check AgentDB
if [ ! -f "$AGENTDB_PATH" ]; then
  echo "❌ AgentDB not found: $AGENTDB_PATH"
  exit 1
fi

# Initialize state tracking
if [ ! -f "$SYNC_STATE_FILE" ]; then
    echo '{"last_synced_id":0,"last_sync_time":"1970-01-01T00:00:00Z"}' > "$SYNC_STATE_FILE"
fi

LAST_SYNCED_ID=$(jq -r '.last_synced_id // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")

# Count episodes
TOTAL_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
UNSYNCED_COUNT=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes WHERE id > $LAST_SYNCED_ID;" 2>/dev/null || echo "0")

echo "📊 Total episodes: $TOTAL_COUNT"
echo "📊 Unsynced episodes: $UNSYNCED_COUNT"
echo "📊 Last synced ID: $LAST_SYNCED_ID"
echo ""

if [ "$UNSYNCED_COUNT" -eq 0 ]; then
    echo "✅ All episodes already synced!"
    exit 0
fi

# Calculate batches
NUM_BATCHES=$(( (UNSYNCED_COUNT + BATCH_SIZE - 1) / BATCH_SIZE ))
if [ "$MAX_BATCHES" -gt 0 ] && [ "$NUM_BATCHES" -gt "$MAX_BATCHES" ]; then
    NUM_BATCHES=$MAX_BATCHES
fi

echo "🔄 Processing $UNSYNCED_COUNT episodes in $NUM_BATCHES batch(es)..."
echo ""

# Use process-specific temp files to avoid conflicts
PID=$$
POINTS_FILE="/tmp/qdrant-batch-points-${PID}.tmp"
REQUESTS_FILE="/tmp/qdrant-batch-requests-${PID}.tmp"
EPISODES_FILE="/tmp/qdrant-episodes-data-${PID}.tmp"
PAYLOAD_FILE="/tmp/qdrant-batch-payload-${PID}.json"

# Clean up temp files from previous runs
rm -f /tmp/qdrant-batch-*.tmp /tmp/qdrant-batch-*.json 2>/dev/null
echo "🧹 Cleaned up old temp files (using PID: $PID)"

TOTAL_SUCCESSFUL=0
TOTAL_FAILED=0
BATCH_NUM=0
MAX_ID=$LAST_SYNCED_ID

# Process in batches
while [ $BATCH_NUM -lt $NUM_BATCHES ]; do
    BATCH_NUM=$((BATCH_NUM + 1))
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📦 Batch $BATCH_NUM/$NUM_BATCHES"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Fetch batch of episodes directly from SQLite (using JSONL for safety)
    # Each line is a complete JSON object - no delimiters needed
    EPISODES_JSON=$(sqlite3 "$AGENTDB_PATH" -json "
        SELECT
            id,
            COALESCE(session_id, '') as session_id,
            REPLACE(REPLACE(COALESCE(task, ''), char(10), ' '), char(13), ' ') as task,
            REPLACE(REPLACE(COALESCE(critique, ''), char(10), ' '), char(13), ' ') as critique,
            COALESCE(reward, 0) as reward,
            COALESCE(success, 0) as success
        FROM episodes
        WHERE id > $MAX_ID
        ORDER BY id ASC
        LIMIT $BATCH_SIZE;
    ")

    EPISODE_COUNT=$(echo "$EPISODES_JSON" | jq 'length' 2>/dev/null || echo "0")

    # Handle empty result
    if [ "$EPISODE_COUNT" -eq 0 ]; then
        echo "✅ No more episodes to process"
        break
    fi

    echo "📥 Fetched $EPISODE_COUNT episodes"

    # Collect points for batch upsert
    BATCH_SUCCESSFUL=0
    BATCH_FAILED=0

    # CRITICAL: Clean up temp files BEFORE starting this batch (prevent accumulation from failed runs)
    rm -f "$POINTS_FILE" "$REQUESTS_FILE" "$EPISODES_FILE" "$PAYLOAD_FILE"

    # STEP 1: Collect episode data and build batch embedding requests (OPTIMIZED - Direct JSON)
    echo "📋 Collecting $EPISODE_COUNT episodes for batch embedding..."

    # Convert JSON array to JSONL (one object per line) and process
    # Use process substitution to avoid subshell issues with pipe
    while read -r episode_json; do
        EPISODE_ID=$(echo "$episode_json" | jq -r '.id')
        # Track max ID
        if [ "$EPISODE_ID" -gt "$MAX_ID" ]; then
            MAX_ID=$EPISODE_ID
        fi

        # Extract task and critique directly for embedding text
        TASK=$(echo "$episode_json" | jq -r '.task')
        CRITIQUE=$(echo "$episode_json" | jq -r '.critique')

        # Create embedding text
        EMBEDDING_TEXT="${TASK} ${CRITIQUE}"

        # Build embedding request (single jq call with pre-extracted data)
        REQUEST=$(jq -n \
            --arg text "$EMBEDDING_TEXT" \
            '{model: "models/gemini-embedding-001", content: {parts: [{text: $text}]}, outputDimensionality: 768}')

        # Save request and store original episode JSON (no pipe delimiters!)
        echo "$REQUEST" >> "$REQUESTS_FILE"
        echo "$episode_json" >> "$EPISODES_FILE"
    done < <(echo "$EPISODES_JSON" | jq -c '.[]')

    # STEP 2: Make ONE batch embedding API call
    if [ -f "$REQUESTS_FILE" ]; then
        REQUEST_COUNT=$(cat "$REQUESTS_FILE" | wc -l | tr -d ' ')
        echo "🚀 Generating $REQUEST_COUNT embeddings in ONE batch API call..."

        # Build batch request payload
        BATCH_REQUEST=$(cat "$REQUESTS_FILE" | jq -s '{requests: .}')

        # Single batch API call for all embeddings
        BATCH_RESPONSE=$(curl -s --max-time 60 -X POST \
            "https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:batchEmbedContents?key=${GEMINI_KEY}" \
            -H "Content-Type: application/json" \
            -d "$BATCH_REQUEST" 2>/dev/null)

        # Check if batch succeeded
        EMBEDDINGS_COUNT=$(echo "$BATCH_RESPONSE" | jq '.embeddings | length' 2>/dev/null || echo "0")

        if [ "$EMBEDDINGS_COUNT" -eq 0 ]; then
            echo "❌ Batch embedding failed - no embeddings returned"
            echo "Response: $BATCH_RESPONSE" | head -200
            BATCH_FAILED=$REQUEST_COUNT
        else
            echo "✅ Received $EMBEDDINGS_COUNT embeddings"

            # STEP 3: Create Qdrant points with batch embeddings
            echo "  📝 Processing embeddings into Qdrant points..."
            EPISODE_INDEX=0
            while read -r episode_json; do
                # Extract fields from JSON
                EPISODE_ID=$(echo "$episode_json" | jq -r '.id')
                SESSION_ID=$(echo "$episode_json" | jq -r '.session_id')
                TASK=$(echo "$episode_json" | jq -r '.task')
                CRITIQUE=$(echo "$episode_json" | jq -r '.critique')
                REWARD=$(echo "$episode_json" | jq -r '.reward')
                SUCCESS=$(echo "$episode_json" | jq -r '.success')

                echo "    Processing episode #${EPISODE_ID} (index $EPISODE_INDEX)..."

                # Get corresponding embedding from batch response
                EMBEDDING=$(echo "$BATCH_RESPONSE" | jq -c ".embeddings[$EPISODE_INDEX].values" 2>/dev/null)

                # Validate embedding is valid JSON array
                if [ "$EMBEDDING" == "null" ] || [ -z "$EMBEDDING" ] || ! echo "$EMBEDDING" | jq -e '.' >/dev/null 2>&1; then
                    echo "      ⚠️  Invalid/missing embedding"
                    BATCH_FAILED=$((BATCH_FAILED + 1))
                else
                    echo "      ✓ Embedding valid, creating point..."
                    # Create point using Python (more robust than jq for complex strings)
                    POINT_ID=$((2000000 + EPISODE_ID))

                    # Combine task and critique for chunking
                    COMBINED_TEXT="${TASK}\n\n${CRITIQUE}"

                    # Use smart-chunker.py for intelligent content handling
                    CHUNK_INPUT=$(jq -n \
                        --arg content "$COMBINED_TEXT" \
                        --arg type "text" \
                        --argjson meta "$(jq -n \
                            --arg sid "$SESSION_ID" \
                            --arg eid "$EPISODE_ID" \
                            --arg rew "$REWARD" \
                            --arg suc "$SUCCESS" \
                            '{session_id: $sid, episode_id: $eid, reward: $rew, success: $suc}')" \
                        '{content: $content, content_type: $type, metadata: $meta}')

                    CHUNK_RESULT=$(echo "$CHUNK_INPUT" | python3 "${SCRIPT_DIR}/smart-chunker.py" 2>&1)

                    # Extract first chunk (or full content if under threshold)
                    CHUNKED_TEXT=$(echo "$CHUNK_RESULT" | jq -r '.chunks[0].text // ""' 2>/dev/null || echo "$COMBINED_TEXT")
                    CONTENT_HASH=$(echo "$CHUNK_RESULT" | jq -r '.chunks[0].hash // ""' 2>/dev/null || echo "")

                    # If chunking failed, fallback to simple truncation
                    if [ -z "$CHUNKED_TEXT" ]; then
                        echo "      ⚠️  Smart chunker failed, using fallback truncation"
                        if [ "${#COMBINED_TEXT}" -gt 2000 ]; then
                            CHUNKED_TEXT="${COMBINED_TEXT:0:1997}..."
                        else
                            CHUNKED_TEXT="$COMBINED_TEXT"
                        fi
                        CONTENT_HASH=$(echo -n "$CHUNKED_TEXT" | sha256sum | awk '{print $1}')
                    fi

                    # Extract project and category from session_id if present
                    # Format: session-{project}-{category}-{timestamp}
                    PROJECT=$(echo "$SESSION_ID" | sed -E 's/session-([^-]+)-.*/\1/' || echo "unknown")
                    CATEGORY=$(echo "$SESSION_ID" | sed -E 's/session-[^-]+-([^-]+)-.*/\1/' || echo "general")

                    # Use Python to safely create JSON with enhanced metadata
                    POINT=$(python3 -c "
import json
import sys

point_id = $POINT_ID
embedding = $EMBEDDING
session_id = '''$SESSION_ID'''
task = '''$TASK'''
critique = '''$CRITIQUE'''
chunked_text = '''$CHUNKED_TEXT'''
content_hash = '''$CONTENT_HASH'''
project = '''$PROJECT'''
category = '''$CATEGORY'''
reward = float('$REWARD')
success = int('$SUCCESS')
episode_id = $EPISODE_ID

point = {
    'id': point_id,
    'vector': embedding,
    'payload': {
        'source': 'agentdb_episodes',
        'session_id': session_id,
        'task': task[:500],  # Keep original task (truncated)
        'critique': critique[:500],  # Keep original critique (truncated)
        'content': chunked_text,  # Smart-chunked content
        'content_hash': content_hash,  # SHA256 hash for dedup
        'project': project,  # Extracted project
        'category': category,  # Extracted category
        'reward': reward,
        'success': success,
        'episode_id': episode_id,
        'synced_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
    }
}

print(json.dumps(point))
" 2>&1)

                    # Check if point creation succeeded
                    # Valid JSON starts with { and ends with }, Python errors start with "Traceback" or have no braces
                    if [ -z "$POINT" ]; then
                        echo "      ✗ Failed - empty output"
                        BATCH_FAILED=$((BATCH_FAILED + 1))
                    elif echo "$POINT" | head -1 | grep -q "^Traceback"; then
                        echo "      ✗ Failed - Python error"
                        echo "      Error: $(echo "$POINT" | head -3)"
                        BATCH_FAILED=$((BATCH_FAILED + 1))
                    elif ! echo "$POINT" | jq -e '.' >/dev/null 2>&1; then
                        echo "      ✗ Failed - invalid JSON"
                        echo "      Output: $(echo "$POINT" | head -2)"
                        BATCH_FAILED=$((BATCH_FAILED + 1))
                    else
                        # Valid JSON - append to points file
                        echo "$POINT" >> "$POINTS_FILE"
                        BATCH_SUCCESSFUL=$((BATCH_SUCCESSFUL + 1))
                        echo "      ✓ Point created"
                    fi
                fi

                EPISODE_INDEX=$((EPISODE_INDEX + 1))
            done < "$EPISODES_FILE"

            echo "  📊 Processed: $BATCH_SUCCESSFUL successful, $BATCH_FAILED failed"

            echo "✅ Created $BATCH_SUCCESSFUL points from embeddings"
        fi
    fi

    # Read accumulated points from file
    if [ -f "$POINTS_FILE" ]; then
        # Use file directly to avoid "Argument list too long"
        POINTS_COUNT=$(cat "$POINTS_FILE" | wc -l | tr -d ' ')

        if [ "$POINTS_COUNT" -gt 0 ]; then
            echo "📤 Batch uploading $POINTS_COUNT points to Qdrant..."

            # Create batch payload using file (avoid arg limit)
            cat "$POINTS_FILE" | jq -s '{points: .}' > "$PAYLOAD_FILE"
            BATCH_PAYLOAD=$(cat "$PAYLOAD_FILE")

            UPLOAD_RESPONSE=$(curl -s --max-time 120 -X PUT \
                "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points?wait=true" \
                -H "api-key: ${QDRANT_API_KEY}" \
                -H "Content-Type: application/json" \
                -d "$BATCH_PAYLOAD" 2>/dev/null)

            UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | jq -r '.status // "error"')

            if [ "$UPLOAD_STATUS" == "ok" ]; then
                TOTAL_SUCCESSFUL=$((TOTAL_SUCCESSFUL + POINTS_COUNT))
                echo "✅ Batch uploaded successfully ($POINTS_COUNT points)"

                # Update state
                jq -n \
                    --argjson lid "$MAX_ID" \
                    --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    '{last_synced_id: $lid, last_sync_time: $lts}' > "$SYNC_STATE_FILE"
            else
                TOTAL_FAILED=$((TOTAL_FAILED + POINTS_COUNT))
                echo "❌ Batch upload failed"
                echo "Response: $UPLOAD_RESPONSE"
            fi
        fi

        # Clean up batch temp files
        rm -f "$POINTS_FILE" "$REQUESTS_FILE" "$EPISODES_FILE" "$PAYLOAD_FILE"
    fi

    echo ""
done

# Final cleanup
rm -f "$POINTS_FILE" "$REQUESTS_FILE" "$EPISODES_FILE" "$PAYLOAD_FILE"

# Final report
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Sync Complete!"
echo "✅ Successful: ${TOTAL_SUCCESSFUL}"
echo "❌ Failed: ${TOTAL_FAILED}"
echo "📝 Last synced ID: $MAX_ID"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check remaining
REMAINING=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes WHERE id > $MAX_ID;" 2>/dev/null || echo "0")
if [ "$REMAINING" -gt 0 ]; then
    echo "ℹ️  $REMAINING episodes remaining. Run again to continue."
fi
