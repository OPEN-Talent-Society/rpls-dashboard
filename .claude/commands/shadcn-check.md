---
description: Check if project is set up for shadcn/ui components
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Check shadcn/ui Project Setup

Check if the current project is properly configured for shadcn/ui components.

## Instructions

1. Look for `components.json` in the project root
2. Check for Tailwind CSS configuration
3. Verify required dependencies (tailwindcss, class-variance-authority, clsx, tailwind-merge)
4. List any installed components in the ui directory
5. Provide recommendations if setup is incomplete

## Checks to Perform

- [ ] `components.json` exists
- [ ] `tailwind.config.js` or `tailwind.config.ts` exists
- [ ] `tailwindcss` in dependencies
- [ ] `class-variance-authority` in dependencies
- [ ] `clsx` in dependencies
- [ ] `tailwind-merge` in dependencies
- [ ] `@/lib/utils.ts` exists with `cn` helper
- [ ] Components directory structure exists

## Output Format

Report status with checkmarks:
✅ Item configured correctly
❌ Item missing - needs action
⚠️ Item optional but recommended

If not initialized, suggest: `pnpm dlx shadcn@latest init`
