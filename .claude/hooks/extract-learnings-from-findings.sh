#!/bin/bash
# Extract Learnings and Patterns from Session Findings
# Bridge hook that analyzes findings and triggers log-learning/save-pattern
# Created: 2025-12-01

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh" 2>/dev/null || true

SESSION_FILE="${1:-/tmp/claude-session-${CLAUDE_VARIANT:-claude-code}.json}"

echo "=== LEARNING/PATTERN EXTRACTION ===" >&2

if [ ! -f "$SESSION_FILE" ]; then
    echo "No session file found at: $SESSION_FILE" >&2
    exit 0
fi

# Check for jq
if ! command -v jq &> /dev/null; then
    echo "jq not found, skipping extraction" >&2
    exit 0
fi

# Extract findings and analyze for learning potential
FINDINGS=$(jq -r '.findings // []' "$SESSION_FILE" 2>/dev/null)
if [ "$FINDINGS" == "[]" ] || [ "$FINDINGS" == "null" ]; then
    echo "No findings to analyze" >&2
    exit 0
fi

FINDINGS_COUNT=$(jq '.findings | length' "$SESSION_FILE" 2>/dev/null || echo "0")
echo "Analyzing $FINDINGS_COUNT findings..." >&2

# Pattern detection keywords
LEARNING_KEYWORDS="discovered|learned|found|realized|understood|identified|noticed|observed|confirmed"
PATTERN_KEYWORDS="pattern|approach|method|strategy|workflow|process|technique|best practice|template"
ERROR_KEYWORDS="error|bug|issue|problem|failed|fixed|resolved|solution"

# Process each finding
jq -c '.findings[]?' "$SESSION_FILE" 2>/dev/null | while read -r finding; do
    TYPE=$(echo "$finding" | jq -r '.type // "general"')
    CONTENT=$(echo "$finding" | jq -r '.content // .description // .message // ""')
    TIMESTAMP=$(echo "$finding" | jq -r '.timestamp // ""')

    if [ -z "$CONTENT" ] || [ "$CONTENT" == "null" ]; then
        continue
    fi

    # Check if finding should be a learning
    if echo "$CONTENT" | grep -iEq "$LEARNING_KEYWORDS|$ERROR_KEYWORDS"; then
        echo "  [Learning detected] $TYPE" >&2

        # Generate topic from content
        TOPIC=$(echo "$CONTENT" | head -c 100 | sed 's/[^a-zA-Z0-9 ]//g' | xargs)
        CATEGORY="session-discovery"

        # Check for error resolution pattern
        if echo "$CONTENT" | grep -iEq "$ERROR_KEYWORDS"; then
            CATEGORY="error-resolution"
        fi

        # Log as learning
        "$SCRIPT_DIR/log-learning.sh" "$TOPIC" "$CATEGORY" "$CONTENT" '["automated","extracted","session"]' 2>/dev/null || true
    fi

    # Check if finding should be a pattern
    if echo "$CONTENT" | grep -iEq "$PATTERN_KEYWORDS"; then
        echo "  [Pattern detected] $TYPE" >&2

        # Generate pattern name
        NAME=$(echo "$CONTENT" | head -c 50 | sed 's/[^a-zA-Z0-9 ]//g' | xargs)

        # Save as pattern
        "$SCRIPT_DIR/save-pattern.sh" "$NAME" "extracted" "$CONTENT" '["automated","extracted"]' '{}' 2>/dev/null || true
    fi
done

echo "Extraction complete." >&2
