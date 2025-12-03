# post-edit

Hook executed after file edits.

## Usage
```bash
/opt/homebrew/bin/claude-flow hook post-edit [options]
```

## Options
- `--file <path>` - Edited file
- `--memory-key <key>` - Memory storage key
- `--format` - Auto-format code

## Examples
```bash
# Post-edit hook
/opt/homebrew/bin/claude-flow hook post-edit --file src/api.js

# Store in memory
/opt/homebrew/bin/claude-flow hook post-edit --file src/api.js --memory-key "api-changes"

# With formatting
/opt/homebrew/bin/claude-flow hook post-edit --file src/api.js --format
```
