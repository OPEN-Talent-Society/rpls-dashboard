#!/bin/bash
# Setup MCP Inheritance for Claude Code Subfolders
# This script creates symlinks from subfolders to parent's MCP configuration

set -e

PARENT_MCP="/Users/adamkovacs/Documents/codebuild/.claude/mcp.json"
CODEBUILD_DIR="/Users/adamkovacs/Documents/codebuild"

echo "🔗 Setting up MCP inheritance for Claude Code subfolders"
echo "Parent MCP config: $PARENT_MCP"
echo ""

# Verify parent MCP config exists
if [ ! -f "$PARENT_MCP" ]; then
  echo "❌ Error: Parent MCP config not found at $PARENT_MCP"
  exit 1
fi

# Find all directories with .claude folder (excluding parent)
echo "📁 Scanning for projects with .claude directories..."
PROJECTS=()

for dir in "$CODEBUILD_DIR"/*/.claude; do
  if [ -d "$dir" ]; then
    project_dir=$(dirname "$dir")
    project_name=$(basename "$project_dir")

    # Skip if this is the parent directory itself
    if [ "$project_dir" != "$CODEBUILD_DIR" ]; then
      PROJECTS+=("$project_name")
    fi
  fi
done

echo "Found ${#PROJECTS[@]} projects with .claude directories"
echo ""

# Process each project
LINKED=0
SKIPPED=0
UPDATED=0

for project in "${PROJECTS[@]}"; do
  SUBFOLDER_CLAUDE="$CODEBUILD_DIR/$project/.claude"
  MCP_FILE="$SUBFOLDER_CLAUDE/mcp.json"

  echo "📦 Processing: $project"

  # Check if mcp.json already exists
  if [ -L "$MCP_FILE" ]; then
    # It's a symlink - check if it points to the right place
    LINK_TARGET=$(readlink "$MCP_FILE")
    if [ "$LINK_TARGET" = "$PARENT_MCP" ]; then
      echo "   ✅ Already linked correctly"
      SKIPPED=$((SKIPPED + 1))
    else
      echo "   ⚠️  Linked to different location: $LINK_TARGET"
      echo "   🔄 Updating symlink..."
      rm "$MCP_FILE"
      ln -s "$PARENT_MCP" "$MCP_FILE"
      echo "   ✅ Updated to parent config"
      UPDATED=$((UPDATED + 1))
    fi
  elif [ -f "$MCP_FILE" ]; then
    echo "   ⚠️  Has own mcp.json (not a symlink)"
    echo "   ℹ️  Keeping existing configuration"
    SKIPPED=$((SKIPPED + 1))
  else
    # Create symlink
    ln -s "$PARENT_MCP" "$MCP_FILE"
    echo "   ✅ Created symlink to parent config"
    LINKED=$((LINKED + 1))
  fi

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary:"
echo "  ✅ New links created: $LINKED"
echo "  🔄 Links updated: $UPDATED"
echo "  ⏭️  Skipped (already configured): $SKIPPED"
echo "  📊 Total projects processed: ${#PROJECTS[@]}"
echo ""
echo "🎉 MCP inheritance setup complete!"
echo ""
echo "Next steps:"
echo "1. Restart Claude Code in any subfolder"
echo "2. Run /context to verify MCP tools are loaded"
echo "3. Should see 'MCP tools: 12.8k tokens' section"
