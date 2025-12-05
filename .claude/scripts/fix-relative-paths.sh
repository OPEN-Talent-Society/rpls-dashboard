#!/bin/bash
# Fix all relative .claude/ paths to absolute paths
# Created: 2025-12-05
# Purpose: Ensure all paths work regardless of working directory

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
BACKUP_DIR="$PROJECT_DIR/.claude-flow/backups/path-fix-$(date +%Y%m%d-%H%M%S)"

echo "🔧 Fixing relative .claude/ paths to absolute paths"
echo "=================================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Backup: $BACKUP_DIR"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Pattern to replace: .claude/ → /Users/adamkovacs/Documents/codebuild/.claude/
# But ONLY in script/command contexts, NOT in comments or documentation

# Files to fix
TARGETS=(
    "$PROJECT_DIR/.claude/skills"
    "$PROJECT_DIR/.claude/agents"
    "$PROJECT_DIR/.claude/commands"
    "$PROJECT_DIR/.claude/hooks"
)

TOTAL_FIXED=0

for target in "${TARGETS[@]}"; do
    if [ ! -d "$target" ]; then
        echo "⚠️  Skipping (not found): $target"
        continue
    fi

    echo "📁 Processing: $(basename "$target")"

    # Find all .sh and .md files
    while IFS= read -r file; do
        # Skip if file doesn't contain .claude/
        if ! grep -q '\.claude/' "$file" 2>/dev/null; then
            continue
        fi

        # Create backup
        rel_path="${file#$PROJECT_DIR/}"
        backup_file="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_file")"
        cp "$file" "$backup_file"

        # Replace patterns (avoiding already absolute paths)
        # Match .claude/ but NOT /Users/adamkovacs/Documents/codebuild/.claude/
        sed -i.bak \
            -e 's|\([^/]\)\.claude/|\1/Users/adamkovacs/Documents/codebuild/.claude/|g' \
            -e 's|^\.claude/|/Users/adamkovacs/Documents/codebuild/.claude/|g' \
            -e 's|"\.claude/|"/Users/adamkovacs/Documents/codebuild/.claude/|g' \
            -e 's|'"'"'\.claude/|'"'"'/Users/adamkovacs/Documents/codebuild/.claude/|g' \
            -e 's|`\.claude/|`/Users/adamkovacs/Documents/codebuild/.claude/|g' \
            "$file"

        # Remove backup file created by sed
        rm -f "${file}.bak"

        TOTAL_FIXED=$((TOTAL_FIXED + 1))
        echo "   ✅ Fixed: $(basename "$file")"
    done < <(find "$target" -type f \( -name "*.sh" -o -name "*.md" \))

    echo ""
done

echo "=================================================="
echo "✅ Fixed $TOTAL_FIXED files"
echo "📦 Backups saved to: $BACKUP_DIR"
echo ""
echo "To verify changes:"
echo "  diff -r $BACKUP_DIR $PROJECT_DIR/.claude"
echo ""
echo "To restore (if needed):"
echo "  cp -r $BACKUP_DIR/.claude/* $PROJECT_DIR/.claude/"
