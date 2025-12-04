#!/bin/bash
# Pre-Task Memory Lookup - Search ALL memory sources before starting work
# Implements "Learn once, remember forever" with persistent storage
# Created: 2025-12-02

TASK_DESCRIPTION="$1"
TASK_CATEGORY="${2:-general}"

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

# Ensure .env is loaded with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi
# Skip if keys not set (non-blocking for hook)
[ -z "$QDRANT_API_KEY" ] && { echo "⚠️ QDRANT_API_KEY not set, skipping Qdrant search" >&2; }
[ -z "$GEMINI_API_KEY" ] && { echo "⚠️ GEMINI_API_KEY not set, skipping embedding" >&2; }

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL}"
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY}"

# Output file for context injection
CONTEXT_FILE="/tmp/pre-task-context.md"

echo "🧠 Pre-Task Memory Lookup" >&2
echo "   Query: ${TASK_DESCRIPTION:0:50}..." >&2

# Start building context
cat > "$CONTEXT_FILE" << 'HEADER'
## Relevant Context from Memory

HEADER

FOUND_ANYTHING=false

# 1. Search AgentDB for similar past episodes (using sqlite directly since MCP might not be available in hook)
AGENTDB="$PROJECT_DIR/agentdb.db"
if [ -f "$AGENTDB" ]; then
    EPISODES=$(sqlite3 "$AGENTDB" "SELECT task, reward, success, critique FROM episodes WHERE task LIKE '%${TASK_DESCRIPTION:0:30}%' OR critique LIKE '%${TASK_DESCRIPTION:0:30}%' ORDER BY reward DESC LIMIT 3;" 2>/dev/null)

    if [ -n "$EPISODES" ]; then
        FOUND_ANYTHING=true
        echo "### Past Similar Tasks (AgentDB)" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        echo "$EPISODES" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        echo "" >> "$CONTEXT_FILE"
        echo "  ✅ Found similar episodes in AgentDB" >&2
    fi
fi

# 2. Search Supabase learnings
LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?or=(topic.ilike.*${TASK_DESCRIPTION:0:20}*,content.ilike.*${TASK_DESCRIPTION:0:20}*)&select=topic,content,category&limit=3" \
    -H "apikey: ${SUPABASE_KEY}" 2>/dev/null)

if [ -n "$LEARNINGS" ] && [ "$LEARNINGS" != "[]" ]; then
    FOUND_ANYTHING=true
    echo "### Relevant Learnings (Supabase)" >> "$CONTEXT_FILE"
    echo "$LEARNINGS" | jq -r '.[] | "- **\(.topic)** (\(.category)): \(.content | .[0:200])..."' >> "$CONTEXT_FILE" 2>/dev/null
    echo "" >> "$CONTEXT_FILE"
    echo "  ✅ Found relevant learnings in Supabase" >&2
fi

# 3. Search Supabase patterns
PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?or=(name.ilike.*${TASK_DESCRIPTION:0:20}*,description.ilike.*${TASK_DESCRIPTION:0:20}*)&select=name,description,category&limit=3" \
    -H "apikey: ${SUPABASE_KEY}" 2>/dev/null)

if [ -n "$PATTERNS" ] && [ "$PATTERNS" != "[]" ]; then
    FOUND_ANYTHING=true
    echo "### Relevant Patterns (Supabase)" >> "$CONTEXT_FILE"
    echo "$PATTERNS" | jq -r '.[] | "- **\(.name)** (\(.category)): \(.description | .[0:150])..."' >> "$CONTEXT_FILE" 2>/dev/null
    echo "" >> "$CONTEXT_FILE"
    echo "  ✅ Found relevant patterns in Supabase" >&2
fi

# 4. Check Swarm Memory for recent trajectories
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
if [ -f "$SWARM_DB" ]; then
    TRAJECTORIES=$(sqlite3 "$SWARM_DB" "SELECT agent_id, query, judge_label FROM task_trajectories WHERE query LIKE '%${TASK_DESCRIPTION:0:20}%' ORDER BY created_at DESC LIMIT 2;" 2>/dev/null)

    if [ -n "$TRAJECTORIES" ]; then
        FOUND_ANYTHING=true
        echo "### Recent Swarm Trajectories" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        echo "$TRAJECTORIES" >> "$CONTEXT_FILE"
        echo '```' >> "$CONTEXT_FILE"
        echo "" >> "$CONTEXT_FILE"
        echo "  ✅ Found swarm trajectories" >&2
    fi
fi

# 5. Search Cortex (SiYuan) knowledge base
# Cloudflare Zero Trust headers required
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
CORTEX_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
CORTEX_TOKEN="${CORTEX_TOKEN}"

CORTEX_RESULTS=$(curl -s -X POST "${CORTEX_URL}/api/search/fullTextSearchBlock" \
    -H "Authorization: Token ${CORTEX_TOKEN}" \
    -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"${TASK_DESCRIPTION:0:30}\"}" 2>/dev/null)

if [ -n "$CORTEX_RESULTS" ] && [ "$CORTEX_RESULTS" != "{}" ]; then
    BLOCKS=$(echo "$CORTEX_RESULTS" | jq -r '.data.blocks[0:3]? | .[]? | .content | .[0:100]' 2>/dev/null)
    if [ -n "$BLOCKS" ]; then
        FOUND_ANYTHING=true
        echo "### Cortex Knowledge Base" >> "$CONTEXT_FILE"
        echo "$CORTEX_RESULTS" | jq -r '.data.blocks[0:3]? | .[]? | "- \(.content | .[0:150])..."' >> "$CONTEXT_FILE" 2>/dev/null
        echo "" >> "$CONTEXT_FILE"
        echo "  ✅ Found Cortex knowledge" >&2
    fi
fi

# 6. Semantic search via Qdrant (persistent vector DB)
# STANDARD: Uses Gemini text-embedding-004 (768 dims) for all searches.
# This is our PRIMARY approach. MCP server with FastEmbed is a fallback only.
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
QDRANT_API_KEY="${QDRANT_API_KEY:-}"
if [ -z "$QDRANT_API_KEY" ]; then
    echo "Warning: QDRANT_API_KEY not set, Qdrant requests may fail" >&2
fi
QDRANT_COLLECTION="${QDRANT_COLLECTION:-agent_memory}"
GEMINI_KEY="${GEMINI_API_KEY}"

if [ -n "$GEMINI_KEY" ]; then
    # Get embedding for query using Gemini (768 dimensions)
    # STANDARD: All Qdrant collections are created with 768 dimensions for Gemini compatibility
    QUERY_TEXT=$(echo "$TASK_DESCRIPTION" | head -c 2000 | jq -Rs '.')
    EMBEDDING_RESPONSE=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/text-embedding-004\",
            \"content\": {\"parts\": [{\"text\": $QUERY_TEXT}]}
        }" 2>/dev/null)

    EMBEDDING=$(echo "$EMBEDDING_RESPONSE" | jq -c '.embedding.values // empty')

    if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
        # Search Qdrant for similar vectors using 768-dim Gemini embeddings
        # All collections are standardized to use 768 dimensions
        QDRANT_RESULTS=$(curl -s -X POST "${QDRANT_URL}/collections/${QDRANT_COLLECTION}/points/search" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{
                \"vector\": $EMBEDDING,
                \"limit\": 5,
                \"with_payload\": true
            }" 2>/dev/null)

        if [ -n "$QDRANT_RESULTS" ]; then
            HITS=$(echo "$QDRANT_RESULTS" | jq -r '.result[]? | select(.score > 0.35) | "- [\(.payload.type)] \(.payload.topic // .payload.name // .payload.key) (score: \(.score | . * 100 | floor / 100))"' 2>/dev/null | head -5)

            if [ -n "$HITS" ]; then
                FOUND_ANYTHING=true
                echo "### Semantic Search (Qdrant)" >> "$CONTEXT_FILE"
                echo "$HITS" >> "$CONTEXT_FILE"
                echo "" >> "$CONTEXT_FILE"
                echo "  ✅ Found semantically similar memories" >&2
            fi
        fi
    fi
fi

# 7. Search Hive-Mind memory (per-project and root)
for HIVE_PATH in "$PROJECT_DIR/.hive-mind/memory.json" "$PROJECT_DIR/project-campfire/.hive-mind/memory.json"; do
    if [ -f "$HIVE_PATH" ]; then
        # Search knowledge_base
        HIVE_KB=$(cat "$HIVE_PATH" | jq -r '.knowledge_base[]? | select(.content | test("'"${TASK_DESCRIPTION:0:20}"'"; "i")) | "- \(.topic // .key): \(.content | .[0:100])..."' 2>/dev/null | head -3)

        # Search tasks
        HIVE_TASKS=$(cat "$HIVE_PATH" | jq -r '.tasks[]? | select(.description | test("'"${TASK_DESCRIPTION:0:20}"'"; "i")) | "- [\(.status)] \(.description | .[0:80])..."' 2>/dev/null | head -3)

        if [ -n "$HIVE_KB" ] || [ -n "$HIVE_TASKS" ]; then
            FOUND_ANYTHING=true
            echo "### Hive-Mind Memory" >> "$CONTEXT_FILE"
            [ -n "$HIVE_KB" ] && echo "$HIVE_KB" >> "$CONTEXT_FILE"
            [ -n "$HIVE_TASKS" ] && echo "$HIVE_TASKS" >> "$CONTEXT_FILE"
            echo "" >> "$CONTEXT_FILE"
            echo "  ✅ Found Hive-Mind context" >&2
        fi
        break  # Only check first found
    fi
done

# Output result
if [ "$FOUND_ANYTHING" = true ]; then
    echo "" >&2
    echo "📋 Context available at: $CONTEXT_FILE" >&2
    # Output context to stdout for potential injection
    cat "$CONTEXT_FILE"
else
    echo "" >&2
    echo "ℹ️  No existing context found. Starting fresh." >&2
    echo "NO_CONTEXT_FOUND"
fi
