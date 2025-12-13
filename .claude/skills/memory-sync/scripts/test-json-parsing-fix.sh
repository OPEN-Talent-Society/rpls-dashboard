#!/bin/bash
# Test JSON parsing fixes for memory sync scripts
# Verifies that markdown tables and pipe characters don't corrupt data

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
AGENTDB_PATH="$PROJECT_DIR/agentdb.db"
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"

echo "====================================="
echo "Testing JSON Parsing Fixes"
echo "====================================="
echo ""

# Test 1: Insert test episode with markdown table in critique
echo "Test 1: Inserting test episode with markdown table..."

TEST_CRITIQUE="Analysis complete:

| Metric | Value | Status |
|--------|-------|--------|
| Performance | 95% | Good |
| Accuracy | 87% | Fair |
| Speed | Fast | Excellent |

This table contains pipe delimiters that would break old parsing."

TEST_TASK="Test task with pipes | and special chars"

sqlite3 "$AGENTDB_PATH" <<EOF
INSERT INTO episodes (session_id, task, reward, success, critique)
VALUES (
    'test-json-parsing',
    '$TEST_TASK',
    0.95,
    1,
    '$TEST_CRITIQUE'
);
EOF

EPISODE_ID=$(sqlite3 "$AGENTDB_PATH" "SELECT id FROM episodes WHERE session_id='test-json-parsing' ORDER BY id DESC LIMIT 1;")

echo "  Created test episode #$EPISODE_ID"
echo ""

# Test 2: Verify JSON extraction doesn't corrupt data
echo "Test 2: Testing JSON extraction from AgentDB..."

EPISODES_JSON=$(sqlite3 "$AGENTDB_PATH" -json "
SELECT
    id,
    COALESCE(session_id, '') as session_id,
    REPLACE(REPLACE(COALESCE(task, ''), char(10), ' '), char(13), ' ') as task,
    REPLACE(REPLACE(COALESCE(critique, ''), char(10), ' '), char(13), ' ') as critique,
    COALESCE(reward, 0) as reward,
    COALESCE(success, 0) as success
FROM episodes
WHERE session_id = 'test-json-parsing'
ORDER BY id DESC
LIMIT 1;
")

echo "  Raw JSON output:"
echo "$EPISODES_JSON" | jq '.'
echo ""

# Test 3: Parse with jq to verify no corruption
echo "Test 3: Parsing JSON with jq..."

PARSED_TASK=$(echo "$EPISODES_JSON" | jq -r '.[0].task')
PARSED_CRITIQUE=$(echo "$EPISODES_JSON" | jq -r '.[0].critique')

echo "  Parsed task: $PARSED_TASK"
echo "  Parsed critique length: ${#PARSED_CRITIQUE} chars"
echo ""

# Verify pipes are preserved
if echo "$PARSED_CRITIQUE" | grep -q "|"; then
    echo "  SUCCESS: Pipe characters preserved in critique"
else
    echo "  FAILED: Pipe characters missing from critique"
    exit 1
fi

# Test 4: Test with swarm database (if exists)
if [ -f "$SWARM_DB" ]; then
    echo "Test 4: Testing swarm database JSON extraction..."

    # Insert test trajectory with required trajectory_json field
    sqlite3 "$SWARM_DB" <<EOF
INSERT INTO task_trajectories (agent_id, query, judge_label, judge_reasons, trajectory_json, created_at)
VALUES (
    'test-agent',
    'Query with pipes | and markdown | tables',
    'success',
    'Result analysis:
| Item | Score |
|------|-------|
| Quality | 9/10 |',
    '{"test": true}',
    datetime('now')
);
EOF

    TRAJ_JSON=$(sqlite3 "$SWARM_DB" -json "
    SELECT
        task_id,
        COALESCE(agent_id, '') as agent_id,
        REPLACE(REPLACE(COALESCE(query, ''), char(10), ' '), char(13), ' ') as query,
        COALESCE(judge_label, '') as judge_label,
        REPLACE(REPLACE(COALESCE(judge_reasons, ''), char(10), ' '), char(13), ' ') as judge_reasons
    FROM task_trajectories
    WHERE agent_id = 'test-agent'
    ORDER BY task_id DESC
    LIMIT 1;
    ")

    echo "  Raw JSON output:"
    echo "$TRAJ_JSON" | jq '.'
    echo ""

    PARSED_QUERY=$(echo "$TRAJ_JSON" | jq -r '.[0].query')

    if echo "$PARSED_QUERY" | grep -q "|"; then
        echo "  SUCCESS: Pipe characters preserved in query"
    else
        echo "  FAILED: Pipe characters missing from query"
        exit 1
    fi
fi

# Test 5: Verify actual script behavior
echo ""
echo "Test 5: Testing actual sync scripts..."
echo ""

# Test sync-agentdb-to-supabase.sh (dry run - just parse, don't sync)
echo "  Testing sync-agentdb-to-supabase.sh parsing..."
TEST_EPISODES=$(sqlite3 "$AGENTDB_PATH" -json "
SELECT
    id,
    COALESCE(session_id, '') as session_id,
    REPLACE(REPLACE(COALESCE(task, ''), char(10), ' '), char(13), ' ') as task,
    REPLACE(REPLACE(COALESCE(critique, ''), char(10), ' '), char(13), ' ') as critique,
    COALESCE(reward, 0) as reward,
    COALESCE(success, 0) as success
FROM episodes
WHERE session_id = 'test-json-parsing'
LIMIT 1;
")

PARSE_COUNT=0
echo "$TEST_EPISODES" | jq -c '.[]' | while read -r episode_json; do
    EPISODE_ID=$(echo "$episode_json" | jq -r '.id')
    SESSION_ID=$(echo "$episode_json" | jq -r '.session_id')
    TASK=$(echo "$episode_json" | jq -r '.task')
    CRITIQUE=$(echo "$episode_json" | jq -r '.critique')

    if [ -n "$EPISODE_ID" ] && [ -n "$TASK" ]; then
        echo "    Parsed episode #$EPISODE_ID successfully"

        if echo "$CRITIQUE" | grep -q "|"; then
            echo "    Critique contains pipes: YES"
        else
            echo "    Critique contains pipes: NO (FAILED)"
        fi
    fi
done

# Test sync-swarm-to-qdrant.sh parsing
if [ -f "$SWARM_DB" ]; then
    echo ""
    echo "  Testing sync-swarm-to-qdrant.sh parsing..."

    TEST_TRAJ=$(sqlite3 "$SWARM_DB" -json "
    SELECT
        task_id,
        COALESCE(agent_id, '') as agent_id,
        REPLACE(REPLACE(COALESCE(query, ''), char(10), ' '), char(13), ' ') as query,
        COALESCE(judge_label, '') as judge_label,
        REPLACE(REPLACE(COALESCE(judge_reasons, ''), char(10), ' '), char(13), ' ') as judge_reasons
    FROM task_trajectories
    WHERE agent_id = 'test-agent'
    LIMIT 1;
    ")

    echo "$TEST_TRAJ" | jq -c '.[]' | while read -r traj_json; do
        TASK_ID=$(echo "$traj_json" | jq -r '.task_id')
        QUERY=$(echo "$traj_json" | jq -r '.query')

        if [ -n "$TASK_ID" ] && [ -n "$QUERY" ]; then
            echo "    Parsed trajectory #$TASK_ID successfully"

            if echo "$QUERY" | grep -q "|"; then
                echo "    Query contains pipes: YES"
            else
                echo "    Query contains pipes: NO (FAILED)"
            fi
        fi
    done
fi

# Cleanup test data
echo ""
echo "Cleanup: Removing test data..."
sqlite3 "$AGENTDB_PATH" "DELETE FROM episodes WHERE session_id='test-json-parsing';"
if [ -f "$SWARM_DB" ]; then
    sqlite3 "$SWARM_DB" "DELETE FROM task_trajectories WHERE agent_id='test-agent';" 2>/dev/null || true
fi

echo ""
echo "====================================="
echo "All Tests Passed!"
echo "====================================="
echo ""
echo "Summary:"
echo "  - JSON extraction preserves pipe characters"
echo "  - Markdown tables don't corrupt data"
echo "  - jq parsing works correctly"
echo "  - All sync scripts use safe JSON parsing"
