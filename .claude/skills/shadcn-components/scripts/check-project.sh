#!/bin/bash
# Check if project is ready for shadcn components

PROJECT_DIR="${1:-.}"

echo "🔍 Checking shadcn/ui project setup..."
echo ""

# Check for components.json
if [ -f "$PROJECT_DIR/components.json" ]; then
    echo "✅ components.json found"
    echo "   $(cat "$PROJECT_DIR/components.json" | jq -r '.style // "default"') style"
    echo "   $(cat "$PROJECT_DIR/components.json" | jq -r '.tailwind.baseColor // "slate"') base color"
else
    echo "❌ components.json not found"
    echo "   Run: pnpm dlx shadcn@latest init"
fi

# Check for tailwind.config
if [ -f "$PROJECT_DIR/tailwind.config.js" ] || [ -f "$PROJECT_DIR/tailwind.config.ts" ]; then
    echo "✅ Tailwind config found"
else
    echo "❌ Tailwind config not found"
fi

# Check for package.json dependencies
if [ -f "$PROJECT_DIR/package.json" ]; then
    if grep -q '"tailwindcss"' "$PROJECT_DIR/package.json"; then
        echo "✅ tailwindcss installed"
    else
        echo "❌ tailwindcss not in package.json"
    fi

    if grep -q '"class-variance-authority"' "$PROJECT_DIR/package.json"; then
        echo "✅ class-variance-authority installed"
    else
        echo "⚠️  class-variance-authority not installed (needed for components)"
    fi

    if grep -q '"clsx"' "$PROJECT_DIR/package.json"; then
        echo "✅ clsx installed"
    else
        echo "⚠️  clsx not installed (needed for cn utility)"
    fi
fi

# Check components directory
COMPONENTS_DIR=$(cat "$PROJECT_DIR/components.json" 2>/dev/null | jq -r '.aliases.components // "components"' | sed 's/@\///')
if [ -d "$PROJECT_DIR/$COMPONENTS_DIR/ui" ]; then
    COMPONENT_COUNT=$(ls -1 "$PROJECT_DIR/$COMPONENTS_DIR/ui" 2>/dev/null | wc -l | tr -d ' ')
    echo "✅ Components directory: $COMPONENTS_DIR/ui ($COMPONENT_COUNT components)"
else
    echo "⚠️  No components installed yet"
fi

echo ""
echo "📦 Quick commands:"
echo "   Init:  pnpm dlx shadcn@latest init"
echo "   Add:   pnpm dlx shadcn@latest add button card input"
echo "   List:  pnpm dlx shadcn@latest add --all (shows available)"
