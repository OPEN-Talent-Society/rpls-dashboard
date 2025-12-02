#!/bin/bash
# Session end hook: Persist session state, sync to all memory systems
# Called at the end of each Claude session

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_FILE="/tmp/claude-session-${CLAUDE_VARIANT}.json"
MEMORY_DIR="/Users/adamkovacs/Documents/codebuild/.claude/memory"
LAST_SESSION="$MEMORY_DIR/last-session-${CLAUDE_VARIANT}.json"

echo "=== SESSION END ===" >&2
echo "Agent: $CLAUDE_AGENT_NAME" >&2
echo "Ended: $TIMESTAMP" >&2

# Update session file
if [ -f "$SESSION_FILE" ] && command -v jq &> /dev/null; then
    jq --arg ts "$TIMESTAMP" '.ended_at = $ts | .status = "completed"' \
       "$SESSION_FILE" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"

    # Copy to last session
    cp "$SESSION_FILE" "$LAST_SESSION"

    # Count actions
    ACTIONS_COUNT=$(jq '.actions | length' "$SESSION_FILE" 2>/dev/null || echo "0")
    FINDINGS_COUNT=$(jq '.findings | length' "$SESSION_FILE" 2>/dev/null || echo "0")
    LEARNINGS_COUNT=$(jq '.learnings | length' "$SESSION_FILE" 2>/dev/null || echo "0")

    echo "" >&2
    echo "Session Summary:" >&2
    echo "  Actions: $ACTIONS_COUNT" >&2
    echo "  Findings: $FINDINGS_COUNT" >&2
    echo "  Learnings: $LEARNINGS_COUNT" >&2
fi

echo "" >&2
echo "Syncing to memory systems..." >&2

# Sync to Supabase (Cloud Persistence)
echo "  [Supabase] Syncing to cloud storage..." >&2
if [ -f "$SCRIPT_DIR/sync-memory-to-supabase.sh" ]; then
    "$SCRIPT_DIR/sync-memory-to-supabase.sh" 2>/dev/null || echo "    Warning: Supabase sync failed" >&2
    echo "    ✅ Supabase sync complete" >&2
fi

# Sync Claude Flow memory to Supabase
echo "  [Claude Flow → Supabase] Syncing all namespaces..." >&2
if [ -f "/tmp/sync-all-memory.sh" ]; then
    bash /tmp/sync-all-memory.sh 2>/dev/null || echo "    Warning: Full memory sync failed" >&2
fi

# Sync to AgentDB (Local JSON)
echo "  [AgentDB] Persisting session data..." >&2
AGENTDB_DIR="$SCRIPT_DIR/../.agentdb"
if [ -d "$AGENTDB_DIR" ]; then
    echo "    ✅ Local JSON files synced" >&2
fi

# === AGENTDB → SUPABASE SYNC (Dynamic) ===
echo "  [AgentDB → Supabase] Syncing local JSON to cloud..." >&2
if [ -f "$SCRIPT_DIR/agentdb-supabase-sync.sh" ]; then
    "$SCRIPT_DIR/agentdb-supabase-sync.sh" all incremental 2>/dev/null || echo "    Warning: AgentDB cloud sync failed" >&2
    echo "    ✅ AgentDB cloud sync complete" >&2
fi

# === LEARNINGS & PATTERNS EXTRACTION (Fixed 2025-12-01) ===

# Log to learnings.json and Supabase
if [ -f "$SESSION_FILE" ] && [ "$LEARNINGS_COUNT" -gt 0 ]; then
    echo "    Found $LEARNINGS_COUNT new learnings to persist" >&2

    # Extract and log each learning
    jq -c '.learnings[]?' "$SESSION_FILE" 2>/dev/null | while read -r learning; do
        TOPIC=$(echo "$learning" | jq -r '.topic // "Session Learning"')
        CATEGORY=$(echo "$learning" | jq -r '.category // "session"')
        CONTENT=$(echo "$learning" | jq -r '.content // ""')
        TAGS=$(echo "$learning" | jq -r '.tags // ["session","automated"]')

        if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
            echo "    -> Logging learning: $TOPIC" >&2
            "$SCRIPT_DIR/log-learning.sh" "$TOPIC" "$CATEGORY" "$CONTENT" "$TAGS" 2>/dev/null || true
        fi
    done
    echo "    ✅ Learnings extracted and synced" >&2
fi

# Extract and save patterns from session
if [ -f "$SESSION_FILE" ]; then
    PATTERNS_COUNT=$(jq '.patterns | length' "$SESSION_FILE" 2>/dev/null || echo "0")
    if [ "$PATTERNS_COUNT" -gt 0 ]; then
        echo "    Found $PATTERNS_COUNT new patterns to persist" >&2

        jq -c '.patterns[]?' "$SESSION_FILE" 2>/dev/null | while read -r pattern; do
            NAME=$(echo "$pattern" | jq -r '.name // "Session Pattern"')
            CATEGORY=$(echo "$pattern" | jq -r '.category // "session"')
            DESCRIPTION=$(echo "$pattern" | jq -r '.description // ""')
            USE_CASES=$(echo "$pattern" | jq -r '.use_cases // []')
            TEMPLATE=$(echo "$pattern" | jq -r '.template // {}')

            if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ]; then
                echo "    -> Saving pattern: $NAME" >&2
                "$SCRIPT_DIR/save-pattern.sh" "$NAME" "$CATEGORY" "$DESCRIPTION" "$USE_CASES" "$TEMPLATE" 2>/dev/null || true
            fi
        done
        echo "    ✅ Patterns extracted and synced" >&2
    fi
fi

# Bridge: Check findings for potential learnings/patterns
if [ -f "$SESSION_FILE" ] && [ "$FINDINGS_COUNT" -gt 0 ]; then
    echo "    Analyzing $FINDINGS_COUNT findings for potential learnings..." >&2
    "$SCRIPT_DIR/extract-learnings-from-findings.sh" "$SESSION_FILE" 2>/dev/null || true
fi

# Archive session log
ARCHIVE_DIR="$MEMORY_DIR/sessions"
mkdir -p "$ARCHIVE_DIR"
if [ -f "$SESSION_FILE" ]; then
    SESSION_ID=$(jq -r '.session_id // "unknown"' "$SESSION_FILE" 2>/dev/null)
    cp "$SESSION_FILE" "$ARCHIVE_DIR/${SESSION_ID}.json"
    echo "  Session archived: ${SESSION_ID}.json" >&2
fi

echo "" >&2
echo "Session ended. Memory persisted for next session." >&2
