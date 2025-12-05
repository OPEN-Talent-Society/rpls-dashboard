#!/bin/bash
# Post-edit hook: Run quality checks on edited files

FILE="$1"

# Only check TypeScript/JavaScript files
if [[ "$FILE" =~ \.(ts|tsx|js|jsx)$ ]]; then
  cd "$(dirname "$FILE")" || exit 0

  # Find project root (where package.json is)
  while [[ ! -f "package.json" ]] && [[ "$PWD" != "/" ]]; do
    cd ..
  done

  if [[ -f "package.json" ]]; then
    # Run ESLint on the specific file (silent mode)
    pnpm lint "$FILE" 2>/dev/null || echo "⚠️  Lint issues in $FILE - run 'pnpm lint:fix' to auto-fix"
  fi
fi
