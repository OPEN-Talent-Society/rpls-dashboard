---
name: shadcn-components
description: shadcn/ui component library skill. Use this when you need to browse, search, or install shadcn components. This skill provides guidance on enabling the shadcn MCP server on-demand to save context tokens when not actively working with UI components.
status: active
owner: frontend
last_reviewed_at: 2025-12-02
tags:
  - frontend
  - ui
  - components
  - shadcn
  - react
  - tailwind
dependencies: []
outputs:
  - component-installation
  - component-examples
  - ui-scaffolding
---

# shadcn/ui Components Skill

This skill provides guidance for working with shadcn/ui components. The MCP server is **NOT loaded by default** to save ~4.7k context tokens - enable it only when needed.

## When to Use This Skill

Use this skill when you need to:
- Browse available shadcn components
- Search for specific UI components
- Get component examples and demos
- Install components to your project
- View component source code and dependencies

## Enabling the MCP Server

To enable shadcn MCP, add this to `.claude/mcp.json`:

```json
{
  "shadcn": {
    "type": "stdio",
    "command": "pnpm",
    "args": ["dlx", "shadcn@latest", "mcp"]
  }
}
```

Then restart Claude Code to load the new MCP.

**Quick enable via CLI:**
```bash
claude mcp add shadcn -- pnpm dlx shadcn@latest mcp
```

## Available Tools (when enabled)

### Registry Management
- `mcp__shadcn__get_project_registries` - Get configured registry names from components.json
- `mcp__shadcn__list_items_in_registries` - List items from registries with pagination

### Component Search
- `mcp__shadcn__search_items_in_registries` - Fuzzy search for components
- `mcp__shadcn__view_items_in_registries` - View detailed component info including source

### Examples & Installation
- `mcp__shadcn__get_item_examples_from_registries` - Find usage examples and demos
- `mcp__shadcn__get_add_command_for_items` - Get CLI command to install components
- `mcp__shadcn__get_audit_checklist` - Verify component setup after installation

## Common Workflows

### Find and Install a Component
```
1. Search: mcp__shadcn__search_items_in_registries
   - registries: ["@shadcn"]
   - query: "button"

2. View details: mcp__shadcn__view_items_in_registries
   - items: ["@shadcn/button"]

3. Get examples: mcp__shadcn__get_item_examples_from_registries
   - registries: ["@shadcn"]
   - query: "button-demo"

4. Install: mcp__shadcn__get_add_command_for_items
   - items: ["@shadcn/button"]

5. Run the returned command (e.g., pnpm dlx shadcn@latest add button)
```

### Browse All Components
```
1. List registries: mcp__shadcn__get_project_registries
2. List components: mcp__shadcn__list_items_in_registries
   - registries: ["@shadcn"]
   - limit: 50
```

### Get Component Examples
```
Common patterns:
- "{component}-demo" (e.g., "accordion-demo")
- "{component} example" (e.g., "button example")
- "example-{feature}" (e.g., "example-booking-form")
```

## Without MCP (Manual Installation)

If you don't need the MCP tools, use the CLI directly:

```bash
# Initialize shadcn in project
pnpm dlx shadcn@latest init

# Add components
pnpm dlx shadcn@latest add button card dialog

# Add multiple components at once
pnpm dlx shadcn@latest add button card input label
```

## Project Setup Requirements

Before using shadcn components, ensure your project has:
- `components.json` (created by `shadcn init`)
- Tailwind CSS configured
- React/Next.js project structure

## Token Savings

By keeping this MCP disabled when not needed:
- **Saves ~4.7k context tokens** per session
- Enable only when actively working with UI components
- Disable after completing component work

## Disable After Use

After completing UI work, remove from `mcp.json` and restart to reclaim context tokens.

Or via CLI:
```bash
claude mcp remove shadcn
```

## Slash Commands

Use these without enabling the MCP:

- `/shadcn-add <components>` - Add components to project
  ```
  /shadcn-add button card input
  /shadcn-add form select checkbox dialog
  ```

- `/shadcn-check` - Check if project is set up for shadcn

## Helper Scripts

Located in `.claude/skills/shadcn-components/scripts/`:

- `check-project.sh [dir]` - Check project setup status
- `list-installed.sh [dir]` - List installed components
- `add-components.sh <components...>` - Quick add components

```bash
# Check project setup
.claude/skills/shadcn-components/scripts/check-project.sh .

# List what's installed
.claude/skills/shadcn-components/scripts/list-installed.sh .

# Add components
.claude/skills/shadcn-components/scripts/add-components.sh button card input
```

---

*shadcn/ui Components Skill v1.0*
