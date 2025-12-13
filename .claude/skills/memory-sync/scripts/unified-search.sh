#!/bin/bash
# Unified search across all memory backends with semantic search and recency ranking
# Usage: unified-search.sh "query" [--backend all|supabase|agentdb|cortex|swarm|qdrant]
# Updated: 2025-12-10

set -e

QUERY="$1"
BACKEND="${2:-all}"
K="${3:-5}"
RECENCY_BOOST="${4:-true}"  # Boost recent results

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Use anon key for reads (works without auth issues)
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY:-}"
[ -z "$SUPABASE_KEY" ] && SUPABASE_KEY="${SUPABASE_ANON_KEY:-}"

# Cortex config - uses CORTEX_TOKEN + Cloudflare Zero Trust Service Token
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_API_TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"

# Qdrant config
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
GEMINI_API_KEY="${GOOGLE_GEMINI_API_KEY:-$GEMINI_API_KEY}"
EMBEDDING_MODEL="gemini-embedding-001"

# Generate embedding for semantic search
generate_embedding() {
    local text="$1"
    local escaped_text=$(echo -n "$text" | jq -Rs '.')

    local response=$(curl -s --max-time 15 \
        "https://generativelanguage.googleapis.com/v1beta/models/${EMBEDDING_MODEL}:embedContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' \
        -d "{
            \"model\": \"models/${EMBEDDING_MODEL}\",
            \"content\": {\"parts\":[{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" 2>/dev/null)

    echo "$response" | jq -c '.embedding.values'
}

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

# Search Qdrant (Semantic Vector Search with Recency Ranking)
if [ "$BACKEND" = "all" ] || [ "$BACKEND" = "qdrant" ]; then
    echo "┌─ Qdrant Semantic Search ─────────────────────────────────────────"

    if [ -z "$GEMINI_API_KEY" ] || [ -z "$QDRANT_API_KEY" ]; then
        echo "│   (Qdrant/Gemini API keys not configured)"
    else
        # Generate query embedding
        echo "│ 🔮 Generating embedding..."
        QUERY_EMBEDDING=$(generate_embedding "$QUERY")

        if [ -n "$QUERY_EMBEDDING" ] && [ "$QUERY_EMBEDDING" != "null" ] && [ "$QUERY_EMBEDDING" != "[]" ]; then
            # Collections to search
            COLLECTIONS=("agent_memory" "codebase" "patterns" "learnings" "cortex" "research" "transcripts" "clients" "communications")

            for COLLECTION in "${COLLECTIONS[@]}"; do
                # Check if collection exists and has vectors
                COL_INFO=$(curl -s "${QDRANT_URL}/collections/${COLLECTION}" \
                    -H "api-key: ${QDRANT_API_KEY}" 2>/dev/null)
                POINT_COUNT=$(echo "$COL_INFO" | jq -r '.result.points_count // 0' 2>/dev/null)

                if [ "$POINT_COUNT" -gt 0 ]; then
                    echo "│"
                    echo "│ 📁 ${COLLECTION} (${POINT_COUNT} vectors):"

                    # Search with recency scoring
                    # We fetch more results than K to allow for recency re-ranking
                    FETCH_K=$((K * 2))
                    RESULTS=$(curl -s -X POST "${QDRANT_URL}/collections/${COLLECTION}/points/search" \
                        -H "api-key: ${QDRANT_API_KEY}" \
                        -H "Content-Type: application/json" \
                        -d "{
                            \"vector\": ${QUERY_EMBEDDING},
                            \"limit\": ${FETCH_K},
                            \"with_payload\": true,
                            \"with_vector\": false
                        }" 2>/dev/null)

                    # Process results with smart recency boost
                    if [ "$RECENCY_BOOST" = "true" ]; then
                        # Recency boost with UNIVERSAL TRUTH preservation:
                        # - High similarity (>0.85) items are NEVER penalized (universal truths)
                        # - Medium similarity (0.7-0.85) gets mild recency boost
                        # - Lower similarity gets stronger recency preference
                        # This ensures foundational knowledge is preserved while
                        # preferring recent info for evolving topics
                        echo "$RESULTS" | python3 -c "
import sys, json
from datetime import datetime, timezone

try:
    data = json.load(sys.stdin)
    results = data.get('result', [])
    now = datetime.now(timezone.utc)

    scored_results = []
    for r in results:
        sim_score = r.get('score', 0)
        payload = r.get('payload', {})
        indexed_at = payload.get('indexed_at', '')
        content_type = payload.get('type', '')

        # SMART RECENCY: Don't penalize high-similarity matches (universal truths)
        # High similarity = query and content are very close semantically
        # These are likely foundational facts, not time-sensitive info

        recency_factor = 1.0  # default - no penalty

        # Only apply recency decay for medium/low similarity matches
        # High similarity (>0.85): NO recency penalty - universal truths preserved
        # Medium similarity (0.7-0.85): Mild recency factor (0.95 floor)
        # Lower similarity (<0.7): Stronger recency preference (0.85 floor)

        if sim_score < 0.85 and indexed_at:
            try:
                dt = datetime.fromisoformat(indexed_at.replace('Z', '+00:00'))
                days_old = (now - dt).days

                if sim_score >= 0.7:
                    # Medium similarity: mild recency preference
                    if days_old < 7:
                        recency_factor = 1.0
                    elif days_old < 30:
                        recency_factor = 0.98
                    elif days_old < 90:
                        recency_factor = 0.96
                    else:
                        recency_factor = 0.95  # floor for medium similarity
                else:
                    # Lower similarity: stronger recency preference
                    if days_old < 7:
                        recency_factor = 1.0
                    elif days_old < 30:
                        recency_factor = 0.95
                    elif days_old < 90:
                        recency_factor = 0.90
                    else:
                        recency_factor = 0.85  # floor for lower similarity
            except:
                pass

        combined_score = sim_score * recency_factor
        scored_results.append((combined_score, sim_score, recency_factor, payload, indexed_at))

    # Sort by combined score and take top K
    scored_results.sort(key=lambda x: x[0], reverse=True)

    for i, (combined, sim, recency, payload, indexed_at) in enumerate(scored_results[:${K}]):
        content = payload.get('content', payload.get('topic', payload.get('task', 'N/A')))
        content_preview = (content[:60] + '...') if len(str(content)) > 60 else content
        file_path = payload.get('file_path', payload.get('source', ''))
        cortex_url = payload.get('cortex_url', '')
        date_str = indexed_at[:10] if indexed_at else 'N/A'
        print(f'│   • [{date_str}] (sim:{sim:.2f} rec:{recency:.2f}) {content_preview}')
        if cortex_url:
            print(f'│     └─ {cortex_url}')
        elif file_path:
            print(f'│     └─ {file_path}')
except Exception as e:
    print(f'│   (error: {e})')
" 2>/dev/null || echo "│   (no results or parse error)"
                    else
                        # Simple display without recency boost
                        echo "$RESULTS" | jq -r '.result[0:'"$K"']? | .[]? | "│   • [\(.score | tostring[0:4])] \(.payload.content // .payload.topic // .payload.task | .[0:60])..."' 2>/dev/null || echo "│   (no results)"
                    fi
                fi
            done
        else
            echo "│   (failed to generate query embedding)"
        fi
    fi

    echo "└──────────────────────────────────────────────────────────────────"
fi

echo ""
echo "✅ Search complete (recency boost: $RECENCY_BOOST)"
