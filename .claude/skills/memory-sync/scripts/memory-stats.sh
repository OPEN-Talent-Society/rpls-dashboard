#!/bin/bash
# Show memory statistics across all backends
# Usage: memory-stats.sh

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
# Use anon key which is available, fallback to service role key
SUPABASE_KEY="${PUBLIC_SUPABASE_ANON_KEY:-${SUPABASE_SERVICE_ROLE_KEY}}"

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              UNIFIED MEMORY STATISTICS                       ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# AgentDB Stats
echo "┌─ AgentDB/ReasoningBank (Local SQLite) ────────────────────────"
AGENTDB_PATH="$PROJECT_DIR/agentdb.db"
if [ -f "$AGENTDB_PATH" ]; then
    EPISODES=$(sqlite3 "$AGENTDB_PATH" "SELECT COUNT(*) FROM episodes;" 2>/dev/null || echo "0")
    SIZE=$(du -h "$AGENTDB_PATH" 2>/dev/null | cut -f1)
    echo "│  Episodes: $EPISODES"
    echo "│  Size: $SIZE"
    echo "│  Path: $AGENTDB_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Swarm Memory Stats
echo "┌─ Swarm Memory (Local SQLite) ─────────────────────────────────"
SWARM_PATH="$PROJECT_DIR/.swarm/memory.db"
if [ -f "$SWARM_PATH" ]; then
    SIZE=$(du -h "$SWARM_PATH" 2>/dev/null | cut -f1)
    echo "│  Size: $SIZE"
    echo "│  Path: $SWARM_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Hive-Mind Memory Stats
echo "┌─ Hive-Mind Memory (Local JSON) ───────────────────────────────"
HIVE_PATH="$PROJECT_DIR/project-campfire/.hive-mind/memory.json"
if [ -f "$HIVE_PATH" ]; then
    SIZE=$(du -h "$HIVE_PATH" 2>/dev/null | cut -f1)
    KEYS=$(jq 'keys | length' "$HIVE_PATH" 2>/dev/null || echo "0")
    echo "│  Keys: $KEYS"
    echo "│  Size: $SIZE"
    echo "│  Path: $HIVE_PATH"
else
    echo "│  Status: Not found"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Supabase Stats
echo "┌─ Supabase (Cloud PostgreSQL) ─────────────────────────────────"
if [ -n "$SUPABASE_KEY" ]; then
    PATTERNS=$(curl -s "${SUPABASE_URL}/rest/v1/patterns?select=id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact" | jq 'length' 2>/dev/null || echo "?")
    LEARNINGS=$(curl -s "${SUPABASE_URL}/rest/v1/learnings?select=id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact" | jq 'length' 2>/dev/null || echo "?")
    MEMORIES=$(curl -s "${SUPABASE_URL}/rest/v1/agent_memory?select=id" \
        -H "apikey: ${SUPABASE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_KEY}" \
        -H "Prefer: count=exact" | jq 'length' 2>/dev/null || echo "?")
    echo "│  patterns table: $PATTERNS records"
    echo "│  learnings table: $LEARNINGS records"
    echo "│  agent_memory table: $MEMORIES records"
    echo "│  URL: $SUPABASE_URL"
else
    echo "│  Status: Not configured (missing SUPABASE_SERVICE_ROLE_KEY)"
fi
echo "└──────────────────────────────────────────────────────────────"
echo ""

# RuVector Stats
echo "┌─ RuVector (Vector Search) ────────────────────────────────────"
RUVECTOR_VERSION=$(pnpm dlx ruvector --version 2>/dev/null || echo "Not installed")
echo "│  Version: $RUVECTOR_VERSION"
pnpm dlx ruvector stats --collection agent_memory 2>/dev/null || echo "│  Collection: Not initialized"
echo "└──────────────────────────────────────────────────────────────"
echo ""

# Qdrant Stats
echo "┌─ Qdrant (Semantic Layer) ─────────────────────────────────────"
QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"
# Fix: Use HTTPS and API key for Qdrant
QDRANT_URL_HTTPS="${QDRANT_URL/http:/https:}"
for collection in agent_memory learnings patterns codebase; do
    COUNT=$(curl -s "${QDRANT_URL_HTTPS}/collections/${collection}" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.points_count // 0' 2>/dev/null)
    if [ "$COUNT" = "0" ] || [ -z "$COUNT" ] || [ "$COUNT" = "null" ]; then
        echo "│  $collection: Not initialized"
    else
        echo "│  $collection: $COUNT vectors"
    fi
done
echo "│  URL: $QDRANT_URL_HTTPS"
echo "└──────────────────────────────────────────────────────────────"
echo ""

echo "Run 'sync-all.sh' to synchronize all backends"
