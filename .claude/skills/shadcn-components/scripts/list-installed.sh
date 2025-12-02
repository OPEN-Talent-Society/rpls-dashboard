#!/bin/bash
# List installed shadcn components in a project

PROJECT_DIR="${1:-.}"

# Find components directory from components.json
if [ -f "$PROJECT_DIR/components.json" ]; then
    COMPONENTS_ALIAS=$(cat "$PROJECT_DIR/components.json" | jq -r '.aliases.components // "@/components"')
    COMPONENTS_DIR=$(echo "$COMPONENTS_ALIAS" | sed 's/@\///')
else
    COMPONENTS_DIR="components"
fi

UI_DIR="$PROJECT_DIR/$COMPONENTS_DIR/ui"

if [ ! -d "$UI_DIR" ]; then
    echo "❌ No shadcn components found at $UI_DIR"
    echo "   Run: pnpm dlx shadcn@latest init"
    exit 1
fi

echo "📦 Installed shadcn/ui components:"
echo ""

for file in "$UI_DIR"/*.tsx "$UI_DIR"/*.ts 2>/dev/null; do
    if [ -f "$file" ]; then
        name=$(basename "$file" | sed 's/\.[^.]*$//')
        echo "   • $name"
    fi
done

TOTAL=$(ls -1 "$UI_DIR"/*.tsx "$UI_DIR"/*.ts 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Total: $TOTAL components"
