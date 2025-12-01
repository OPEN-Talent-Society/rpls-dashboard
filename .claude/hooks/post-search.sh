#!/bin/bash
# Post-Search Hook: Cache search results for future reuse
# Implements "Don't search for same things twice" principle

SEARCH_QUERY="$1"
SEARCH_RESULT="$2"
SEARCH_TYPE="${3:-general}"
TTL_DAYS="${4:-7}"

# Generate hash for this search
QUERY_HASH=$(echo "${SEARCH_TYPE}:${SEARCH_QUERY}" | md5 | cut -c1-12)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Store the search result
npx claude-flow memory store \
  --namespace "searches" \
  --key "searches/${SEARCH_TYPE}/${QUERY_HASH}" \
  --value "{
    \"query\": \"$SEARCH_QUERY\",
    \"type\": \"$SEARCH_TYPE\",
    \"result\": $SEARCH_RESULT,
    \"timestamp\": \"$TIMESTAMP\",
    \"agent\": \"${CLAUDE_VARIANT:-claude-code}\",
    \"ttl_days\": $TTL_DAYS
  }" \
  --ttl $((TTL_DAYS * 24 * 60 * 60))

echo "Search cached: ${SEARCH_TYPE}/${QUERY_HASH}"
