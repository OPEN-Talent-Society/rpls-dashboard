# Cortex Fix Orphans Command

Fix orphaned documents in Cortex by creating bidirectional links.

## Problem

Orphaned documents = documents with no incoming backlinks (not in `refs.def_block_id`)

## Solution Strategy

1. **Identify orphans**: Query `refs.def_block_id` for documents NOT referenced
2. **Add forward links**: From connected docs TO orphans using `((block-id))`
3. **Add reverse links**: From orphans TO connected docs
4. **Rebuild index**: SiYuan Settings > Search > Rebuild Index

## API Pattern

```bash
# Load credentials from .env (NEVER hardcode tokens!)
source /Users/adamkovacs/Documents/codebuild/.env

TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
URL="https://cortex.aienablement.academy"

# Find orphans
SQL_ORPHANS="SELECT b.id, b.content FROM blocks b WHERE b.type='d' AND b.id NOT IN (SELECT DISTINCT def_block_id FROM refs WHERE def_block_id IS NOT NULL)"

# Insert block with ref (creates backlink on target)
curl -s -X POST "${URL}/api/block/insertBlock" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"Related: ((TARGET_DOC_ID 'Title'))\", \"previousID\": \"\", \"parentID\": \"SOURCE_DOC_ID\"}"
```

## Critical Learnings

### ✅ CORRECT: Use insertBlock with content
- Creates blocks with `((block-id))` syntax IN the content
- SiYuan parses this and populates `refs` table
- Backlinks appear on target document

### ❌ WRONG: Use setBlockAttrs
- Only sets metadata attributes
- Does NOT create refs or backlinks
- Links stored but invisible to users

### Bash Compatibility (macOS)
- macOS ships with bash 3.x
- NO associative arrays (`declare -A` fails)
- Use separate variables or jq for key-value storage

## Fix Script Location

```
/tmp/cortex-bidirectional-fix.sh
```

## After Running Fix

1. Check refs: `SELECT COUNT(*) FROM refs`
2. Check orphans: Use SQL_ORPHANS query above
3. **Rebuild SiYuan index** if orphan rate unchanged:
   - SiYuan Settings > Search > Rebuild Index
   - Or restart SiYuan to re-parse content

## Related

- [[cortex-link-creator.sh]] - Individual link creation
- [[cortex-verify.sh]] - Verification script
