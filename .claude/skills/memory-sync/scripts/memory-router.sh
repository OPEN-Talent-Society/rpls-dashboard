#!/bin/bash
# Memory Router - Smart multi-directional sync with deduplication
# Routes content to optimal destinations based on type
# Features: change tracking, content hashing, timeout safety, no duplicates, batch processing
# Created: 2025-12-11
#
# FLOW DESIGN:
# ✅ AgentDB → Qdrant (semantic search)
# ✅ AgentDB → Supabase (cold storage)
# ✅ AgentDB → Cortex (high-value learnings, documentation, deep research)
# ✅ Supabase Learnings → Qdrant + Cortex
# ✅ Swarm → Qdrant (ephemeral patterns)
# ❌ Cortex → AgentDB (NOT needed - search works directly in Cortex)
#
# BATCH PROCESSING: Groups items into batches of BATCH_SIZE for efficient bulk operations

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
SCRIPT_DIR="$PROJECT_DIR/.claude/skills/memory-sync/scripts"

# Load environment
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# State files for change tracking
STATE_DIR="/tmp/memory-router-state"
mkdir -p "$STATE_DIR"
CONTENT_HASHES="$STATE_DIR/content-hashes.txt"
SYNC_LOG="$STATE_DIR/sync.log"

# Touch hash file if not exists
touch "$CONTENT_HASHES"

# Batch processing config
BATCH_SIZE=${BATCH_SIZE:-20}          # Items per batch
BATCH_TIMEOUT=${BATCH_TIMEOUT:-120}   # Max seconds per batch
PARALLEL_WRITES=${PARALLEL_WRITES:-5} # Concurrent API calls

# ============================================
# TIMEOUT WRAPPER (macOS compatible)
# ============================================
run_with_timeout() {
    local timeout_seconds=$1
    shift

    # Run command in background
    "$@" &
    local pid=$!

    # Start timeout killer in background
    (sleep $timeout_seconds && kill $pid 2>/dev/null) &
    local killer_pid=$!

    # Wait for command
    wait $pid 2>/dev/null
    local exit_code=$?

    # Kill the killer if command finished
    kill $killer_pid 2>/dev/null || true

    return $exit_code
}

# ============================================
# CONTENT HASHING (Deduplication)
# ============================================
compute_content_hash() {
    local content="$1"
    echo -n "$content" | md5 -q 2>/dev/null || echo -n "$content" | md5sum | cut -d' ' -f1
}

content_exists() {
    local hash="$1"
    grep -q "^$hash$" "$CONTENT_HASHES" 2>/dev/null
}

mark_content_synced() {
    local hash="$1"
    echo "$hash" >> "$CONTENT_HASHES"
}

# ============================================
# GEMINI EMBEDDING (Single function, reusable)
# Uses gemini-embedding-001 with outputDimensionality=768
# ============================================
get_embedding() {
    local text="$1"
    local max_len=8000

    # Truncate if too long
    text=$(echo "$text" | head -c $max_len)

    # Escape for JSON
    local escaped=$(echo "$text" | jq -Rs '.')

    # Use gemini-embedding-001 with 768 dimensions (matches Qdrant collections)
    local response=$(curl -s --max-time 30 \
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\":\"models/gemini-embedding-001\",
            \"content\":{\"parts\":[{\"text\":$escaped}]},
            \"outputDimensionality\": 768
        }")

    echo "$response" | jq -c '.embedding.values // empty'
}

# ============================================
# DESTINATION WRITERS
# ============================================

write_to_qdrant() {
    local collection="$1"
    local id="$2"
    local content="$3"
    local payload="$4"

    # Get embedding
    local embedding=$(get_embedding "$content")
    [ -z "$embedding" ] && { echo "  ⚠️  Failed to get embedding"; return 1; }

    # Upsert to Qdrant
    local response=$(curl -s --max-time 30 -X PUT \
        "https://qdrant.harbor.fyi/collections/$collection/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $id,
                \"vector\": $embedding,
                \"payload\": $payload
            }]
        }")

    echo "$response" | jq -e '.status == "ok"' > /dev/null 2>&1
}

# Batch upsert to Qdrant (much faster for multiple items)
batch_upsert_qdrant() {
    local collection="$1"
    local points_json="$2"  # JSON array of {id, content, payload}

    local points_array="[]"
    local count=0

    # Build points with embeddings
    echo "$points_json" | jq -c '.[]' | while read -r point; do
        local id=$(echo "$point" | jq -r '.id')
        local content=$(echo "$point" | jq -r '.content')
        local payload=$(echo "$point" | jq -c '.payload')

        local embedding=$(get_embedding "$content")
        [ -z "$embedding" ] && continue

        # Append to batch (using temp file for accumulation)
        echo "{\"id\":$id,\"vector\":$embedding,\"payload\":$payload}" >> "/tmp/qdrant-batch-$collection.jsonl"
        ((count++))

        # Flush every BATCH_SIZE
        if [ $((count % BATCH_SIZE)) -eq 0 ]; then
            local batch_points=$(cat "/tmp/qdrant-batch-$collection.jsonl" | jq -s '.')
            curl -s --max-time $BATCH_TIMEOUT -X PUT \
                "https://qdrant.harbor.fyi/collections/$collection/points" \
                -H "api-key: ${QDRANT_API_KEY}" \
                -H "Content-Type: application/json" \
                -d "{\"points\": $batch_points}" > /dev/null
            rm -f "/tmp/qdrant-batch-$collection.jsonl"
            echo "    📦 Flushed batch of $BATCH_SIZE to $collection"
        fi
    done

    # Flush remaining
    if [ -f "/tmp/qdrant-batch-$collection.jsonl" ]; then
        local batch_points=$(cat "/tmp/qdrant-batch-$collection.jsonl" | jq -s '.')
        curl -s --max-time $BATCH_TIMEOUT -X PUT \
            "https://qdrant.harbor.fyi/collections/$collection/points" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d "{\"points\": $batch_points}" > /dev/null
        rm -f "/tmp/qdrant-batch-$collection.jsonl"
    fi
}

write_to_supabase() {
    local table="$1"
    local data="$2"

    curl -s --max-time 30 -X POST \
        "${PUBLIC_SUPABASE_URL}/rest/v1/$table" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Content-Type: application/json" \
        -H "Prefer: resolution=merge-duplicates" \
        -d "$data" > /dev/null
}

write_to_cortex() {
    local notebook="$1"
    local title="$2"
    local content="$3"

    # Check if already exists (by title search)
    local exists=$(curl -s --max-time 15 -X POST \
        "${CORTEX_URL}/api/search/fullTextSearchBlock" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"query\": \"$title\"}" | jq '.data.blocks | length')

    [ "$exists" -gt 0 ] && { echo "  ℹ️  Already in Cortex: $title"; return 0; }

    # Create document
    local escaped_content=$(echo "$content" | jq -Rs '.')
    curl -s --max-time 30 -X POST \
        "${CORTEX_URL}/api/filetree/createDocWithMd" \
        -H "Authorization: Token ${CORTEX_TOKEN}" \
        -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
        -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
        -H "Content-Type: application/json" \
        -d "{
            \"notebook\": \"$notebook\",
            \"path\": \"/Memory-Router/$title\",
            \"markdown\": $escaped_content
        }" > /dev/null
}

# ============================================
# ROUTING LOGIC
# ============================================

# Check if episode is high-value (should go to Cortex)
is_high_value_episode() {
    local task="$1"
    local reward="$2"
    local critique="$3"

    # High reward threshold
    local reward_num=$(echo "$reward" | awk '{printf "%.1f", $1}')
    if [ "$(echo "$reward_num >= 0.9" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        return 0  # High value
    fi

    # Keywords that indicate documentation/research worth saving
    local keywords="documentation|architecture|design|research|analysis|implementation|fix|solution|discovery|learning|pattern|strategy|framework"
    if echo "$task $critique" | grep -qiE "$keywords"; then
        return 0  # High value
    fi

    return 1  # Regular episode
}

route_episode() {
    local id="$1"
    local task="$2"
    local reward="$3"
    local critique="$4"
    local session_id="$5"

    local content="Task: $task\nReward: $reward\nCritique: $critique"
    local hash=$(compute_content_hash "$content")

    # Skip if already synced
    if content_exists "$hash"; then
        echo "  ⏭️  Episode $id already synced (hash match)"
        return 0
    fi

    echo "  📤 Routing episode $id..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local qdrant_payload=$(jq -n \
        --arg task "$task" \
        --arg reward "$reward" \
        --arg critique "$critique" \
        --arg session "$session_id" \
        --arg ts "$timestamp" \
        '{type: "episode", task: $task, reward: ($reward | tonumber), critique: $critique, session_id: $session, indexed_at: $ts}')

    # Write to Qdrant (agent_memory collection)
    run_with_timeout 45 write_to_qdrant "agent_memory" "$id" "$content" "$qdrant_payload" &
    local qdrant_pid=$!

    # Write to Supabase (patterns table)
    local supabase_data=$(jq -n \
        --arg pid "episode-$id" \
        --arg name "$task" \
        --arg desc "$critique" \
        --arg reward "$reward" \
        '{pattern_id: $pid, name: $name, description: $desc, category: "episode", template: {reward: ($reward | tonumber)}, success_count: 1}')
    run_with_timeout 30 write_to_supabase "patterns" "$supabase_data" &
    local supabase_pid=$!

    # HIGH-VALUE episodes also go to Cortex (documentation, research, major learnings)
    local cortex_pid=""
    if is_high_value_episode "$task" "$reward" "$critique"; then
        echo "    ⭐ High-value episode → also syncing to Cortex"
        local NOTEBOOK_RESOURCES="20251201183343-ujsixib"
        local cortex_content="# Episode: $task\n\n**Reward:** $reward\n\n## Critique\n$critique\n\n---\n*Session: $session_id*\n*Synced: $timestamp*"
        run_with_timeout 45 write_to_cortex "$NOTEBOOK_RESOURCES" "Episode-$id: $(echo "$task" | head -c 50)" "$cortex_content" &
        cortex_pid=$!
    fi

    # Wait for all
    wait $qdrant_pid 2>/dev/null && echo "    ✅ Qdrant" || echo "    ⚠️  Qdrant failed"
    wait $supabase_pid 2>/dev/null && echo "    ✅ Supabase" || echo "    ⚠️  Supabase failed"
    [ -n "$cortex_pid" ] && { wait $cortex_pid 2>/dev/null && echo "    ✅ Cortex" || echo "    ⚠️  Cortex failed"; }

    mark_content_synced "$hash"
}

route_learning() {
    local id="$1"
    local topic="$2"
    local content="$3"
    local category="$4"

    local hash=$(compute_content_hash "$content")

    if content_exists "$hash"; then
        echo "  ⏭️  Learning already synced (hash match)"
        return 0
    fi

    echo "  📤 Routing learning: $topic..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Parallel writes to Qdrant, Supabase, AND Cortex (learnings are high-value)

    # Qdrant (learnings collection)
    local qdrant_payload=$(jq -n \
        --arg topic "$topic" \
        --arg content "$content" \
        --arg cat "$category" \
        --arg ts "$timestamp" \
        '{type: "learning", topic: $topic, content: $content, category: $cat, indexed_at: $ts}')
    run_with_timeout 45 write_to_qdrant "learnings" "$id" "$content" "$qdrant_payload" &
    local qdrant_pid=$!

    # Supabase (learnings table)
    local supabase_data=$(jq -n \
        --arg lid "learning-$id" \
        --arg topic "$topic" \
        --arg content "$content" \
        --arg cat "$category" \
        '{learning_id: $lid, topic: $topic, content: $content, category: $cat, agent_id: "memory-router"}')
    run_with_timeout 30 write_to_supabase "learnings" "$supabase_data" &
    local supabase_pid=$!

    # Cortex (Resources notebook)
    local NOTEBOOK_RESOURCES="20251201183343-ujsixib"
    run_with_timeout 45 write_to_cortex "$NOTEBOOK_RESOURCES" "$topic" "# $topic\n\n$content\n\n---\n*Category: $category*\n*Synced: $timestamp*" &
    local cortex_pid=$!

    # Wait for all
    wait $qdrant_pid 2>/dev/null && echo "    ✅ Qdrant" || echo "    ⚠️  Qdrant failed"
    wait $supabase_pid 2>/dev/null && echo "    ✅ Supabase" || echo "    ⚠️  Supabase failed"
    wait $cortex_pid 2>/dev/null && echo "    ✅ Cortex" || echo "    ⚠️  Cortex failed"

    mark_content_synced "$hash"
}

route_swarm_pattern() {
    local id="$1"
    local namespace="$2"
    local key="$3"
    local value="$4"

    # Skip operational telemetry
    case "$namespace" in
        command-history|tool-usage|metrics|debug|logs|telemetry)
            return 0
            ;;
    esac

    local content="$namespace: $key = $value"
    local hash=$(compute_content_hash "$content")

    if content_exists "$hash"; then
        return 0
    fi

    echo "  📤 Routing swarm pattern: $namespace/$key..."

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local qdrant_payload=$(jq -n \
        --arg ns "$namespace" \
        --arg key "$key" \
        --arg val "$value" \
        --arg ts "$timestamp" \
        '{type: "swarm-pattern", namespace: $ns, key: $key, value: $val, indexed_at: $ts}')

    # Swarm patterns only go to Qdrant (ephemeral, search-only)
    run_with_timeout 45 write_to_qdrant "patterns" "$id" "$content" "$qdrant_payload"

    mark_content_synced "$hash"
}

# ============================================
# MAIN: Process pending items from sources
# ============================================

sync_new_episodes() {
    echo ""
    echo "📚 Syncing new AgentDB episodes (batch mode)..."

    local AGENTDB="$PROJECT_DIR/agentdb.db"
    [ ! -f "$AGENTDB" ] && { echo "  ⚠️  AgentDB not found"; return 0; }

    # Get last synced ID
    local last_id_file="$STATE_DIR/last-episode-id"
    local last_id=$(cat "$last_id_file" 2>/dev/null || echo "0")

    # Count pending episodes
    local pending_count=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes WHERE id > $last_id")
    echo "  📊 Pending episodes: $pending_count"

    if [ "$pending_count" -eq 0 ]; then
        echo "  ✅ No new episodes to sync"
        return 0
    fi

    # Process in batches
    local batch_num=0
    local total_synced=0
    local max_batches=10  # Safety limit

    while [ $batch_num -lt $max_batches ]; do
        ((batch_num++))

        # Get batch of episodes
        local batch=$(sqlite3 "$AGENTDB" "SELECT id, task, reward, success, critique, session_id FROM episodes WHERE id > $last_id ORDER BY id LIMIT $BATCH_SIZE")

        [ -z "$batch" ] && break

        echo ""
        echo "  📦 Processing batch $batch_num (up to $BATCH_SIZE items)..."

        local batch_count=0
        local batch_last_id="$last_id"

        while IFS='|' read -r id task reward success critique session_id; do
            [ -z "$id" ] && continue
            route_episode "$id" "$task" "$reward" "$critique" "$session_id"
            batch_last_id="$id"
            ((batch_count++))
            ((total_synced++))
        done <<< "$batch"

        # Update checkpoint after each batch
        echo "$batch_last_id" > "$last_id_file"
        last_id="$batch_last_id"

        echo "  ✅ Batch $batch_num complete: $batch_count episodes (checkpoint: $batch_last_id)"

        # Check if we've caught up
        local remaining=$(sqlite3 "$AGENTDB" "SELECT COUNT(*) FROM episodes WHERE id > $last_id")
        [ "$remaining" -eq 0 ] && break

        # Small delay between batches to avoid overwhelming APIs
        sleep 2
    done

    echo ""
    echo "  ✅ Episode sync complete: $total_synced total"
}

sync_new_learnings() {
    echo ""
    echo "📖 Syncing new Supabase learnings to Qdrant+Cortex..."

    # Get last synced learning
    local last_id_file="$STATE_DIR/last-learning-id"
    local last_id=$(cat "$last_id_file" 2>/dev/null || echo "0")

    # Get new learnings from Supabase
    local learnings=$(curl -s --max-time 30 \
        "${PUBLIC_SUPABASE_URL}/rest/v1/learnings?select=id,topic,content,category&id=gt.$last_id&order=id&limit=50" \
        -H "apikey: ${SUPABASE_SERVICE_ROLE_KEY}" \
        -H "Authorization: Bearer ${SUPABASE_SERVICE_ROLE_KEY}")

    local count=0
    echo "$learnings" | jq -c '.[]' 2>/dev/null | while read -r learning; do
        local id=$(echo "$learning" | jq -r '.id')
        local topic=$(echo "$learning" | jq -r '.topic')
        local content=$(echo "$learning" | jq -r '.content')
        local category=$(echo "$learning" | jq -r '.category // "general"')

        [ -z "$id" ] || [ "$id" = "null" ] && continue

        # Route to Qdrant + Cortex (skip Supabase - already there!)
        local hash=$(compute_content_hash "$content")
        if ! content_exists "$hash"; then
            echo "  📤 Routing learning to Qdrant+Cortex: $topic..."

            local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
            local qdrant_payload=$(jq -n \
                --arg topic "$topic" \
                --arg content "$content" \
                --arg cat "$category" \
                --arg ts "$timestamp" \
                '{type: "learning", topic: $topic, content: $content, category: $cat, indexed_at: $ts}')

            run_with_timeout 45 write_to_qdrant "learnings" "$id" "$content" "$qdrant_payload" &

            local NOTEBOOK_RESOURCES="20251201183343-ujsixib"
            run_with_timeout 45 write_to_cortex "$NOTEBOOK_RESOURCES" "$topic" "# $topic\n\n$content" &

            wait
            mark_content_synced "$hash"
        fi

        echo "$id" > "$last_id_file"
        ((count++)) || true
    done

    echo "  ✅ Processed learnings"
}

sync_swarm_patterns() {
    echo ""
    echo "🐝 Syncing Swarm patterns to Qdrant..."

    local SWARM_DB="$PROJECT_DIR/.swarm/memory.db"
    [ ! -f "$SWARM_DB" ] && { echo "  ⚠️  Swarm DB not found"; return 0; }

    local last_id_file="$STATE_DIR/last-swarm-id"
    local last_id=$(cat "$last_id_file" 2>/dev/null || echo "0")

    local patterns=$(sqlite3 "$SWARM_DB" "SELECT id, namespace, key, value FROM patterns WHERE id > $last_id ORDER BY id LIMIT 100" 2>/dev/null || echo "")

    local count=0
    while IFS='|' read -r id namespace key value; do
        [ -z "$id" ] && continue
        route_swarm_pattern "$id" "$namespace" "$key" "$value"
        echo "$id" > "$last_id_file"
        ((count++))
    done <<< "$patterns"

    echo "  ✅ Synced $count swarm patterns"
}

# ============================================
# CLEANUP & MAINTENANCE
# ============================================

cleanup_old_hashes() {
    # Keep only last 10000 hashes to prevent unbounded growth
    local hash_count=$(wc -l < "$CONTENT_HASHES" 2>/dev/null || echo "0")
    if [ "$hash_count" -gt 10000 ]; then
        echo "🧹 Trimming hash file (was $hash_count)..."
        tail -5000 "$CONTENT_HASHES" > "$CONTENT_HASHES.tmp"
        mv "$CONTENT_HASHES.tmp" "$CONTENT_HASHES"
    fi
}

# ============================================
# ENTRY POINT
# ============================================

main() {
    echo "🔀 Memory Router - Smart Multi-Directional Sync"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Started: $(date)"
    echo ""

    # Validate environment
    [ -z "$QDRANT_API_KEY" ] && { echo "❌ QDRANT_API_KEY not set"; exit 1; }
    [ -z "$GEMINI_API_KEY" ] && { echo "❌ GEMINI_API_KEY not set"; exit 1; }
    [ -z "$SUPABASE_SERVICE_ROLE_KEY" ] && { echo "❌ SUPABASE_SERVICE_ROLE_KEY not set"; exit 1; }

    # Run syncs
    sync_new_episodes
    sync_new_learnings
    sync_swarm_patterns

    # Maintenance
    cleanup_old_hashes

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Memory Router complete: $(date)"
}

# Handle arguments
case "${1:-}" in
    --episodes)
        sync_new_episodes
        ;;
    --learnings)
        sync_new_learnings
        ;;
    --swarm)
        sync_swarm_patterns
        ;;
    --help)
        echo "Usage: memory-router.sh [--episodes|--learnings|--swarm|--help]"
        echo "  No args: full sync"
        echo "  --episodes: sync AgentDB episodes only"
        echo "  --learnings: sync Supabase learnings only"
        echo "  --swarm: sync Swarm patterns only"
        ;;
    *)
        main
        ;;
esac
