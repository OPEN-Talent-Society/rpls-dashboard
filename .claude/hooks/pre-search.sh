#!/bin/bash
# Pre-Search Hook: Check for cached searches before performing new ones
# Implements "Don't search for same things twice" principle

SEARCH_QUERY="$1"
SEARCH_TYPE="${2:-general}"

# Generate hash for this search
QUERY_HASH=$(echo "${SEARCH_TYPE}:${SEARCH_QUERY}" | md5 | cut -c1-12)

# Check if we've searched this before
CACHED_RESULT=$(npx claude-flow memory search \
  --pattern "searches/${SEARCH_TYPE}/${QUERY_HASH}*" \
  --limit 1 2>/dev/null)

if [ -n "$CACHED_RESULT" ] && [ "$CACHED_RESULT" != "[]" ]; then
  echo "CACHE_HIT"
  echo "Found cached search result:"
  echo "$CACHED_RESULT"
  exit 0
fi

echo "CACHE_MISS"
# Caller should perform search and then call post-search.sh to cache
