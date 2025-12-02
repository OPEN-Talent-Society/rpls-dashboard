#!/bin/bash
# Check Existing Solution Hook: Look for patterns before solving
# Implements "Learn once, remember forever" principle

PROBLEM_DESCRIPTION="$1"
PROBLEM_CATEGORY="${2:-general}"

echo "Checking for existing solutions..."

# Search patterns namespace for similar problems
PATTERNS=$(pnpm dlx claude-flow memory search \
  --namespace "patterns" \
  --pattern "patterns/${PROBLEM_CATEGORY}/*" \
  --limit 5 2>/dev/null)

if [ -n "$PATTERNS" ] && [ "$PATTERNS" != "[]" ]; then
  echo "FOUND_PATTERNS"
  echo "Existing patterns that may help:"
  echo "$PATTERNS"
  echo ""
fi

# Search for relevant error resolutions
ERRORS=$(pnpm dlx claude-flow memory search \
  --namespace "errors" \
  --pattern "errors/*" \
  --limit 3 2>/dev/null)

if [ -n "$ERRORS" ] && [ "$ERRORS" != "[]" ]; then
  echo "FOUND_ERRORS"
  echo "Relevant past errors to avoid:"
  echo "$ERRORS"
  echo ""
fi

# Search for related learnings
LEARNINGS=$(pnpm dlx claude-flow memory search \
  --namespace "learnings" \
  --pattern "learnings/*" \
  --limit 3 2>/dev/null)

if [ -n "$LEARNINGS" ] && [ "$LEARNINGS" != "[]" ]; then
  echo "FOUND_LEARNINGS"
  echo "Related learnings:"
  echo "$LEARNINGS"
fi

# If nothing found
if [ -z "$PATTERNS" ] && [ -z "$ERRORS" ] && [ -z "$LEARNINGS" ]; then
  echo "NO_EXISTING_SOLUTION"
  echo "No existing solutions found. Proceed with investigation."
fi
