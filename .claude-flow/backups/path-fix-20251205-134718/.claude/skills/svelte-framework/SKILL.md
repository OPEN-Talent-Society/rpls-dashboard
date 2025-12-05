---
name: svelte-framework
description: Svelte and SvelteKit development skill. Use this when building Svelte applications and need access to Svelte-specific MCP tools for component generation and best practices. This skill provides guidance on enabling the Svelte MCP server on-demand to save context tokens.
status: active
owner: platform
last_reviewed_at: 2025-12-01
tags:
  - frontend
  - svelte
  - sveltekit
  - components
  - framework
dependencies: []
outputs:
  - svelte-components
  - sveltekit-routes
  - best-practices
---

# Svelte Framework Skill

This skill provides guidance for Svelte and SvelteKit development. The MCP server is **NOT loaded by default** to save context tokens - enable it only when needed.

## When to Use This Skill

Use this skill when you need to:
- Build Svelte components
- Work with SvelteKit routes and layouts
- Use Svelte-specific patterns and best practices
- Generate Svelte code with MCP assistance
- Understand Svelte 5 runes and new features

## Enabling the MCP Server

To enable Svelte MCP, add this to `.claude/mcp.json`:

```json
{
  "svelte": {
    "type": "stdio",
    "command": "pnpm",
    "args": ["dlx", "@sveltejs/mcp"]
  }
}
```

Then restart Claude Code to load the new MCP.

## Svelte 5 Runes (New in Svelte 5)

### State Management
```svelte
<script>
  // Reactive state
  let count = $state(0);

  // Derived state
  let doubled = $derived(count * 2);

  // Effect
  $effect(() => {
    console.log('Count changed:', count);
  });
</script>
```

### Props
```svelte
<script>
  // Props with defaults
  let { name, greeting = 'Hello' } = $props();

  // Bindable props
  let { value = $bindable() } = $props();
</script>
```

## SvelteKit Routing

### File-based Routes
```
src/routes/
  +page.svelte          # /
  +layout.svelte        # Root layout
  about/
    +page.svelte        # /about
  blog/
    +page.svelte        # /blog
    [slug]/
      +page.svelte      # /blog/:slug
      +page.server.ts   # Server load function
```

### Load Functions
```typescript
// +page.server.ts
export async function load({ params, fetch }) {
  const post = await fetch(`/api/posts/${params.slug}`);
  return { post: await post.json() };
}
```

### Form Actions
```typescript
// +page.server.ts
export const actions = {
  default: async ({ request }) => {
    const data = await request.formData();
    // Handle form submission
  }
};
```

## Common Patterns

### Component with Props
```svelte
<!-- Button.svelte -->
<script lang="ts">
  let {
    variant = 'primary',
    disabled = false,
    onclick
  } = $props<{
    variant?: 'primary' | 'secondary';
    disabled?: boolean;
    onclick?: () => void;
  }>();
</script>

<button
  class={variant}
  {disabled}
  {onclick}
>
  <slot />
</button>
```

### Stores (Svelte 4 pattern, still valid)
```typescript
// stores.ts
import { writable, derived } from 'svelte/store';

export const count = writable(0);
export const doubled = derived(count, $count => $count * 2);
```

### Context API
```svelte
<script>
  import { setContext, getContext } from 'svelte';

  // Parent
  setContext('theme', { color: 'dark' });

  // Child
  const theme = getContext('theme');
</script>
```

## CLI Without MCP

For simple tasks, use the CLI directly:

```bash
# Create new SvelteKit project
pnpm create svelte@latest my-app

# Add dependencies
pnpm add -D @sveltejs/adapter-auto
pnpm add tailwindcss

# Development
pnpm dev

# Build
pnpm build

# Preview production build
pnpm preview
```

## Configuration

### svelte.config.js
```javascript
import adapter from '@sveltejs/adapter-auto';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

export default {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    alias: {
      $components: 'src/lib/components',
      $stores: 'src/lib/stores'
    }
  }
};
```

## Token Savings

By keeping this MCP disabled when not needed:
- **Saves ~10k-15k context tokens** per session
- Enable only when actively building Svelte apps
- Use Context7 for Svelte docs instead: `mcp__context7__get-library-docs` with `/sveltejs/svelte`

## Alternative: Use Context7 for Docs

Instead of loading the Svelte MCP, use Context7 for documentation:

```
mcp__context7__resolve-library-id({ libraryName: "svelte" })
mcp__context7__get-library-docs({ context7CompatibleLibraryID: "/sveltejs/svelte" })
```

This is more token-efficient for documentation lookups.

## Disable After Use

After completing Svelte development, remove from `mcp.json` and restart to reclaim context tokens.

---

*Svelte Framework Skill v1.0*
