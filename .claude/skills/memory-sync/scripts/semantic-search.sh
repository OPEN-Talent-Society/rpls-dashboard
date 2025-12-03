#!/bin/bash
# Semantic Search - Searches AgentDB episodes using keyword matching
# For true semantic search, use MCP tool: mcp__claude-flow__agentdb_pattern_search
# Usage: semantic-search.sh "query text" [limit]

set -e

QUERY="$1"
LIMIT="${2:-5}"
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
AGENTDB="$PROJECT_DIR/agentdb.db"
source "$PROJECT_DIR/.env" 2>/dev/null || true

if [ -z "$QUERY" ]; then
    echo "Usage: semantic-search.sh \"query text\" [limit]"
    echo ""
    echo "For true semantic search with embeddings, use MCP tool:"
    echo "  mcp__claude-flow__agentdb_pattern_search"
    exit 1
fi

echo "🔍 Memory Search: \"$QUERY\""
echo ""

# Search AgentDB episodes
echo "📋 AgentDB Episodes:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sqlite3 "$AGENTDB" "
SELECT
    '📝 ' || substr(task, 1, 70) || CASE WHEN length(task) > 70 THEN '...' ELSE '' END,
    '   ⭐ ' || reward || ' | ' || CASE success WHEN 1 THEN '✅' ELSE '❌' END,
    '   💡 ' || substr(COALESCE(critique, ''), 1, 80) || CASE WHEN length(critique) > 80 THEN '...' ELSE '' END,
    ''
FROM episodes
WHERE task LIKE '%${QUERY}%'
   OR critique LIKE '%${QUERY}%'
   OR input LIKE '%${QUERY}%'
   OR output LIKE '%${QUERY}%'
ORDER BY reward DESC
LIMIT $LIMIT;
" 2>/dev/null || echo "   No episodes found"

# Search Supabase patterns
echo ""
echo "🎯 Supabase Patterns:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
PATTERNS=$(curl -s "${PUBLIC_SUPABASE_URL}/rest/v1/patterns?or=(name.ilike.*${QUERY}*,description.ilike.*${QUERY}*)&select=name,description&limit=$LIMIT" \
    -H "apikey: ${PUBLIC_SUPABASE_ANON_KEY}" 2>/dev/null)

if [ -n "$PATTERNS" ] && [ "$PATTERNS" != "[]" ]; then
    echo "$PATTERNS" | jq -r '.[] | "📝 \(.name)\n   💡 \(.description | .[0:80])...\n"' 2>/dev/null
else
    echo "   No patterns found"
fi

# Search Supabase learnings
echo ""
echo "📚 Supabase Learnings:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
LEARNINGS=$(curl -s "${PUBLIC_SUPABASE_URL}/rest/v1/learnings?or=(topic.ilike.*${QUERY}*,content.ilike.*${QUERY}*)&select=topic,content,category&limit=$LIMIT" \
    -H "apikey: ${PUBLIC_SUPABASE_ANON_KEY}" 2>/dev/null)

if [ -n "$LEARNINGS" ] && [ "$LEARNINGS" != "[]" ]; then
    echo "$LEARNINGS" | jq -r '.[] | "📝 \(.topic) [\(.category)]\n   💡 \(.content | .[0:80])...\n"' 2>/dev/null
else
    echo "   No learnings found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 Tip: For true semantic search with embeddings, use MCP tool:"
echo "   mcp__claude-flow__agentdb_pattern_search"
echo "✅ Search complete"
