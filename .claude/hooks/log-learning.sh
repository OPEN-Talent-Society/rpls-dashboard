#!/bin/bash
# Log Learning Hook: Capture learnings with deduplication
# Implements "Log learnings, fix problems, prevent recurrence" principle

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

LEARNING_TOPIC="$1"
LEARNING_CONTENT="$2"
LEARNING_CATEGORY="${3:-general}"
CONTEXT="${4:-}"

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LEARNING_HASH=$(echo "${LEARNING_CONTENT}" | md5 | cut -c1-16)

# Check for duplicate learnings in LOCAL file storage first (most reliable)
echo "Checking for duplicate learnings..."

SCRIPT_DIR_DUP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTDB_FILE_DUP="${SCRIPT_DIR_DUP}/../.agentdb/learnings.json"

if [ -f "$AGENTDB_FILE_DUP" ] && command -v jq >/dev/null 2>&1; then
  EXISTING_LOCAL=$(jq -r --arg hash "learning-${LEARNING_HASH}" '.entries[] | select(.id == $hash) | .id' "$AGENTDB_FILE_DUP" 2>/dev/null)
  if [ -n "$EXISTING_LOCAL" ]; then
    echo "Similar learning already exists in local storage: $EXISTING_LOCAL"
    echo "Skipping duplicate storage. Consider updating existing learning instead."
    exit 0
  fi
fi

# Load .env for Supabase check
CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"
if [ -f "${CODEBUILD_ROOT}/.env" ]; then
  source "${CODEBUILD_ROOT}/.env"
fi

# Also check Supabase if available (for cloud dedup)
if [ -n "$SUPABASE_ACCESS_TOKEN" ]; then
  EXISTING_CLOUD=$(curl -s -X POST "https://api.supabase.com/v1/projects/zxcrbcmdxpqprpxhsntc/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"SELECT learning_id FROM learnings WHERE learning_id = 'learning-${LEARNING_HASH}' LIMIT 1;\"}" 2>/dev/null)
  if echo "$EXISTING_CLOUD" | grep -q "learning-${LEARNING_HASH}"; then
    echo "Learning already exists in Supabase cloud storage"
    echo "Skipping duplicate storage."
    exit 0
  fi
fi

# Store the learning in AgentDB
pnpm dlx claude-flow memory store \
  --namespace "learnings" \
  --key "learnings/${LEARNING_CATEGORY}/${LEARNING_HASH}" \
  --value "{
    \"topic\": \"$LEARNING_TOPIC\",
    \"content\": \"$LEARNING_CONTENT\",
    \"category\": \"$LEARNING_CATEGORY\",
    \"context\": \"$CONTEXT\",
    \"timestamp\": \"$TIMESTAMP\",
    \"agent\": \"${CLAUDE_VARIANT:-claude-code}\",
    \"agent_email\": \"${CLAUDE_AGENT_EMAIL:-claude-code@aienablement.academy}\"
  }" \
  --ttl $((30 * 24 * 60 * 60))

echo "Learning logged: learnings/${LEARNING_CATEGORY}/${LEARNING_HASH}"

# PERSISTENT STORAGE: Write to file-based AgentDB
AGENTDB_FILE="${SCRIPT_DIR}/../.agentdb/learnings.json"
if [ -f "$AGENTDB_FILE" ]; then
  # Create new entry
  NEW_ENTRY=$(cat <<ENTRY
{
  "id": "learning-${LEARNING_HASH}",
  "timestamp": "${TIMESTAMP}",
  "topic": "${LEARNING_TOPIC}",
  "category": "${LEARNING_CATEGORY}",
  "agent": "${CLAUDE_VARIANT:-claude-code}",
  "content": $(echo "$LEARNING_CONTENT" | jq -Rs .),
  "tags": ["${LEARNING_CATEGORY}", "automated"],
  "related_docs": []
}
ENTRY
)
  # Append to entries array using jq
  if command -v jq >/dev/null 2>&1; then
    TMP_FILE=$(mktemp)
    jq --argjson entry "$NEW_ENTRY" '.entries += [$entry] | .updated = "'"${TIMESTAMP}"'"' "$AGENTDB_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$AGENTDB_FILE"
    echo "Persistent storage updated: $AGENTDB_FILE"
  fi
fi

# Create Cortex document for human visibility
echo "Creating Cortex learning document..."
CORTEX_DOC=$(cat <<EOF
---
title: "Learning - ${LEARNING_TOPIC}"
created: ${TIMESTAMP}
type: learning
agent: ${CLAUDE_VARIANT:-claude-code}
category: ${LEARNING_CATEGORY}
tags: [learning, ${LEARNING_CATEGORY}, automated]
---

# ${LEARNING_TOPIC}

## Context
${CONTEXT}

## Key Learning
${LEARNING_CONTENT}

## Metadata
- **Category**: ${LEARNING_CATEGORY}
- **Agent**: ${CLAUDE_VARIANT:-claude-code}
- **Logged**: ${TIMESTAMP}

#learning #${LEARNING_CATEGORY} #automated

{: custom-type="learning" custom-category="${LEARNING_CATEGORY}" custom-agent="${CLAUDE_VARIANT:-claude-code}" }
EOF
)

echo "Learning document created for Cortex sync."

# CLOUD STORAGE: Write to Supabase
# Load credentials from .env
CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"
if [ -f "${CODEBUILD_ROOT}/.env" ]; then
  source "${CODEBUILD_ROOT}/.env"
fi

if [ -n "$SUPABASE_ACCESS_TOKEN" ]; then
  echo "Writing to Supabase cloud storage..."

  # Escape content for JSON
  ESCAPED_CONTENT=$(echo "$LEARNING_CONTENT" | jq -Rs . | sed 's/^"//;s/"$//')
  ESCAPED_TOPIC=$(echo "$LEARNING_TOPIC" | jq -Rs . | sed 's/^"//;s/"$//')
  ESCAPED_CONTEXT=$(echo "$CONTEXT" | jq -Rs . | sed 's/^"//;s/"$//')

  SUPABASE_QUERY=$(cat <<EOSQL
INSERT INTO learnings (learning_id, topic, category, content, context, agent_id, agent_email, tags)
VALUES ('learning-${LEARNING_HASH}', '${ESCAPED_TOPIC}', '${LEARNING_CATEGORY}', '${ESCAPED_CONTENT}', '${ESCAPED_CONTEXT}', '${CLAUDE_VARIANT:-claude-code}', '${CLAUDE_AGENT_EMAIL:-claude-code@aienablement.academy}', ARRAY['${LEARNING_CATEGORY}', 'automated'])
ON CONFLICT (learning_id) DO UPDATE SET
  content = EXCLUDED.content,
  context = EXCLUDED.context,
  updated_at = NOW()
RETURNING id, learning_id;
EOSQL
)

  # Create JSON payload
  jq -n --arg query "$SUPABASE_QUERY" '{"query": $query}' > /tmp/supabase_learning.json

  # Execute query
  SUPABASE_RESULT=$(curl -s -X POST "https://api.supabase.com/v1/projects/zxcrbcmdxpqprpxhsntc/database/query" \
    -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
    -H "Content-Type: application/json" \
    -d @/tmp/supabase_learning.json 2>&1)

  if echo "$SUPABASE_RESULT" | grep -q '"id"'; then
    echo "✅ Supabase cloud storage updated successfully"
  else
    echo "⚠️ Supabase write may have failed: $SUPABASE_RESULT"
  fi

  rm -f /tmp/supabase_learning.json
else
  echo "⚠️ SUPABASE_ACCESS_TOKEN not set, skipping cloud storage"
fi
