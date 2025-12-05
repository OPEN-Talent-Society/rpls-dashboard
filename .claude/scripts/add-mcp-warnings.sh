#!/bin/bash
# Script to add MCP tool warnings to remaining agent and skill files

WARNING_BLOCK='

---

## ⚠️ CRITICAL: MCP Tool Changes

**IMPORTANT:** The MCP swarm tools referenced in this document are **DENIED** and will not work.

**❌ DENIED Tools:**
- `mcp__claude-flow__swarm_init`
- `mcp__claude-flow__agent_spawn`
- `mcp__claude-flow__task_orchestrate`
- `mcp__claude-flow__agentic_flow_agent`

**✅ USE INSTEAD: Task Tool**
```javascript
// Spawn workers using Task tool
Task({
  subagent_type: "general-purpose",  // or "Explore", "Plan", or any agent from .claude/agents/
  description: "Brief task description",
  prompt: "Detailed instructions..."
})

// Spawn multiple workers in parallel (ONE message)
Task({ subagent_type: "general-purpose", description: "Worker 1", prompt: "..." })
Task({ subagent_type: "general-purpose", description: "Worker 2", prompt: "..." })
Task({ subagent_type: "general-purpose", description: "Worker 3", prompt: "..." })
```

**Why DENIED:** These tools require separate API keys and infrastructure. The Task tool uses your Claude Max subscription.

**For updated patterns, see:**
- `/Users/adamkovacs/CLAUDE.md` - Section I (Mandatory Rules)
- `.claude/docs/ref/SWARM-PATTERNS.md` - Multi-agent orchestration with Task tool
- `.claude/docs/ref/MCP-TOOLS.md` - ALLOWED vs DENIED tools

---
'

# Find all files with MCP tool references
FILES=$(grep -rl "mcp__claude-flow__\(swarm_init\|agent_spawn\|agentic_flow_agent\)" /Users/adamkovacs/Documents/codebuild/.claude/agents /Users/adamkovacs/Documents/codebuild/.claude/skills 2>/dev/null | grep -v node_modules | grep -v ".swp")

echo "Found $(echo "$FILES" | wc -l) files with MCP tool references"
echo ""

for file in $FILES; do
  # Skip if warning already exists
  if grep -q "⚠️ CRITICAL: MCP Tool Changes" "$file" 2>/dev/null; then
    echo "SKIP: $file (warning already exists)"
    continue
  fi
  
  # Find the first heading after frontmatter
  LINE=$(awk '/^---$/,/^---$/ {next} /^#/ {print NR; exit}' "$file")
  
  if [ -n "$LINE" ]; then
    # Insert warning after the first heading + description
    NEXT_LINE=$((LINE + 3))
    sed -i.bak "${NEXT_LINE}i\\
$WARNING_BLOCK
" "$file" && rm "${file}.bak"
    echo "UPDATED: $file"
  else
    echo "SKIP: $file (could not find insertion point)"
  fi
done

echo ""
echo "Done! Run validation:"
echo "grep -c '⚠️ CRITICAL: MCP Tool Changes' \$(grep -rl 'mcp__claude-flow__' /Users/adamkovacs/Documents/codebuild/.claude/agents /Users/adamkovacs/Documents/codebuild/.claude/skills 2>/dev/null | grep -v node_modules)"
