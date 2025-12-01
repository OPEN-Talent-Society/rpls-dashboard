# Cortex Export Command

Export documents and content from Cortex (SiYuan) knowledge base in various formats.

## Usage

```
/cortex-export <document_id> [format] [options]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `document_id` | Yes | Block/document ID to export (e.g., `20251201183343-ujsixib`) |
| `format` | No | Export format: `md` (default), `html`, `pdf`, `docx` |
| `options` | No | Additional options (see below) |

## Options

- `--recursive` - Export document with all child blocks
- `--assets` - Include linked assets (images, files)
- `--refs` - Include referenced blocks inline
- `--notebook <id>` - Export entire notebook
- `--query <sql>` - Export results of SQL query

## API Configuration

```bash
TOKEN="0fkvtzw0jrat2oht"
CF_CLIENT_ID="6c0fe301311410aea8ca6e236a176938.access"
CF_CLIENT_SECRET="714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3"
URL="https://cortex.aienablement.academy"
```

## Export API Endpoints

### Export Markdown Content
```bash
curl -s -X POST "${URL}/api/export/exportMdContent" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

**Response:**
```json
{
  "code": 0,
  "msg": "",
  "data": {
    "hPath": "/Notebook/Path/Document",
    "content": "# Document Title\n\nMarkdown content here..."
  }
}
```

### Export HTML Content
```bash
curl -s -X POST "${URL}/api/export/exportHTML" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID", "savePath": "/tmp/export"}'
```

### Export Preview HTML (Single Block)
```bash
curl -s -X POST "${URL}/api/export/preview" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"id": "BLOCK_ID"}'
```

### Export Notebook as Markdown Archive
```bash
curl -s -X POST "${URL}/api/export/exportNotebookMd" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "NOTEBOOK_ID"}'
```

### Export SiYuan (.sy) Format
```bash
curl -s -X POST "${URL}/api/export/exportSY" \
  -H "Authorization: Token ${TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}'
```

## PARA Notebook IDs (2025-12-01)

| Notebook | ID | Purpose |
|----------|-----|---------|
| Projects | `20251103053911-8ex6uns` | Active project documentation |
| Areas | `20251201183343-543piyt` | Ongoing responsibilities |
| Resources | `20251201183343-ujsixib` | Reference materials, learnings |
| Archives | `20251201183343-xf2snc8` | Completed work (>30 days) |
| Knowledge Base | `20251103053840-moamndp` | Core KB, glossary |

## Examples

### Export Single Document to Markdown
```bash
# Export a learning document
/cortex-export 20251201183343-ujsixib md

# Using curl directly
curl -s -X POST "https://cortex.aienablement.academy/api/export/exportMdContent" \
  -H "Authorization: Token 0fkvtzw0jrat2oht" \
  -H "CF-Access-Client-Id: 6c0fe301311410aea8ca6e236a176938.access" \
  -H "CF-Access-Client-Secret: 714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3" \
  -H "Content-Type: application/json" \
  -d '{"id": "20251201183343-ujsixib"}' | jq -r '.data.content'
```

### Export Entire Notebook
```bash
# Export Resources notebook as markdown archive
/cortex-export --notebook 20251201183343-ujsixib

# Using curl
curl -s -X POST "https://cortex.aienablement.academy/api/export/exportNotebookMd" \
  -H "Authorization: Token 0fkvtzw0jrat2oht" \
  -H "CF-Access-Client-Id: 6c0fe301311410aea8ca6e236a176938.access" \
  -H "CF-Access-Client-Secret: 714c7fc0d9cf883295d1c5eb730ecb64e9b5fe0418605009cafde13b4900afb3" \
  -H "Content-Type: application/json" \
  -d '{"notebook": "20251201183343-ujsixib"}'
```

### Export Query Results
```bash
# Export all learning documents
/cortex-export --query "SELECT * FROM blocks WHERE content LIKE '%#learning%' AND type='d'"
```

### Bulk Export with SQL
```javascript
// MCP tool pattern for bulk export
mcp__cortex__siyuan_request({
  endpoint: "/api/query/sql",
  payload: {
    stmt: `SELECT id, content FROM blocks
           WHERE type='d'
           AND box='20251201183343-ujsixib'
           LIMIT 50`
  }
})
// Then iterate and export each document
```

## MCP Tool Integration

```javascript
// Export using MCP tool
mcp__cortex__siyuan_request({
  endpoint: "/api/export/exportMdContent",
  payload: {
    id: "DOCUMENT_ID"
  }
})

// Export notebook
mcp__cortex__siyuan_request({
  endpoint: "/api/export/exportNotebookMd",
  payload: {
    notebook: "20251201183343-ujsixib"
  }
})
```

## Use Cases

### 1. Backup Knowledge Base
Export all documents for backup or migration:
```bash
# Export each PARA notebook
for notebook in "20251103053911-8ex6uns" "20251201183343-543piyt" "20251201183343-ujsixib" "20251201183343-xf2snc8" "20251103053840-moamndp"; do
  /cortex-export --notebook $notebook
done
```

### 2. Share Learning with Team
Export a learning document to share:
```bash
/cortex-export 20251201-learning-api-patterns md --refs
```

### 3. Generate Static Documentation
Export for external documentation site:
```bash
/cortex-export 20251103053840-moamndp html --recursive --assets
```

### 4. Archive Completed Projects
Export completed project docs before archiving:
```bash
/cortex-export --query "SELECT id FROM blocks WHERE type='d' AND box='20251103053911-8ex6uns' AND updated < date('now', '-30 days')"
```

## Related Commands

- `/cortex-search` - Search knowledge base
- `/cortex-fix-orphans` - Fix orphan documents
- `/task-complete` - Complete task and archive to Cortex

## Related Hooks

- `cortex-template-create.sh` - Create documents from templates
- `cortex-learning-capture.sh` - Capture learnings
- `post-task-cortex-log.sh` - Log task completion

## Related Resources

- **Agent**: `.claude/agents/core/cortex-ops.md`
- **Skill**: `.claude/skills/cortex-api-ops.md`
- **Docs**: `.claude/docs/TOOL-REFERENCE.md#cortex-siyuan`

---

*Command: cortex-export | Version: 1.0.0 | Updated: 2025-12-01*
*Part of Cortex Excellence Initiative*
