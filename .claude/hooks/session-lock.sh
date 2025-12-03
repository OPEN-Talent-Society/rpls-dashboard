#!/bin/bash
# Session Lock - Prevent parallel session conflicts
# Creates advisory lock file with session info
# Created: 2025-12-02

ACTION="${1:-check}"  # check, acquire, release
LOCK_FILE="/tmp/claude-code-session.lock"
SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

case "$ACTION" in
    check)
        if [ -f "$LOCK_FILE" ]; then
            LOCK_AGE=$(($(date +%s) - $(stat -f %m "$LOCK_FILE" 2>/dev/null || echo "0")))
            LOCK_SESSION=$(cat "$LOCK_FILE" 2>/dev/null | jq -r '.session_id // "unknown"')
            LOCK_PROJECT=$(cat "$LOCK_FILE" 2>/dev/null | jq -r '.project // "unknown"')

            # Lock expires after 1 hour of inactivity
            if [ "$LOCK_AGE" -lt 3600 ]; then
                echo "WARNING: Another session is active"
                echo "  Session: $LOCK_SESSION"
                echo "  Project: $LOCK_PROJECT"
                echo "  Age: ${LOCK_AGE}s"
                echo ""
                echo "Hot memory may have conflicts. Consider:"
                echo "  1. Wait for other session to finish"
                echo "  2. Use different project folder"
                echo "  3. Force acquire: session-lock.sh acquire --force"
                exit 1
            fi
        fi
        echo "NO_LOCK"
        ;;

    acquire)
        FORCE="${2:-}"
        if [ -f "$LOCK_FILE" ] && [ "$FORCE" != "--force" ]; then
            ./$0 check
            exit $?
        fi

        jq -n \
            --arg sid "$SESSION_ID" \
            --arg proj "$PROJECT_DIR" \
            --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --arg pid "$$" \
            '{
                session_id: $sid,
                project: $proj,
                started_at: $time,
                pid: $pid
            }' > "$LOCK_FILE"

        echo "LOCK_ACQUIRED"
        echo "  Session: $SESSION_ID"
        ;;

    release)
        if [ -f "$LOCK_FILE" ]; then
            rm -f "$LOCK_FILE"
            echo "LOCK_RELEASED"
        else
            echo "NO_LOCK_TO_RELEASE"
        fi
        ;;

    *)
        echo "Usage: session-lock.sh [check|acquire|release] [--force]"
        exit 1
        ;;
esac
