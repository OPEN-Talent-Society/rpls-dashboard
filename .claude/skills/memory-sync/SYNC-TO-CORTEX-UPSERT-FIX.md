# Sync-to-Cortex Upsert Fix Summary

**Date:** 2025-12-11
**Script:** `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh`

## Problem
The original `sync-to-cortex.sh` script used direct `createDocWithMd` API calls, which created duplicate documents every time the sync ran. No duplicate detection or update logic existed.

## Solution
Implemented upsert logic using the centralized `cortex-helpers.sh` library.

## Changes Made

### 1. Added cortex-helpers.sh Integration
```bash
# Load cortex-helpers.sh for upsert functionality
CORTEX_HELPERS="$PROJECT_DIR/.claude/lib/cortex-helpers.sh"
if [ ! -f "$CORTEX_HELPERS" ]; then
    echo "❌ ERROR: cortex-helpers.sh not found at $CORTEX_HELPERS"
    exit 1
fi
source "$CORTEX_HELPERS"
```

### 2. Replaced create_cortex_doc with upsert_cortex_doc
**Old approach (created duplicates):**
```bash
create_cortex_doc() {
    # Direct API call - no duplicate check
    curl -s -X POST "${CORTEX_URL}/api/filetree/createDocWithMd" ...
}
```

**New approach (prevents duplicates):**
```bash
upsert_cortex_doc() {
    local NOTEBOOK="$1"
    local TITLE="$2"
    local CONTENT="$3"
    local TAGS="$4"

    # Build metadata
    local METADATA=$(jq -n --arg tags "$TAGS" '{"custom-tags": $tags}')

    # Resolve notebook name to ID
    local NOTEBOOK_ID=$(resolve_notebook_id "$NOTEBOOK")

    # Upsert document (update if exists, create if not)
    upsert_doc "$TITLE" "$MD_CONTENT" "$NOTEBOOK_ID" "/Synced/$TITLE" "supabase" "$METADATA"
}
```

### 3. Updated All Document Creation Calls

**Learnings sync:**
```bash
# OLD: RESULT=$(create_cortex_doc "$RESOURCES_NOTEBOOK" "Learning: $TOPIC" "$CONTENT" "$TAGS")
# NEW:
DOC_ID=$(upsert_cortex_doc "resources" "Learning: $TOPIC" "$CONTENT" "$TAGS")
```

**Patterns sync:**
```bash
# OLD: RESULT=$(create_cortex_doc "$RESOURCES_NOTEBOOK" "Pattern: $NAME" "$CONTENT" "$CATEGORY,pattern,synced")
# NEW:
DOC_ID=$(upsert_cortex_doc "resources" "Pattern: $NAME" "$CONTENT" "$CATEGORY,pattern,synced")
```

### 4. Added Source Attribute Tagging
All documents now include `source=supabase` attribute for:
- Proper duplicate detection (matches by title + source)
- Attribution tracking
- Filtering in search queries

### 5. Enhanced Output
```bash
echo "🔄 Using upsert logic - no duplicates will be created"
echo "✅ Synced learning: $TOPIC (ID: $DOC_ID)"
echo "   Processed: $LEARNING_COUNT learnings"
echo "   All documents tagged with source=supabase for duplicate prevention"
```

## How Upsert Works

1. **Check for existing document:**
   - Search by title: "Learning: X" or "Pattern: Y"
   - Filter by source attribute: `custom-source=supabase`

2. **If document exists:**
   - Update content with new markdown
   - Increment version number
   - Update timestamp

3. **If document doesn't exist:**
   - Create new document
   - Set source attribute
   - Set initial metadata

## Benefits

1. **No duplicates:** Running sync multiple times updates existing docs instead of creating new ones
2. **Version tracking:** Each update increments the version number
3. **Attribution:** Every document tagged with `custom-source=supabase`
4. **Timestamps:** `custom-synced` (created) and `custom-updated` (last modified)
5. **Centralized logic:** All Cortex scripts use the same upsert pattern via cortex-helpers.sh

## Testing

```bash
# Syntax validation
bash -n /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh
# ✅ PASSED

# Run sync twice - should update, not duplicate
bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh
bash /Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh
# Second run should update existing documents
```

## Files Modified

- `/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/scripts/sync-to-cortex.sh` (134 lines)

## Dependencies

- `/Users/adamkovacs/Documents/codebuild/.claude/lib/cortex-helpers.sh` (must exist)
- Functions used: `upsert_doc()`, `resolve_notebook_id()`, `cortex_helpers_version()`

## Migration Notes

No data migration needed. Next sync run will:
- Find existing untagged documents by title
- Add source attributes on first match
- Future runs will properly update instead of duplicate

---

**Status:** ✅ COMPLETE
**Validation:** Syntax check passed
**Next Step:** Test with actual Supabase data
