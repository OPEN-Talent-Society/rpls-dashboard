#!/bin/bash
# Fix all relative .agentdb paths to use PROJECT_DIR
# Created: 2025-12-05
# Purpose: Ensure AgentDB paths work from any directory

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
BACKUP_DIR="$PROJECT_DIR/.claude-flow/backups/agentdb-path-fix-$(date +%Y%m%d-%H%M%S)"

echo "🔧 Fixing relative .agentdb paths"
echo "=================================="
echo ""
echo "Project: $PROJECT_DIR"
echo "Backup: $BACKUP_DIR"
echo ""

mkdir -p "$BACKUP_DIR"

# Find all hooks with .agentdb references
FILES=$(grep -l "\.agentdb" "$PROJECT_DIR/.claude/hooks"/*.sh 2>/dev/null || true)

if [ -z "$FILES" ]; then
    echo "✅ No files need fixing"
    exit 0
fi

TOTAL_FIXED=0

for file in $FILES; do
    # Backup
    rel_path="${file#$PROJECT_DIR/}"
    backup_file="$BACKUP_DIR/$rel_path"
    mkdir -p "$(dirname "$backup_file")"
    cp "$file" "$backup_file"

    # Check if file already has PROJECT_DIR defined
    if grep -q '^PROJECT_DIR=' "$file"; then
        # File has PROJECT_DIR, use it
        sed -i.bak \
            -e 's|AGENTDB_DIR="\$SCRIPT_DIR/\.\./\.agentdb"|AGENTDB_DIR="$PROJECT_DIR/.agentdb"|g' \
            -e 's|AGENTDB_FILE="\${SCRIPT_DIR}/\.\./\.agentdb/|AGENTDB_FILE="$PROJECT_DIR/.agentdb/|g' \
            -e 's|"\$SCRIPT_DIR/\.\./\.agentdb/|"$PROJECT_DIR/.agentdb/|g' \
            -e 's|AGENTDB="\$PROJECT_DIR/agentdb\.db"|AGENTDB="${AGENTDB_PATH:-$PROJECT_DIR/agentdb.db}"|g' \
            "$file"
    else
        # File doesn't have PROJECT_DIR, add it and fix paths
        # Insert after shebang
        sed -i.bak \
            -e '2i\
# Load .env with exports\
PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"\
if [ -f "$PROJECT_DIR/.env" ]; then\
    set -a; source "$PROJECT_DIR/.env"; set +a\
fi\
' \
            -e 's|AGENTDB_DIR="\$SCRIPT_DIR/\.\./\.agentdb"|AGENTDB_DIR="$PROJECT_DIR/.agentdb"|g' \
            -e 's|AGENTDB_FILE="\${SCRIPT_DIR}/\.\./\.agentdb/|AGENTDB_FILE="$PROJECT_DIR/.agentdb/|g' \
            -e 's|"\$SCRIPT_DIR/\.\./\.agentdb/|"$PROJECT_DIR/.agentdb/|g' \
            "$file"
    fi

    rm -f "${file}.bak"
    TOTAL_FIXED=$((TOTAL_FIXED + 1))
    echo "   ✅ Fixed: $(basename "$file")"
done

echo ""
echo "=================================="
echo "✅ Fixed $TOTAL_FIXED files"
echo "📦 Backups saved to: $BACKUP_DIR"
