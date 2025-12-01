#!/bin/bash
# Detect which Claude agent variant is running based on working directory

WORKING_DIR="${PWD}"
AGENT_CONFIG="/Users/adamkovacs/Documents/codebuild/.claude/config/agents.json"

# Detect variant from path
detect_variant() {
    if [[ "$WORKING_DIR" == *"claude-zai-agent-flow"* ]]; then
        echo "claude-zai-agent-flow"
    elif [[ "$WORKING_DIR" == *"claude-zai-flow"* ]]; then
        echo "claude-zai-flow"
    elif [[ "$WORKING_DIR" == *"claude-flow"* ]]; then
        echo "claude-flow"
    elif [[ "$WORKING_DIR" == *"claude-zai"* ]]; then
        echo "claude-zai"
    elif [[ "$WORKING_DIR" == *"claude-code"* ]]; then
        echo "claude-code"
    else
        # Default to claude-code
        echo "claude-code"
    fi
}

# Get agent email from config
get_agent_email() {
    local variant=$(detect_variant)
    if command -v jq &> /dev/null && [ -f "$AGENT_CONFIG" ]; then
        jq -r ".agents.\"$variant\".email // \"claude-code@aienablement.academy\"" "$AGENT_CONFIG"
    else
        echo "claude-code@aienablement.academy"
    fi
}

# Get agent user_id from config
get_agent_user_id() {
    local variant=$(detect_variant)
    if command -v jq &> /dev/null && [ -f "$AGENT_CONFIG" ]; then
        jq -r ".agents.\"$variant\".user_id // \"uskfxdybo8kofowf\"" "$AGENT_CONFIG"
    else
        echo "uskfxdybo8kofowf"
    fi
}

# Get agent display name
get_agent_name() {
    local variant=$(detect_variant)
    if command -v jq &> /dev/null && [ -f "$AGENT_CONFIG" ]; then
        jq -r ".agents.\"$variant\".display_name // \"Claude Code\"" "$AGENT_CONFIG"
    else
        echo "Claude Code"
    fi
}

# Export for use in other scripts
export CLAUDE_VARIANT=$(detect_variant)
export CLAUDE_AGENT_EMAIL=$(get_agent_email)
export CLAUDE_AGENT_USER_ID=$(get_agent_user_id)
export CLAUDE_AGENT_NAME=$(get_agent_name)

# If called directly, output the values
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "CLAUDE_VARIANT=$CLAUDE_VARIANT"
    echo "CLAUDE_AGENT_EMAIL=$CLAUDE_AGENT_EMAIL"
    echo "CLAUDE_AGENT_USER_ID=$CLAUDE_AGENT_USER_ID"
    echo "CLAUDE_AGENT_NAME=$CLAUDE_AGENT_NAME"
fi
