#!/bin/bash
# Load .env with exports
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Save Pattern Hook: Store successful solutions as reusable patterns
# Implements "Build higher-level capabilities over time" principle

PATTERN_NAME="$1"
PATTERN_CATEGORY="$2"
PROBLEM_PATTERN="$3"
SOLUTION_TEMPLATE="$4"
PREREQUISITES="${5:-}"
CAVEATS="${6:-}"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
PATTERN_ID=$(echo "${PATTERN_CATEGORY}:${PATTERN_NAME}" | md5 | cut -c1-12)

# Check for duplicate patterns
EXISTING=$(/opt/homebrew/bin/claude-flow memory search \
  --namespace "patterns" \
  --pattern "patterns/${PATTERN_CATEGORY}/${PATTERN_ID}*" \
  --limit 1 2>/dev/null)

if [ -n "$EXISTING" ] && [ "$EXISTING" != "[]" ]; then
  echo "Pattern already exists: ${PATTERN_CATEGORY}/${PATTERN_ID}"
  echo "Updating with new information..."
fi

# Store the pattern
/opt/homebrew/bin/claude-flow memory store \
  --namespace "patterns" \
  --key "patterns/${PATTERN_CATEGORY}/${PATTERN_ID}" \
  --value "{
    \"id\": \"$PATTERN_ID\",
    \"name\": \"$PATTERN_NAME\",
    \"category\": \"$PATTERN_CATEGORY\",
    \"problem_pattern\": \"$PROBLEM_PATTERN\",
    \"solution_template\": \"$SOLUTION_TEMPLATE\",
    \"prerequisites\": \"$PREREQUISITES\",
    \"caveats\": \"$CAVEATS\",
    \"timestamp\": \"$TIMESTAMP\",
    \"agent\": \"${CLAUDE_VARIANT:-claude-code}\",
    \"usage_count\": 0
  }"

echo "Pattern saved: patterns/${PATTERN_CATEGORY}/${PATTERN_ID}"
echo "This solution is now available for future similar problems."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# LOCAL FILE STORAGE: Write to file-based AgentDB (ALWAYS - works offline)
AGENTDB_FILE="$PROJECT_DIR/.agentdb/patterns.json"
if [ -f "$AGENTDB_FILE" ]; then
  echo "Writing to local file storage (offline backup)..."
  NEW_ENTRY=$(cat <<ENTRY
{
  "id": "pattern-${PATTERN_ID}",
  "hash": "${PATTERN_ID}",
  "name": $(echo "$PATTERN_NAME" | jq -Rs .),
  "category": "${PATTERN_CATEGORY}",
  "description": $(echo "$PREREQUISITES $CAVEATS" | jq -Rs .),
  "template": {
    "problem": $(echo "$PROBLEM_PATTERN" | jq -Rs .),
    "solution": $(echo "$SOLUTION_TEMPLATE" | jq -Rs .)
  },
  "use_cases": ["${PATTERN_CATEGORY}", "automated"],
  "timestamp": "${TIMESTAMP}",
  "agent": "${CLAUDE_VARIANT:-claude-code}"
}
ENTRY
)
  if command -v jq >/dev/null 2>&1; then
    TMP_FILE=$(mktemp)
    jq --argjson entry "$NEW_ENTRY" '.patterns += [$entry] | .updated = "'"${TIMESTAMP}"'"' "$AGENTDB_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$AGENTDB_FILE"
    echo "✅ Local file storage updated: $AGENTDB_FILE"
  fi
else
  echo "⚠️ Local patterns file not found, creating..."
  mkdir -p "${SCRIPT_DIR}/../.agentdb"
  echo '{"version":"1.0.0","created":"'"${TIMESTAMP}"'","updated":"'"${TIMESTAMP}"'","patterns":[]}' > "$AGENTDB_FILE"
fi

# CLOUD STORAGE: Write to Supabase (when online)
CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"
if [ -f "${CODEBUILD_ROOT}/.env" ]; then
  source "${CODEBUILD_ROOT}/.env"
fi

if [ -n "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "Writing pattern to Supabase cloud storage..."

  # Escape content for JSON
  ESCAPED_NAME=$(echo "$PATTERN_NAME" | jq -Rs . | sed 's/^"//;s/"$//')
  ESCAPED_PROBLEM=$(echo "$PROBLEM_PATTERN" | jq -Rs . | sed 's/^"//;s/"$//')
  ESCAPED_SOLUTION=$(echo "$SOLUTION_TEMPLATE" | jq -Rs . | sed 's/^"//;s/"$//')
  ESCAPED_DESC=$(echo "$PREREQUISITES $CAVEATS" | jq -Rs . | sed 's/^"//;s/"$//')

  SUPABASE_QUERY=$(cat <<EOSQL
INSERT INTO patterns (pattern_id, name, category, description, template, use_cases)
VALUES ('pattern-${PATTERN_ID}', '${ESCAPED_NAME}', '${PATTERN_CATEGORY}', '${ESCAPED_DESC}', '{"problem": "${ESCAPED_PROBLEM}", "solution": "${ESCAPED_SOLUTION}"}', ARRAY['${PATTERN_CATEGORY}', 'automated'])
ON CONFLICT (pattern_id) DO UPDATE SET
  template = EXCLUDED.template,
  success_count = patterns.success_count + 1,
  updated_at = NOW()
RETURNING id, pattern_id;
EOSQL
)

  jq -n --arg query "$SUPABASE_QUERY" '{"query": $query}' > /tmp/supabase_pattern.json

  SUPABASE_RESULT=$(curl -s -X POST "https://api.supabase.com/v1/projects/zxcrbcmdxpqprpxhsntc/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/supabase_pattern.json 2>&1)

  if echo "$SUPABASE_RESULT" | grep -q '"id"'; then
    echo "✅ Supabase cloud storage updated successfully"
  else
    echo "⚠️ Supabase write may have failed: $SUPABASE_RESULT"
  fi

  rm -f /tmp/supabase_pattern.json
else
  echo "⚠️ SUPABASE_ACCESS_TOKEN not set, skipping cloud storage"
fi
