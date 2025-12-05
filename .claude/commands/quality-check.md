---
description: Run full quality checks (lint + type-check + format)
---

# Quality Check

Running comprehensive code quality checks...

```bash
cd /Users/adamkovacs/Documents/codebuild/ai-enablement-academy-v2

echo "🔍 Running ESLint..."
pnpm lint

echo "✅ Lint passed!"
echo ""

echo "🔍 Running TypeScript type check..."
pnpm type-check

echo "✅ Type check passed!"
echo ""

echo "🔍 Checking code formatting..."
pnpm prettier --check "src/**/*.{ts,tsx}"

echo "✅ All quality checks passed! 🎉"
```

**To auto-fix issues:**
- Lint: `pnpm lint:fix`
- Format: `pnpm prettier --write "src/**/*.{ts,tsx}"`
