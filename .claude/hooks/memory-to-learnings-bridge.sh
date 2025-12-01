#!/bin/bash
# Memory to Learnings/Patterns Bridge Hook
# Automatically triggers learnings/patterns extraction when memory is stored
# Created: 2025-12-01
# Purpose: Bridge the gap between memory operations and learning/pattern capture

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh" 2>/dev/null || true

# Input parameters
MEMORY_KEY="${1:-}"
MEMORY_VALUE="${2:-}"
MEMORY_NAMESPACE="${3:-default}"

echo "=== MEMORY-TO-LEARNINGS BRIDGE ===" >&2
echo "Key: $MEMORY_KEY" >&2
echo "Namespace: $MEMORY_NAMESPACE" >&2

# Keywords that indicate this memory should become a learning
LEARNING_TRIGGERS="learning|discovery|insight|finding|realized|understood|solution|resolved|fixed"
# Keywords that indicate this memory should become a pattern
PATTERN_TRIGGERS="pattern|approach|method|strategy|workflow|process|technique|template|architecture|structure"

# Namespaces that always trigger learning extraction
LEARNING_NAMESPACES="learnings|discoveries|insights|findings|solutions"
# Namespaces that always trigger pattern extraction
PATTERN_NAMESPACES="patterns|approaches|methods|strategies|workflows|architectures"

# Check if namespace triggers learning
if echo "$MEMORY_NAMESPACE" | grep -iEq "$LEARNING_NAMESPACES"; then
    echo "  [Namespace match] Triggering learning extraction..." >&2

    TOPIC=$(echo "$MEMORY_KEY" | sed 's/:/ - /g' | sed 's/-/ /g')
    CATEGORY="memory-extracted"

    "$SCRIPT_DIR/log-learning.sh" "$TOPIC" "$CATEGORY" "$MEMORY_VALUE" '["memory-bridge","automated"]' 2>/dev/null || true
    echo "  ✅ Learning logged from memory" >&2
fi

# Check if namespace triggers pattern
if echo "$MEMORY_NAMESPACE" | grep -iEq "$PATTERN_NAMESPACES"; then
    echo "  [Namespace match] Triggering pattern extraction..." >&2

    NAME=$(echo "$MEMORY_KEY" | sed 's/:/ - /g' | sed 's/-/ /g')

    "$SCRIPT_DIR/save-pattern.sh" "$NAME" "memory-extracted" "$MEMORY_VALUE" '["memory-bridge","automated"]' '{}' 2>/dev/null || true
    echo "  ✅ Pattern saved from memory" >&2
fi

# Check if content triggers learning
if echo "$MEMORY_VALUE" | grep -iEq "$LEARNING_TRIGGERS"; then
    echo "  [Content match] Found learning-like content..." >&2

    TOPIC=$(echo "$MEMORY_KEY" | sed 's/:/ - /g' | sed 's/-/ /g')
    CATEGORY="content-analysis"

    "$SCRIPT_DIR/log-learning.sh" "$TOPIC" "$CATEGORY" "$MEMORY_VALUE" '["content-detected","automated"]' 2>/dev/null || true
    echo "  ✅ Learning extracted from content" >&2
fi

# Check if content triggers pattern
if echo "$MEMORY_VALUE" | grep -iEq "$PATTERN_TRIGGERS"; then
    echo "  [Content match] Found pattern-like content..." >&2

    NAME=$(echo "$MEMORY_KEY" | sed 's/:/ - /g' | sed 's/-/ /g')

    "$SCRIPT_DIR/save-pattern.sh" "$NAME" "content-analysis" "$MEMORY_VALUE" '["content-detected","automated"]' '{}' 2>/dev/null || true
    echo "  ✅ Pattern extracted from content" >&2
fi

# Log the bridge operation
BRIDGE_LOG="/tmp/memory-bridge-log.json"
if command -v jq &> /dev/null; then
    jq -n \
        --arg key "$MEMORY_KEY" \
        --arg namespace "$MEMORY_NAMESPACE" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            key: $key,
            namespace: $namespace,
            processed_at: $timestamp,
            bridge_type: "memory-to-learnings"
        }' >> "$BRIDGE_LOG" 2>/dev/null || true
fi

echo "Bridge processing complete." >&2
