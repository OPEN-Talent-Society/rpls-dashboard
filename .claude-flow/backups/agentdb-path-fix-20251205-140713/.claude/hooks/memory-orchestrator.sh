#!/bin/bash
# Memory Orchestrator Hook: Unified 3-Layer Memory Chain
# Ensures all memory operations flow through Layer 1 → Layer 2 → Layer 3
# Created: 2025-12-01
#
# ARCHITECTURE:
# Layer 1: claude-flow memory_usage (MCP) - Session memory
# Layer 2: AgentDB JSON files + neural_patterns - Local persistence
# Layer 3: Supabase cloud + flow-nexus storage - Cloud persistence
#
# CHAIN: memory_usage → memory-to-learnings-bridge → log-learning/save-pattern → Supabase

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/detect-agent.sh" 2>/dev/null || true

# Input parameters
ACTION="${1:-store}"
KEY="${2:-}"
VALUE="${3:-}"
NAMESPACE="${4:-default}"
LAYER_TARGET="${5:-all}"  # all, layer1, layer2, layer3

TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
LOG_FILE="/tmp/memory-orchestrator.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== MEMORY ORCHESTRATOR ==="
log "Action: $ACTION | Key: $KEY | Namespace: $NAMESPACE | Target: $LAYER_TARGET"

# ============================================
# LAYER 1: Claude Flow Memory (MCP)
# ============================================
layer1_store() {
    log "[Layer 1] Storing to claude-flow memory..."

    # Output MCP tool call format for Claude to execute
    cat << EOF
{
  "layer": 1,
  "system": "claude-flow",
  "mcp_tool": "mcp__claude-flow__memory_usage",
  "parameters": {
    "action": "store",
    "namespace": "$NAMESPACE",
    "key": "$KEY",
    "value": "$VALUE",
    "ttl": 2592000
  }
}
EOF
    log "[Layer 1] ✅ Memory store request generated"
}

layer1_retrieve() {
    log "[Layer 1] Retrieving from claude-flow memory..."
    cat << EOF
{
  "layer": 1,
  "system": "claude-flow",
  "mcp_tool": "mcp__claude-flow__memory_usage",
  "parameters": {
    "action": "retrieve",
    "namespace": "$NAMESPACE",
    "key": "$KEY"
  }
}
EOF
}

# ============================================
# LAYER 2: AgentDB Local + Neural Patterns
# ============================================
layer2_store() {
    log "[Layer 2] Storing to AgentDB local files..."

    # Determine if this is a learning or pattern
    if echo "$NAMESPACE" | grep -iEq "learning|discovery|insight|finding"; then
        AGENTDB_FILE="$SCRIPT_DIR/../.agentdb/learnings.json"
        ENTRY_TYPE="learning"
    else
        AGENTDB_FILE="$SCRIPT_DIR/../.agentdb/patterns.json"
        ENTRY_TYPE="pattern"
    fi

    if [ -f "$AGENTDB_FILE" ]; then
        HASH=$(echo "$KEY" | md5 | cut -c1-12)
        NEW_ENTRY=$(cat <<ENTRY
{
  "id": "${ENTRY_TYPE}-${HASH}",
  "key": "$KEY",
  "namespace": "$NAMESPACE",
  "content": $(echo "$VALUE" | jq -Rs .),
  "timestamp": "$TIMESTAMP",
  "agent": "${CLAUDE_VARIANT:-claude-code}",
  "agent_email": "${CLAUDE_AGENT_EMAIL:-claude-code@aienablement.academy}",
  "source": "memory-orchestrator"
}
ENTRY
)
        if command -v jq >/dev/null 2>&1; then
            TMP_FILE=$(mktemp)
            if [ "$ENTRY_TYPE" = "learning" ]; then
                jq --argjson entry "$NEW_ENTRY" '.entries += [$entry] | .updated = "'"$TIMESTAMP"'"' "$AGENTDB_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$AGENTDB_FILE"
            else
                jq --argjson entry "$NEW_ENTRY" '.patterns += [$entry] | .updated = "'"$TIMESTAMP"'"' "$AGENTDB_FILE" > "$TMP_FILE" 2>/dev/null && mv "$TMP_FILE" "$AGENTDB_FILE"
            fi
            log "[Layer 2] ✅ AgentDB updated: $AGENTDB_FILE"
        fi
    fi

    # Also trigger neural patterns for learning
    cat << EOF
{
  "layer": 2,
  "system": "neural_patterns",
  "mcp_tool": "mcp__claude-flow__neural_patterns",
  "parameters": {
    "action": "learn",
    "operation": "$KEY",
    "outcome": "stored",
    "metadata": {
      "namespace": "$NAMESPACE",
      "timestamp": "$TIMESTAMP"
    }
  }
}
EOF
    log "[Layer 2] ✅ Neural pattern request generated"
}

# ============================================
# LAYER 3: Supabase Cloud + Flow Nexus
# ============================================
layer3_store() {
    log "[Layer 3] Storing to Supabase cloud..."

    # Load credentials
    CODEBUILD_ROOT="${CODEBUILD_ROOT:-/Users/adamkovacs/Documents/codebuild}"
    if [ -f "${CODEBUILD_ROOT}/.env" ]; then
        source "${CODEBUILD_ROOT}/.env"
    fi

    if [ -n "$SUPABASE_ACCESS_TOKEN" ]; then
        # Escape for SQL
        ESCAPED_KEY=$(echo "$KEY" | sed "s/'/''/g")
        ESCAPED_VALUE=$(echo "$VALUE" | jq -Rs . | sed 's/^"//;s/"$//' | sed "s/'/''/g")

        QUERY="INSERT INTO agent_memory (key, namespace, value, metadata, agent_id, agent_email) VALUES ('${ESCAPED_KEY}', '${NAMESPACE}', '${ESCAPED_VALUE}', '{\"source\": \"memory-orchestrator\", \"timestamp\": \"${TIMESTAMP}\"}', '${CLAUDE_VARIANT:-claude-code}', '${CLAUDE_AGENT_EMAIL:-claude-code@aienablement.academy}') ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, metadata = EXCLUDED.metadata, updated_at = NOW() RETURNING id, key;"

        PAYLOAD=$(jq -n --arg query "$QUERY" '{"query": $query}')

        RESULT=$(curl -s -X POST "https://api.supabase.com/v1/projects/zxcrbcmdxpqprpxhsntc/database/query" \
            -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" 2>&1)

        if echo "$RESULT" | grep -q '"id"'; then
            log "[Layer 3] ✅ Supabase cloud storage updated"
        else
            log "[Layer 3] ⚠️ Supabase write may have failed"
        fi
    else
        log "[Layer 3] ⚠️ SUPABASE_ACCESS_TOKEN not set"
    fi

    # Also output flow-nexus storage request
    cat << EOF
{
  "layer": 3,
  "system": "flow-nexus",
  "mcp_tool": "mcp__flow-nexus__storage_upload",
  "parameters": {
    "bucket": "memory",
    "path": "orchestrator/${NAMESPACE}/${KEY}.json",
    "content": $(echo "$VALUE" | jq -Rs .),
    "content_type": "application/json"
  }
}
EOF
    log "[Layer 3] ✅ Flow-nexus storage request generated"
}

# ============================================
# ORCHESTRATE ALL LAYERS
# ============================================
orchestrate() {
    log "Orchestrating $ACTION across $LAYER_TARGET layers..."

    case "$ACTION" in
        store)
            if [ "$LAYER_TARGET" = "all" ] || [ "$LAYER_TARGET" = "layer1" ]; then
                layer1_store
            fi
            if [ "$LAYER_TARGET" = "all" ] || [ "$LAYER_TARGET" = "layer2" ]; then
                layer2_store
            fi
            if [ "$LAYER_TARGET" = "all" ] || [ "$LAYER_TARGET" = "layer3" ]; then
                layer3_store
            fi
            ;;
        retrieve)
            layer1_retrieve
            ;;
        *)
            log "Unknown action: $ACTION"
            exit 1
            ;;
    esac

    log "=== ORCHESTRATION COMPLETE ==="
}

# Execute
orchestrate
