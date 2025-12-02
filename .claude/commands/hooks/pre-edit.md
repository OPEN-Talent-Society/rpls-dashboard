# pre-edit

Hook executed before file edits.

## Usage
```bash
pnpm dlx claude-flow hook pre-edit [options]
```

## Options
- `--file <path>` - File to be edited
- `--validate-syntax` - Validate syntax before edit
- `--backup` - Create backup

## Examples
```bash
# Pre-edit hook
pnpm dlx claude-flow hook pre-edit --file src/api.js

# With validation
pnpm dlx claude-flow hook pre-edit --file src/api.js --validate-syntax

# Create backup
pnpm dlx claude-flow hook pre-edit --file src/api.js --backup
```
