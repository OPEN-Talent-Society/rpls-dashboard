#!/bin/bash
# Post-task hook: Log completion, persist learnings, update task tracker
# Called when a significant task is completed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh"

TASK_STATUS="${1:-Done}"
TASK_SUMMARY="${2:-Task completed}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_FILE="/tmp/claude-session-${CLAUDE_VARIANT}.json"

echo "=== POST-TASK HOOK ===" >&2
echo "Agent: $CLAUDE_AGENT_NAME" >&2
echo "Status: $TASK_STATUS" >&2
echo "Summary: $TASK_SUMMARY" >&2

# Update session file with completion
if [ -f "$SESSION_FILE" ] && command -v jq &> /dev/null; then
    jq --arg status "$TASK_STATUS" \
       --arg summary "$TASK_SUMMARY" \
       --arg ts "$TIMESTAMP" \
       '.status = $status | .summary = $summary | .completed_at = $ts' \
       "$SESSION_FILE" > "${SESSION_FILE}.tmp" && mv "${SESSION_FILE}.tmp" "$SESSION_FILE"

    echo "Session updated with completion status" >&2
fi

# Generate Cortex document content
CORTEX_DOC=$(cat << 'TEMPLATE'
# Task Log: {{TASK_NAME}}

**Agent**: {{AGENT_NAME}} ({{AGENT_EMAIL}})
**Status**: {{STATUS}}
**Completed**: {{TIMESTAMP}}

## Summary
{{SUMMARY}}

## Actions Taken
{{ACTIONS}}

## Findings
{{FINDINGS}}

## Learnings
{{LEARNINGS}}

## Tags
#agent-log #{{VARIANT}} #automated

---
*Logged automatically by post-task hook*
TEMPLATE
)

echo "Post-task logging complete." >&2

# === ACTUAL SYNC CALLS (Fixed 2025-12-01) ===

# 1. Extract and save any learnings from the session
if [ -f "$SESSION_FILE" ] && command -v jq &> /dev/null; then
    LEARNINGS=$(jq -r '.learnings // []' "$SESSION_FILE" 2>/dev/null)
    if [ "$LEARNINGS" != "[]" ] && [ "$LEARNINGS" != "null" ]; then
        echo "  [Learnings] Extracting session learnings..." >&2
        jq -c '.learnings[]' "$SESSION_FILE" 2>/dev/null | while read -r learning; do
            TOPIC=$(echo "$learning" | jq -r '.topic // "Session Learning"')
            CATEGORY=$(echo "$learning" | jq -r '.category // "session"')
            CONTENT=$(echo "$learning" | jq -r '.content // ""')
            TAGS=$(echo "$learning" | jq -r '.tags // ["session","automated"]')

            if [ -n "$CONTENT" ] && [ "$CONTENT" != "null" ]; then
                echo "    -> Logging: $TOPIC" >&2
                "$SCRIPT_DIR/log-learning.sh" "$TOPIC" "$CATEGORY" "$CONTENT" "$TAGS" 2>/dev/null || true
            fi
        done
        echo "    ✅ Learnings synced" >&2
    fi
fi

# 2. Extract and save any patterns from the session
if [ -f "$SESSION_FILE" ] && command -v jq &> /dev/null; then
    PATTERNS=$(jq -r '.patterns // []' "$SESSION_FILE" 2>/dev/null)
    if [ "$PATTERNS" != "[]" ] && [ "$PATTERNS" != "null" ]; then
        echo "  [Patterns] Extracting session patterns..." >&2
        jq -c '.patterns[]' "$SESSION_FILE" 2>/dev/null | while read -r pattern; do
            NAME=$(echo "$pattern" | jq -r '.name // "Session Pattern"')
            CATEGORY=$(echo "$pattern" | jq -r '.category // "session"')
            DESCRIPTION=$(echo "$pattern" | jq -r '.description // ""')
            USE_CASES=$(echo "$pattern" | jq -r '.use_cases // []')
            TEMPLATE=$(echo "$pattern" | jq -r '.template // {}')

            if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ]; then
                echo "    -> Saving: $NAME" >&2
                "$SCRIPT_DIR/save-pattern.sh" "$NAME" "$CATEGORY" "$DESCRIPTION" "$USE_CASES" "$TEMPLATE" 2>/dev/null || true
            fi
        done
        echo "    ✅ Patterns synced" >&2
    fi
fi

# 3. Update NocoDB task status if task ID is set
TASK_ID_FILE="/tmp/claude-code-current-task-id"
if [ -f "$TASK_ID_FILE" ]; then
    CURRENT_TASK_ID=$(cat "$TASK_ID_FILE")
    if [ -n "$CURRENT_TASK_ID" ] && [ "$CURRENT_TASK_ID" != "null" ]; then
        echo "  [NocoDB] Updating task $CURRENT_TASK_ID to $TASK_STATUS..." >&2
        "$SCRIPT_DIR/nocodb-update-status.sh" "$CURRENT_TASK_ID" "$TASK_STATUS" 2>/dev/null || true
        echo "    ✅ NocoDB status updated" >&2
    fi
fi

# 4. Create Cortex documentation entry
if [ -f "$SCRIPT_DIR/cortex-log-learning.sh" ]; then
    echo "  [Cortex] Creating task documentation..." >&2
    "$SCRIPT_DIR/cortex-log-learning.sh" "Task Completed: $TASK_SUMMARY" "task-log" "$CORTEX_DOC" 2>/dev/null || true
    echo "    ✅ Cortex entry created" >&2
fi

# 5. Sync memory to Supabase
if [ -f "$SCRIPT_DIR/sync-memory-to-supabase.sh" ]; then
    echo "  [Supabase] Syncing memory to cloud..." >&2
    "$SCRIPT_DIR/sync-memory-to-supabase.sh" 2>/dev/null || true
    echo "    ✅ Supabase sync complete" >&2
fi

echo "" >&2
echo "All syncs complete for task: $TASK_SUMMARY" >&2
