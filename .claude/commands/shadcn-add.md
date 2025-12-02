---
description: Add shadcn/ui components to the current project
argument-hint: <components...>
allowed-tools:
  - Bash
  - Read
  - Glob
---

# Add shadcn/ui Components

Add the specified shadcn/ui components to the current project.

## Arguments
$ARGUMENTS - Component names to add (e.g., "button card input")

## Instructions

1. First check if the project has `components.json` (shadcn initialized)
2. If not initialized, ask if user wants to run `pnpm dlx shadcn@latest init`
3. Run `pnpm dlx shadcn@latest add <components>` to install
4. Report which components were added successfully

## Popular Components Reference

**Core UI:**
- button, card, input, label, textarea, badge

**Forms:**
- form, select, checkbox, radio-group, switch, slider

**Overlays:**
- dialog, sheet, dropdown-menu, popover, tooltip, hover-card

**Navigation:**
- tabs, accordion, navigation-menu, breadcrumb, sidebar

**Data Display:**
- table, avatar, separator, skeleton

**Feedback:**
- alert, toast, sonner, progress

**Date/Time:**
- calendar, date-picker

## Example Usage

```
/shadcn-add button card input
/shadcn-add form select checkbox
/shadcn-add dialog sheet toast
```
