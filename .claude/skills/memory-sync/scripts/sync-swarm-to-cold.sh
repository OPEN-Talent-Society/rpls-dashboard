#!/bin/bash
# Sync Swarm Memory to cold storage (Supabase + Cortex)
# Extracts patterns, trajectories, and coordination data
# Created: 2025-12-02

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"

# Proper env loading with exports
if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

# Supabase config
SUPABASE_URL="${PUBLIC_SUPABASE_URL:-https://zxcrbcmdxpqprpxhsntc.supabase.co}"
SUPABASE_KEY="${SUPABASE_SERVICE_ROLE_KEY}"

# Cortex config
SIYUAN_BASE_URL="${CORTEX_URL:-https://cortex.aienablement.academy}"
SIYUAN_API_TOKEN="${CORTEX_TOKEN}"

# Cloudflare Zero Trust Service Token auth
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
NOTEBOOK_RESOURCES="20251201183343-ujsixib"  # 03 Resources

# Swarm Memory path
SWARM_DB="$PROJECT_DIR/.swarm/memory.db"

echo "🐝 Syncing Swarm Memory → Cold Storage"

if [ ! -f "$SWARM_DB" ]; then
    echo "  ⚠️  Swarm Memory not found at $SWARM_DB"
    exit 0
fi

TOTAL_SYNCED=0

# State tracking for incremental sync (prevents re-syncing all 26K+ entries)
SYNC_STATE_FILE="/tmp/swarm-cold-sync-state.json"
if [ ! -f "$SYNC_STATE_FILE" ]; then
    echo '{"last_synced_trajectory_id":0,"last_synced_memory_id":0,"last_synced_pattern_timestamp":"1970-01-01T00:00:00Z","last_sync_time":"1970-01-01T00:00:00Z"}' > "$SYNC_STATE_FILE"
fi

LAST_SYNCED_TRAJ_ID=$(jq -r '.last_synced_trajectory_id // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")
LAST_SYNCED_MEMORY_ID=$(jq -r '.last_synced_memory_id // 0' "$SYNC_STATE_FILE" 2>/dev/null || echo "0")
LAST_SYNCED_PATTERN_TS=$(jq -r '.last_synced_pattern_timestamp // "1970-01-01T00:00:00Z"' "$SYNC_STATE_FILE" 2>/dev/null || echo "1970-01-01T00:00:00Z")

# 1. Sync successful trajectories to Supabase patterns
echo ""
echo "📊 Syncing successful trajectories..."

# Check if task_trajectories table exists
HAS_TRAJECTORIES=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='task_trajectories';" 2>/dev/null)

if [ -n "$HAS_TRAJECTORIES" ]; then
    # Check for id column, if not exists use rowid
    HAS_ID_COLUMN=$(sqlite3 "$SWARM_DB" "PRAGMA table_info(task_trajectories);" 2>/dev/null | grep "^0|id|" | wc -l | tr -d ' ')

    if [ "$HAS_ID_COLUMN" -gt 0 ]; then
        ID_FIELD="id"
    else
        ID_FIELD="rowid"
    fi

    TRAJ_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM task_trajectories WHERE (judge_label = 'correct' OR judge_label = 'success') AND $ID_FIELD > $LAST_SYNCED_TRAJ_ID;" 2>/dev/null || echo "0")

    if [ "$TRAJ_COUNT" -gt 0 ]; then
        # FIXED: Use JSON parsing instead of pipe delimiters
        TRAJECTORIES_JSON=$(sqlite3 "$SWARM_DB" -json "
        SELECT
            $ID_FIELD as id,
            COALESCE(agent_id, '') as agent_id,
            REPLACE(REPLACE(COALESCE(query, ''), char(10), ' '), char(13), ' ') as query,
            COALESCE(judge_label, '') as judge_label,
            COALESCE(created_at, '') as created_at
        FROM task_trajectories
        WHERE (judge_label = 'correct' OR judge_label = 'success')
          AND $ID_FIELD > $LAST_SYNCED_TRAJ_ID
        ORDER BY created_at DESC
        LIMIT 20;
        " 2>/dev/null || echo "[]")

        MAX_TRAJ_ID=$LAST_SYNCED_TRAJ_ID

        echo "$TRAJECTORIES_JSON" | jq -c '.[]' | while read -r traj_json; do
            # Extract fields from JSON (safe, no delimiter issues)
            TRAJ_ID=$(echo "$traj_json" | jq -r '.id')
            AGENT_ID=$(echo "$traj_json" | jq -r '.agent_id')
            QUERY=$(echo "$traj_json" | jq -r '.query')
            LABEL=$(echo "$traj_json" | jq -r '.judge_label')
            CREATED_AT=$(echo "$traj_json" | jq -r '.created_at')

            [ -z "$QUERY" ] && continue

            # Track max ID
            if [ "$TRAJ_ID" -gt "$MAX_TRAJ_ID" ]; then
                MAX_TRAJ_ID=$TRAJ_ID
            fi

            PATTERN=$(jq -n \
                --arg name "swarm-${AGENT_ID}-$(echo "$QUERY" | head -c 30 | tr ' ' '-')" \
                --arg desc "$QUERY" \
                --arg category "swarm-trajectory" \
                --arg trajId "$TRAJ_ID" \
                '{
                    pattern_id: ("swarm-traj-" + $trajId + "-" + ($name | gsub(" "; "-") | ascii_downcase)),
                    name: $name,
                    description: $desc,
                    category: $category,
                    template: "# Swarm Trajectory Pattern\n\n## Query\n{{description}}\n\n## Application\nReuse this successful swarm coordination pattern.",
                    success_count: 1,
                    project: "codebuild",
                    tags: ["swarm", "trajectory", "success"]
                }')

            RESPONSE=$(curl -s -X POST "${SUPABASE_URL}/rest/v1/patterns" \
                -H "apikey: ${SUPABASE_KEY}" \
                -H "Authorization: Bearer ${SUPABASE_KEY}" \
                -H "Content-Type: application/json" \
                -H "Prefer: resolution=merge-duplicates" \
                -d "$PATTERN" 2>&1)

            if ! echo "$RESPONSE" | grep -q "error"; then
                TOTAL_SYNCED=$((TOTAL_SYNCED + 1))
                echo "  ✅ Trajectory #${TRAJ_ID}: ${QUERY:0:40}..."
            fi
        done

        # Update state after successful sync
        if [ "$MAX_TRAJ_ID" -gt "$LAST_SYNCED_TRAJ_ID" ]; then
            # Preserve other state fields during update
            CURRENT_STATE=$(cat "$SYNC_STATE_FILE" 2>/dev/null || echo '{}')
            echo "$CURRENT_STATE" | jq \
                --argjson lid "$MAX_TRAJ_ID" \
                --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '.last_synced_trajectory_id = $lid | .last_sync_time = $lts' > "$SYNC_STATE_FILE"
            echo "  📝 Updated state: last_synced_trajectory_id = $MAX_TRAJ_ID"
        fi
    else
        echo "  ℹ️  No new successful trajectories found"
    fi
else
    echo "  ℹ️  task_trajectories table not found"
fi

# 2. Sync memory_entries to Supabase (INCREMENTAL - only new entries)
echo ""
echo "💾 Syncing memory entries (INCREMENTAL)..."

HAS_MEMORY=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='memory_entries';" 2>/dev/null)

if [ -n "$HAS_MEMORY" ]; then
    TOTAL_MEMORY_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM memory_entries;" 2>/dev/null || echo "0")
    NEW_MEMORY_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM memory_entries WHERE id > $LAST_SYNCED_MEMORY_ID;" 2>/dev/null || echo "0")

    echo "  📊 Total memory entries: $TOTAL_MEMORY_COUNT (${NEW_MEMORY_COUNT} new since last sync)"

    if [ "$NEW_MEMORY_COUNT" -gt 0 ]; then
        # Only sync NEW entries (incremental) - limit to 100 at a time for safety
        BATCH_LIMIT=100
        if [ "$NEW_MEMORY_COUNT" -gt "$BATCH_LIMIT" ]; then
            echo "  ⚠️  Found $NEW_MEMORY_COUNT new entries - limiting to $BATCH_LIMIT per sync"
        fi

        MEMORY_JSON=$(sqlite3 "$SWARM_DB" -json "
            SELECT
                id,
                key,
                value,
                namespace,
                created_at
            FROM memory_entries
            WHERE id > $LAST_SYNCED_MEMORY_ID
            ORDER BY id ASC
            LIMIT $BATCH_LIMIT;
        " 2>/dev/null || echo "[]")

        MAX_MEMORY_ID=$LAST_SYNCED_MEMORY_ID
        MEMORY_SYNCED=0

        # Use process substitution to avoid subshell variable loss
        while IFS= read -r entry_json; do
            ENTRY_ID=$(echo "$entry_json" | jq -r '.id')
            KEY=$(echo "$entry_json" | jq -r '.key')
            FULL_VALUE=$(echo "$entry_json" | jq -r '.value')
            NAMESPACE=$(echo "$entry_json" | jq -r '.namespace')
            CREATED_AT=$(echo "$entry_json" | jq -r '.created_at')

            [ -z "$KEY" ] && continue

            # Track max ID
            if [ "$ENTRY_ID" -gt "$MAX_MEMORY_ID" ]; then
                MAX_MEMORY_ID=$ENTRY_ID
            fi

            # CRITICAL: Filter out operational telemetry (NOT learnings)
            # These are metrics, command history, and operational data - skip entirely
            # Quality gate: Skip entries with content < 50 chars OR noise namespaces
            IS_NOISE=0

            # Skip noise categories: command-history, performance-metrics, neural-training, hooks:*
            if [[ "$NAMESPACE" =~ ^(command-history|command-results|command-metrics|performance-metrics|neural-training|hooks:.*|session-states|session-metrics|tool-usage|metrics|telemetry|debug|logs|file-history)$ ]]; then
                IS_NOISE=1
            fi

            # Additional quality gate: content must be >= 50 chars to be considered knowledge
            if [ ${#FULL_VALUE} -lt 50 ]; then
                IS_NOISE=1
            fi

            # SKIP noise entries entirely (don't sync to any table)
            if [ "$IS_NOISE" -eq 1 ]; then
                continue
            fi

            # Determine if remaining data is operational (route to telemetry) vs knowledge (route to learnings)
            IS_OPERATIONAL=0
            if [[ "$NAMESPACE" =~ ^(hive-mind|worker|queen|scout|swarm-status|task-coordination|agent-assignments|performance)$ ]] || \
               [[ "$KEY" =~ ^(status|progress|task-|worker-|queue-|coordination-) ]]; then
                IS_OPERATIONAL=1
            fi

            if [ "$IS_OPERATIONAL" -eq 1 ]; then
                # Route to operations_telemetry table (operational data)
                TELEMETRY=$(jq -n \
                    --arg eid "$ENTRY_ID" \
                    --arg ns "$NAMESPACE" \
                    --arg key "$KEY" \
                    --arg val "$FULL_VALUE" \
                    --arg ts "$CREATED_AT" \
                    '{
                        telemetry_id: ("swarm-mem-" + $eid),
                        source: ("swarm-memory/" + $ns),
                        operation_type: $key,
                        metrics: {value: $val, namespace: $ns},
                        agent_id: "swarm-memory-sync",
                        timestamp: $ts,
                        project: "codebuild",
                        tags: ["swarm", "operational", $ns]
                    }')

                if [ -n "$SUPABASE_KEY" ]; then
                    curl -s -X POST "${SUPABASE_URL}/rest/v1/operations_telemetry" \
                        -H "apikey: ${SUPABASE_KEY}" \
                        -H "Authorization: Bearer ${SUPABASE_KEY}" \
                        -H "Content-Type: application/json" \
                        -H "Prefer: resolution=merge-duplicates" \
                        -d "$TELEMETRY" >/dev/null 2>&1 && MEMORY_SYNCED=$((MEMORY_SYNCED + 1))
                fi
            else
                # Route to learnings table (actual knowledge/patterns)
                # Use smart-chunker for long content
                if [ ${#FULL_VALUE} -gt 500 ]; then
                    # Use smart-chunker.py for intelligent chunking
                    CHUNKER_INPUT=$(jq -n \
                        --arg content "$FULL_VALUE" \
                        --arg type "text" \
                        --arg ns "$NAMESPACE" \
                        --arg key "$KEY" \
                        '{
                            content: $content,
                            content_type: $type,
                            metadata: {namespace: $ns, key: $key}
                        }')

                    CHUNKER_OUTPUT=$(echo "$CHUNKER_INPUT" | python3 "$PROJECT_DIR/.claude/skills/memory-sync/scripts/smart-chunker.py" 2>/dev/null || echo '{"success":false,"chunks":[]}')
                    CHUNK_SUCCESS=$(echo "$CHUNKER_OUTPUT" | jq -r '.success')

                    if [ "$CHUNK_SUCCESS" = "true" ]; then
                        # Store each chunk as a separate learning
                        echo "$CHUNKER_OUTPUT" | jq -c '.chunks[]' | while read -r chunk_json; do
                            CHUNK_TEXT=$(echo "$chunk_json" | jq -r '.text')
                            CHUNK_INDEX=$(echo "$chunk_json" | jq -r '.index')
                            CHUNK_TOTAL=$(echo "$chunk_json" | jq -r '.total')

                            LEARNING=$(jq -n \
                                --arg key "$KEY" \
                                --arg val "$CHUNK_TEXT" \
                                --arg ns "$NAMESPACE" \
                                --arg eid "$ENTRY_ID" \
                                --arg idx "$CHUNK_INDEX" \
                                --arg total "$CHUNK_TOTAL" \
                                '{
                                    learning_id: ("swarm-memory-" + $eid + "-chunk-" + $idx),
                                    topic: ($ns + "/" + $key + " [" + $idx + "/" + $total + "]"),
                                    content: $val,
                                    category: "swarm-knowledge",
                                    agent_id: "swarm-memory-sync",
                                    project: "codebuild",
                                    tags: ["swarm", "memory", $ns, "chunked"]
                                }')

                            if [ -n "$SUPABASE_KEY" ]; then
                                curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                                    -H "apikey: ${SUPABASE_KEY}" \
                                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                                    -H "Content-Type: application/json" \
                                    -H "Prefer: resolution=merge-duplicates" \
                                    -d "$LEARNING" >/dev/null 2>&1
                            fi
                        done
                        MEMORY_SYNCED=$((MEMORY_SYNCED + 1))
                    else
                        # Fallback: truncate to 2000 chars if chunker fails
                        VALUE_TRUNCATED="${FULL_VALUE:0:2000}"
                        LEARNING=$(jq -n \
                            --arg key "$KEY" \
                            --arg val "$VALUE_TRUNCATED" \
                            --arg ns "$NAMESPACE" \
                            --arg eid "$ENTRY_ID" \
                            '{
                                learning_id: ("swarm-memory-" + $eid),
                                topic: ($ns + "/" + $key),
                                content: $val,
                                category: "swarm-knowledge",
                                agent_id: "swarm-memory-sync",
                                project: "codebuild",
                                tags: ["swarm", "memory", $ns, "truncated"]
                            }')

                        if [ -n "$SUPABASE_KEY" ]; then
                            curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                                -H "apikey: ${SUPABASE_KEY}" \
                                -H "Authorization: Bearer ${SUPABASE_KEY}" \
                                -H "Content-Type: application/json" \
                                -H "Prefer: resolution=merge-duplicates" \
                                -d "$LEARNING" >/dev/null 2>&1 && MEMORY_SYNCED=$((MEMORY_SYNCED + 1))
                        fi
                    fi
                else
                    # Short content: store directly without chunking
                    LEARNING=$(jq -n \
                        --arg key "$KEY" \
                        --arg val "$FULL_VALUE" \
                        --arg ns "$NAMESPACE" \
                        --arg eid "$ENTRY_ID" \
                        '{
                            learning_id: ("swarm-memory-" + $eid),
                            topic: ($ns + "/" + $key),
                            content: $val,
                            category: "swarm-knowledge",
                            agent_id: "swarm-memory-sync",
                            project: "codebuild",
                            tags: ["swarm", "memory", $ns]
                        }')

                    if [ -n "$SUPABASE_KEY" ]; then
                        curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                            -H "apikey: ${SUPABASE_KEY}" \
                            -H "Authorization: Bearer ${SUPABASE_KEY}" \
                            -H "Content-Type: application/json" \
                            -H "Prefer: resolution=merge-duplicates" \
                            -d "$LEARNING" >/dev/null 2>&1 && MEMORY_SYNCED=$((MEMORY_SYNCED + 1))
                    fi
                fi
            fi
        done < <(echo "$MEMORY_JSON" | jq -c '.[]')

        # Update state with new max memory ID
        if [ "$MAX_MEMORY_ID" -gt "$LAST_SYNCED_MEMORY_ID" ]; then
            CURRENT_STATE=$(cat "$SYNC_STATE_FILE" 2>/dev/null || echo '{}')
            echo "$CURRENT_STATE" | jq \
                --argjson mid "$MAX_MEMORY_ID" \
                --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '.last_synced_memory_id = $mid | .last_sync_time = $lts' > "$SYNC_STATE_FILE"
            echo "  ✅ Synced $MEMORY_SYNCED memory entries (last ID: $MAX_MEMORY_ID)"
            TOTAL_SYNCED=$((TOTAL_SYNCED + MEMORY_SYNCED))
        fi
    else
        echo "  ℹ️  No new memory entries to sync"
    fi
else
    echo "  ℹ️  memory_entries table not found"
fi

# 3. Sync ReasoningBank patterns to AgentDB (fast bulk insert - INCREMENTAL)
echo ""
echo "🔗 Syncing ReasoningBank patterns to AgentDB (INCREMENTAL)..."

HAS_PATTERNS=$(sqlite3 "$SWARM_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='patterns';" 2>/dev/null)
AGENTDB="$PROJECT_DIR/agentdb.db"

if [ -n "$HAS_PATTERNS" ]; then
    PATTERN_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM patterns;" 2>/dev/null || echo "0")
    NEW_PATTERN_COUNT=$(sqlite3 "$SWARM_DB" "SELECT COUNT(*) FROM patterns WHERE created_at > '$LAST_SYNCED_PATTERN_TS';" 2>/dev/null || echo "0")
    echo "  📊 Found $PATTERN_COUNT patterns in ReasoningBank ($NEW_PATTERN_COUNT new)"

    if [ "$NEW_PATTERN_COUNT" -gt 0 ] && [ -f "$AGENTDB" ]; then
        # FAST APPROACH: Use SQLite's ATTACH to copy NEW patterns only (incremental)
        # This avoids slow shell loops and API calls

        # Use ATTACH to efficiently copy ONLY new patterns
        sqlite3 "$AGENTDB" "
            ATTACH '${SWARM_DB}' AS swarm;

            -- Insert only NEW patterns from ReasoningBank into AgentDB episodes (INCREMENTAL)
            INSERT OR REPLACE INTO episodes (task, reward, success, critique, session_id, created_at)
            SELECT
                COALESCE(json_extract(pattern_data, '$.title'), 'Pattern-' || id) as task,
                confidence as reward,
                1 as success,
                substr(COALESCE(json_extract(pattern_data, '$.content'), pattern_data), 1, 2000) as critique,
                'reasoningbank-sync' as session_id,
                created_at
            FROM swarm.patterns
            WHERE created_at > '$LAST_SYNCED_PATTERN_TS';

            DETACH swarm;
        " 2>/dev/null

        # Get latest pattern timestamp for next sync
        LATEST_PATTERN_TS=$(sqlite3 "$SWARM_DB" "SELECT MAX(created_at) FROM patterns;" 2>/dev/null || echo "$LAST_SYNCED_PATTERN_TS")

        echo "  ✅ Synced $NEW_PATTERN_COUNT new patterns to AgentDB"
        TOTAL_SYNCED=$((TOTAL_SYNCED + NEW_PATTERN_COUNT))

        # Update state with new pattern timestamp
        CURRENT_STATE=$(cat "$SYNC_STATE_FILE" 2>/dev/null || echo '{}')
        echo "$CURRENT_STATE" | jq \
            --arg pts "$LATEST_PATTERN_TS" \
            --arg lts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.last_synced_pattern_timestamp = $pts | .last_sync_time = $lts' > "$SYNC_STATE_FILE"
        echo "  📝 Updated state: last_synced_pattern_timestamp = $LATEST_PATTERN_TS"

        # Optional: Sync only NEW patterns to Supabase (not all 50 every time)
        if [ -n "$SUPABASE_KEY" ] && [ "$NEW_PATTERN_COUNT" -gt 0 ]; then
            # Limit to 20 new patterns per sync to avoid API rate limits
            SUPABASE_BATCH_LIMIT=20
            echo "  📤 Syncing up to $SUPABASE_BATCH_LIMIT new patterns to Supabase..."
            SYNCED_TO_SUPABASE=0

            PATTERNS_JSON=$(sqlite3 "$SWARM_DB" -json "
                SELECT
                    id,
                    COALESCE(json_extract(pattern_data, '$.title'), '') as title,
                    COALESCE(confidence, 0) as confidence
                FROM patterns
                WHERE created_at > '$LAST_SYNCED_PATTERN_TS'
                ORDER BY confidence DESC
                LIMIT $SUPABASE_BATCH_LIMIT;
            " 2>/dev/null || echo "[]")

            echo "$PATTERNS_JSON" | jq -c '.[]' | while read -r pattern_json; do
                ID=$(echo "$pattern_json" | jq -r '.id')
                TITLE=$(echo "$pattern_json" | jq -r '.title')
                CONF=$(echo "$pattern_json" | jq -r '.confidence')

                [ -z "$ID" ] && continue
                [ -z "$TITLE" ] && TITLE="Pattern-$ID"

                LEARNING=$(jq -n \
                    --arg topic "$TITLE" \
                    --arg category "reasoningbank-pattern" \
                    --arg patternId "$ID" \
                    '{
                        learning_id: ("rb-" + $patternId),
                        topic: $topic,
                        content: "See ReasoningBank for full content",
                        category: $category,
                        agent_id: "reasoningbank-sync",
                        project: "codebuild",
                        tags: ["reasoningbank", "pattern"]
                    }')

                curl -s -X POST "${SUPABASE_URL}/rest/v1/learnings" \
                    -H "apikey: ${SUPABASE_KEY}" \
                    -H "Authorization: Bearer ${SUPABASE_KEY}" \
                    -H "Content-Type: application/json" \
                    -H "Prefer: resolution=merge-duplicates" \
                    -d "$LEARNING" >/dev/null 2>&1 && SYNCED_TO_SUPABASE=$((SYNCED_TO_SUPABASE + 1))
            done
            echo "  ✅ Synced to Supabase: $SYNCED_TO_SUPABASE new patterns (incremental)"
        fi
    else
        echo "  ℹ️  No new patterns to sync (all up to date)"
    fi
else
    echo "  ℹ️  patterns table not found in Swarm Memory"
fi

# 4. DISABLED - Cortex sync per MEMORY-SYSTEM-SPECIFICATION.md
# Raw machine data (metrics) should NOT be auto-dumped to Cortex
# Use /cortex-* commands for curated human-readable content
echo ""
echo "📈 Cortex metrics sync DISABLED (use /cortex-note for curated content)"

echo ""
echo "✅ Swarm Memory → Cold Storage sync complete: $TOTAL_SYNCED items synced"
