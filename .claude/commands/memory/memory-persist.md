# memory-persist

Persist memory across sessions.

## Usage
```bash
/opt/homebrew/bin/claude-flow memory persist [options]
```

## Options
- `--export <file>` - Export to file
- `--import <file>` - Import from file
- `--compress` - Compress memory data

## Examples
```bash
# Export memory
/opt/homebrew/bin/claude-flow memory persist --export memory-backup.json

# Import memory
/opt/homebrew/bin/claude-flow memory persist --import memory-backup.json

# Compressed export
/opt/homebrew/bin/claude-flow memory persist --export memory.gz --compress
```
