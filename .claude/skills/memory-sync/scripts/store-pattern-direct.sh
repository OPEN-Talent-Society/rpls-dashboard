#!/bin/bash
# Direct pattern storage to AgentDB SQLite - Workaround for __dirname CLI issue
# Usage: store-pattern-direct.sh <session_id> <task> <reward> <success> [critique] [input] [output]
#
# This bypasses the broken AgentDB CLI (npx agentdb) which fails with:
#   "❌ __dirname is not defined"
#
# The CLI issue is an ESM vs CommonJS compatibility problem in the agentdb package.
# This script writes directly to the SQLite database instead.

set -e

# Paths
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
AGENTDB_PATH="${PROJECT_DIR}/agentdb.db"

# Validate required args
if [ $# -lt 4 ]; then
    echo "Usage: store-pattern-direct.sh <session_id> <task> <reward> <success> [critique] [input] [output]"
    echo ""
    echo "Arguments:"
    echo "  session_id  - Unique identifier for this session (e.g., 'e2.1-recordings')"
    echo "  task        - Description of what was accomplished"
    echo "  reward      - Success score 0.0-1.0 (e.g., 0.95)"
    echo "  success     - Boolean: 1=success, 0=failure"
    echo "  critique    - (optional) Self-reflection on approach"
    echo "  input       - (optional) Input/context for the task"
    echo "  output      - (optional) Output/result description"
    exit 1
fi

SESSION_ID="$1"
TASK="$2"
REWARD="$3"
SUCCESS="$4"
CRITIQUE="${5:-}"
INPUT="${6:-}"
OUTPUT="${7:-}"

# Validate database exists
if [ ! -f "$AGENTDB_PATH" ]; then
    echo "❌ AgentDB not found at: $AGENTDB_PATH"
    exit 1
fi

# Generate timestamp
TS=$(date +%s)
CREATED_AT=$(date -u '+%Y-%m-%d %H:%M:%S')

# Escape single quotes for SQL
escape_sql() {
    echo "$1" | sed "s/'/''/g"
}

SESSION_ID_ESC=$(escape_sql "$SESSION_ID")
TASK_ESC=$(escape_sql "$TASK")
CRITIQUE_ESC=$(escape_sql "$CRITIQUE")
INPUT_ESC=$(escape_sql "$INPUT")
OUTPUT_ESC=$(escape_sql "$OUTPUT")

# Insert into AgentDB
sqlite3 "$AGENTDB_PATH" <<EOF
INSERT INTO episodes (ts, session_id, task, input, output, critique, reward, success, created_at)
VALUES ($TS, '$SESSION_ID_ESC', '$TASK_ESC', '$INPUT_ESC', '$OUTPUT_ESC', '$CRITIQUE_ESC', $REWARD, $SUCCESS, '$CREATED_AT');
EOF

if [ $? -eq 0 ]; then
    # Get the inserted ID
    NEW_ID=$(sqlite3 "$AGENTDB_PATH" "SELECT MAX(id) FROM episodes;")
    echo "✅ Pattern stored successfully (ID: $NEW_ID)"
    echo "   Session: $SESSION_ID"
    echo "   Task: $TASK"
    echo "   Reward: $REWARD | Success: $SUCCESS"
else
    echo "❌ Failed to store pattern"
    exit 1
fi
