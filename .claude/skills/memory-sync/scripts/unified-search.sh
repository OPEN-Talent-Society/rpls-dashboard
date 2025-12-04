#!/bin/bash
# Unified search across all memory backends
# Usage: unified-search.sh "query" [--backend all|supabase|agentdb|cortex|swarm]
# Updated: 2025-12-02

set -e

QUERY="$1"
BACKEND="${2:-all}"
K="${3:-5}"

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Use anon key for reads (works without auth issues)
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY:-sb_publishable_BI1-ojV23xWqWShHnXAKLQ_P8-XP4oi}"

# Cortex config - uses CORTEX_TOKEN + Cloudflare Zero Trust headers
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_API_TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"

if [ -z "$QUERY" ]; then
    echo "Usage: unified-search.sh \"query\" [--backend all|supabase|agentdb|ruvector]"
    exit 1
fi

# URL-encode the query for HTTP requests
QUERY_ENCODED=$(echo "$QUERY" | sed 's/ /%20/g' | sed 's/"/%22/g')

echo "🔍 Searching: \"$QUERY\""
echo "   Backend: $BACKEND"
echo "   Results: $K per source"
echo ""

# Search Supabase
if [ "$BACKEND" = "all" ] || [ "$BACKEND" = "supabase" ]; then
    echo "┌─ Supabase Results ─────────────────────────────────────────────"

    # Search learnings (use URL-encoded query)
    echo "│ 📚 Learnings:"
    curl -s "${SUPABASE_URL}/rest/v1/learnings?or=(topic.ilike.*${QUERY_ENCODED}*,content.ilike.*${QUERY_ENCODED}*)&limit=${K}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" | \
        jq -r '.[] | "│   • \(.topic): \(.content | .[0:80])..."' 2>/dev/null || echo "│   (no results)"

    # Search patterns
    echo "│ 🎯 Patterns:"
    curl -s "${SUPABASE_URL}/rest/v1/patterns?or=(name.ilike.*${QUERY_ENCODED}*,description.ilike.*${QUERY_ENCODED}*)&limit=${K}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" | \
        jq -r '.[] | "│   • \(.name): \(.description | .[0:60])..."' 2>/dev/null || echo "│   (no results)"

    # Search agent_memory
    echo "│ 🧠 Agent Memory:"
    curl -s "${SUPABASE_URL}/rest/v1/agent_memory?key=ilike.*${QUERY_ENCODED}*&limit=${K}" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" | \
        jq -r '.[] | "│   • \(.key)"' 2>/dev/null || echo "│   (no results)"

    echo "└──────────────────────────────────────────────────────────────────"
    echo ""
fi

# Search AgentDB
if [ "$BACKEND" = "all" ] || [ "$BACKEND" = "agentdb" ]; then
    echo "┌─ AgentDB Results ──────────────────────────────────────────────"
    AGENTDB_PATH="$PROJECT_DIR/agentdb.db"
    if [ -f "$AGENTDB_PATH" ]; then
        sqlite3 "$AGENTDB_PATH" "SELECT '│   • ' || task || ': ' || substr(critique, 1, 60) || '...'
            FROM episodes
            WHERE task LIKE '%${QUERY}%' OR critique LIKE '%${QUERY}%'
            LIMIT ${K};" 2>/dev/null || echo "│   (no results)"
    else
        echo "│   (AgentDB not found)"
    fi
    echo "└──────────────────────────────────────────────────────────────────"
    echo ""
fi

# Search Swarm Memory
if [ "$BACKEND" = "all" ] || [ "$BACKEND" = "swarm" ]; then
    echo "┌─ Swarm Memory Results ───────────────────────────────────────────"
    SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
    if [ -f "$SWARM_DB" ]; then
        echo "│ 🐝 Patterns:"
        sqlite3 "$SWARM_DB" "SELECT '│   • [' || type || '] ' || substr(pattern_data, 1, 60) || '...'
            FROM patterns
            WHERE type LIKE '%${QUERY}%' OR pattern_data LIKE '%${QUERY}%'
            LIMIT ${K};" 2>/dev/null || echo "│   (no results)"
        echo "│"
        echo "│ 📊 Trajectories:"
        sqlite3 "$SWARM_DB" "SELECT '│   • [' || agent_id || '] ' || substr(query, 1, 60)
            FROM task_trajectories
            WHERE query LIKE '%${QUERY}%'
            LIMIT ${K};" 2>/dev/null || echo "│   (no results)"
    else
        echo "│   (Swarm DB not found)"
    fi
    echo "└──────────────────────────────────────────────────────────────────"
    echo ""
fi

# Search Cortex (SiYuan) - requires Cloudflare Zero Trust headers
if [ "$BACKEND" = "all" ] || [ "$BACKEND" = "cortex" ]; then
    echo "┌─ Cortex Knowledge Base ──────────────────────────────────────────"
    CORTEX_RESULTS=$(curl -s -X POST "${CORTEX_URL}/api/search/fullTextSearchBlock" \
        -H "Authorization: Token ${CORTEX_API_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"${QUERY}\"}" 2>/dev/null)

    if [ -n "$CORTEX_RESULTS" ] && [ "$CORTEX_RESULTS" != "{}" ]; then
        echo "$CORTEX_RESULTS" | jq -r '.data.blocks[0:'"$K"']? | .[]? | "│   • \(.content | .[0:70])..."' 2>/dev/null || echo "│   (no results)"
    else
        echo "│   (no results or Cortex unavailable)"
    fi
    echo "└──────────────────────────────────────────────────────────────────"
fi

echo ""
echo "✅ Search complete"
