#!/bin/bash
# Quick add shadcn components

if [ $# -eq 0 ]; then
    echo "Usage: add-components.sh <component1> [component2] ..."
    echo ""
    echo "Popular components:"
    echo "  button card input label textarea"
    echo "  dialog sheet dropdown-menu"
    echo "  form select checkbox radio-group"
    echo "  table tabs accordion"
    echo "  avatar badge tooltip"
    echo "  alert toast sonner"
    echo "  calendar date-picker"
    echo "  navigation-menu sidebar"
    echo ""
    echo "Example: add-components.sh button card input form"
    exit 1
fi

echo "📦 Installing shadcn components: $@"
echo ""

pnpm dlx shadcn@latest add "$@"

echo ""
echo "✅ Done! Components added to your project."
