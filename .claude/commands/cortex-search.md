# Cortex Search Command

Search Cortex (SiYuan) knowledge base for documents by content, tags, or type.

## Usage

```
/cortex-search <query>
```

## API Pattern

```bash
TOKEN="0fkvtzw0jrat2oht"
CF_CLIENT_ID="6c0fe301311410aea8ca6e236a176938.access"
CF_CLIENT_SECRET="714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3"
URL="https://cortex.aienablement.academy"

# Search by content
SQL="SELECT id, content, box FROM blocks WHERE type='d' AND content LIKE '%QUERY%' LIMIT 20"

curl -s -X POST "${URL}/api/query/sql" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"${SQL}\"}"
```

## Common Queries

### Find orphans (no backlinks)
```sql
SELECT b.id, b.content FROM blocks b
WHERE b.type='d' AND b.id NOT IN
(SELECT DISTINCT def_block_id FROM refs WHERE def_block_id IS NOT NULL)
```

### Count refs
```sql
SELECT COUNT(*) as cnt FROM refs
```

### Find documents by tag attribute
```sql
SELECT block_id, value FROM attributes WHERE name='custom-semantic-tags'
```

## Key Insights

1. Use `type='d'` for documents, `type='p'` for paragraphs
2. `refs.block_id` = source block, `refs.def_block_id` = target block
3. Backlinks appear on document whose ID is in `def_block_id`
4. Use `/api/block/insertBlock` to create content that generates refs
5. Block ref syntax: `((block-id 'anchor text'))` creates refs

## Related

- [[cortex-link-creator.sh]] - Create bidirectional links
- [[cortex-learning-capture.sh]] - Store learnings
- [[cortex-post-task.sh]] - Log completed tasks
