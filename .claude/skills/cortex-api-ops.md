# Cortex API Operations Skill

Master skill for all Cortex (SiYuan) API operations.

## Authentication

```bash
TOKEN="0fkvtzw0jrat2oht"
CF_CLIENT_ID="6c0fe301311410aea8ca6e236a176938.access"
CF_CLIENT_SECRET="714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3"
URL="https://cortex.aienablement.academy"

# Header pattern for ALL requests
-H "Authorization: Token ${TOKEN}"
-H "CF-Access-Client-Id: ${CF_CLIENT_ID}"
-H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}"
-H "Content-Type: application/json"
```

## Core APIs

### 1. SQL Query (`/api/query/sql`)
```bash
curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"SELECT id, content FROM blocks WHERE type='d' LIMIT 10\"}"
```

### 2. Insert Block (`/api/block/insertBlock`)
**CRITICAL: This is how you create refs/backlinks!**
```bash
curl -s -X POST "${URL}/api/block/insertBlock" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"dataType\": \"markdown\", \"data\": \"Content with ((block-id 'anchor'))\", \"previousID\": \"\", \"parentID\": \"TARGET_PARENT_ID\"}"
```

### 3. Set Attributes (`/api/attr/setBlockAttrs`)
**Note: Only for metadata, does NOT create refs!**
```bash
curl -s -X POST "${URL}/api/attr/setBlockAttrs" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"BLOCK_ID\", \"attrs\": {\"custom-tag\": \"value\"}}"
```

## Block Types

| Type | Description |
|------|-------------|
| `d`  | Document (top-level) |
| `p`  | Paragraph |
| `h`  | Heading |
| `l`  | List |
| `c`  | Code block |
| `t`  | Table |

## Refs Table Structure

| Column | Description |
|--------|-------------|
| `block_id` | Source block containing the reference |
| `def_block_id` | Target block being referenced (backlink appears here) |
| `root_id` | Root document of source |
| `def_block_root_id` | Root document of target |

## Block Reference Syntax

```markdown
((block-id))                    # Basic ref
((block-id 'anchor text'))      # Ref with custom anchor
((block-id "anchor text"))      # Also works with double quotes
```

## Common SQL Queries

### Find orphans
```sql
SELECT id, content FROM blocks b
WHERE type='d' AND id NOT IN
(SELECT DISTINCT def_block_id FROM refs WHERE def_block_id IS NOT NULL)
```

### Count refs
```sql
SELECT COUNT(*) as cnt FROM refs
```

### Get documents with specific attribute
```sql
SELECT block_id, value FROM attributes
WHERE name='custom-semantic-tags'
```

### Search documents by content
```sql
SELECT id, content FROM blocks
WHERE type='d' AND content LIKE '%keyword%'
```

## Notebook IDs (Updated 2025-12-01)

| Notebook | ID |
|----------|-----|
| Resources | `20251201183343-ujsixib` |
| Knowledge Base | `20251103053840-moamndp` |
| Projects | `20251103053911-8ex6uns` |
| Archives | `20251201183343-xf2snc8` |
| Areas | `20251201183343-543piyt` |

## Key Learnings

1. **insertBlock creates refs** - setBlockAttrs does NOT
2. **Backlinks on def_block_id** - Not on block_id
3. **bash 3.x on macOS** - No associative arrays
4. **Rebuild index after batch ops** - SiYuan may cache
5. **Always use new notebook IDs** - Old IDs (2023*) no longer valid

## Related Files

- `.claude/hooks/cortex-post-task.sh`
- `.claude/hooks/cortex-learning-capture.sh`
- `.claude/hooks/cortex-link-creator.sh`
- `.claude/commands/cortex-search.md`
- `.claude/commands/cortex-fix-orphans.md`
