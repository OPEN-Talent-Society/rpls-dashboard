---
name: cortex-knowledge
description: "Cortex (SiYuan) knowledge management using REST API calls. Uses Tier 1 curl for simple operations, enables MCP for complex workflows. Saves tokens when MCP is disabled."
---

# Cortex Knowledge Management Skill

## Overview

This skill provides Cortex (SiYuan) knowledge management with a **two-tier approach**:
1. **Simple ops (Tier 1)**: Use curl REST API calls directly (no MCP needed)
2. **Complex ops (Tier 2)**: Enable Cortex MCP for batch operations

## Configuration

```bash
# Load credentials from .env (NEVER hardcode tokens!)
source /Users/adamkovacs/Documents/codebuild/.env

CORTEX_URL="https://cortex.aienablement.academy"
TOKEN="${CORTEX_TOKEN}"
CF_CLIENT_ID="${CF_ACCESS_CLIENT_ID}"
CF_CLIENT_SECRET="${CF_ACCESS_CLIENT_SECRET}"
```

## PARA Notebook IDs

| Notebook | ID | Purpose |
|----------|-----|---------|
| 01 Projects | `20251103053911-8ex6uns` | Active project documentation |
| 02 Areas | `20251201183343-543piyt` | Ongoing responsibilities |
| 03 Resources | `20251201183343-ujsixib` | Reference materials, learnings |
| 04 Archives | `20251201183343-xf2snc8` | Completed work (>30 days) |
| 05 Knowledge Base | `20251103053840-moamndp` | Core KB, glossary |
| 11 Agents | `20251103053916-bq6qbgu` | Agent definitions, personas |

---

## Tier 1: Simple Operations (No MCP)

### Search Documents
```bash
source /Users/adamkovacs/Documents/codebuild/.env

SQL="SELECT id, content, box FROM blocks WHERE type='d' AND content LIKE '%keyword%' LIMIT 20"

curl -s -X POST "${CORTEX_URL}/api/query/sql" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"${SQL}\"}" | jq
```

### Create Document
```bash
curl -s -X POST "${CORTEX_URL}/api/filetree/createDocWithMd" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{
    "notebook": "20251201183343-ujsixib",
    "path": "/Learning-Title",
    "markdown": "# Learning\n\nContent here..."
  }' | jq
```

### Get Document Content
```bash
curl -s -X POST "${CORTEX_URL}/api/export/exportMdContent" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{"id": "DOCUMENT_ID"}' | jq -r '.data.content'
```

### Insert Block with Backlink
```bash
# Creates refs/backlinks on target document
curl -s -X POST "${CORTEX_URL}/api/block/insertBlock" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{
    "dataType": "markdown",
    "data": "Related: ((TARGET_DOC_ID '\''Title'\''))",
    "previousID": "",
    "parentID": "SOURCE_DOC_ID"
  }' | jq
```

### Set Document Attributes
```bash
curl -s -X POST "${CORTEX_URL}/api/attr/setBlockAttrs" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "BLOCK_ID",
    "attrs": {
      "custom-semantic-tags": "learning,api,technical"
    }
  }' | jq
```

### Count Documents
```bash
SQL="SELECT COUNT(*) as cnt FROM blocks WHERE type='d'"

curl -s -X POST "${CORTEX_URL}/api/query/sql" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"${SQL}\"}" | jq
```

---

## Tier 2: Enable MCP for Complex Operations

For batch operations requiring:
- Bulk document creation
- Complex queries
- Notebook-wide operations
- Backlink management

### Enable MCP Temporarily

**Via Claude Code CLI**
```bash
# The Cortex MCP server is local
claude mcp add cortex -- node /Users/adamkovacs/Documents/codebuild/mcp-servers/cortex/index.js

# After task, remove to restore token savings
claude mcp remove cortex
```

### MCP Tools Available (When Enabled)

| Tool | Purpose |
|------|---------|
| `siyuan_request` | Generic API endpoint caller |
| `siyuan_search` | Full-text search |

---

## Helper Scripts

### scripts/search.sh
```bash
#!/bin/bash
# Search Cortex documents
source /Users/adamkovacs/Documents/codebuild/.env

QUERY="${1:-}"
LIMIT="${2:-20}"

if [ -z "$QUERY" ]; then
  echo "Usage: search.sh <query> [limit]"
  exit 1
fi

SQL="SELECT id, content, box FROM blocks WHERE type='d' AND content LIKE '%${QUERY}%' LIMIT ${LIMIT}"

curl -s -X POST "https://cortex.aienablement.academy/api/query/sql" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"stmt\": \"${SQL}\"}" | jq '.data[] | {id: .id, content: .content[0:100]}'
```

### scripts/create-learning.sh
```bash
#!/bin/bash
# Create a learning document in Cortex
source /Users/adamkovacs/Documents/codebuild/.env

TITLE="${1:-Untitled Learning}"
CONTENT="${2:-}"
NOTEBOOK="20251201183343-ujsixib"  # Resources notebook

# Sanitize title for path
PATH_TITLE=$(echo "$TITLE" | tr ' ' '-' | tr -cd '[:alnum:]-')

curl -s -X POST "https://cortex.aienablement.academy/api/filetree/createDocWithMd" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{
    \"notebook\": \"${NOTEBOOK}\",
    \"path\": \"/${PATH_TITLE}\",
    \"markdown\": \"# ${TITLE}\\n\\n${CONTENT}\"
  }" | jq

echo "Learning created: ${TITLE}"
```

### scripts/export-doc.sh
```bash
#!/bin/bash
# Export a Cortex document to markdown
source /Users/adamkovacs/Documents/codebuild/.env

DOC_ID="${1}"

if [ -z "$DOC_ID" ]; then
  echo "Usage: export-doc.sh <document_id>"
  exit 1
fi

curl -s -X POST "https://cortex.aienablement.academy/api/export/exportMdContent" \
  -H "Authorization: Token ${CORTEX_TOKEN}" \
  -H "CF-Access-Client-Id: ${CF_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CF_ACCESS_CLIENT_SECRET}" \
  -H "Content-Type: application/json" \
  -d "{\"id\": \"${DOC_ID}\"}" | jq -r '.data.content'
```

---

## Common SQL Queries

### Find Orphans (no backlinks)
```sql
SELECT b.id, b.content FROM blocks b
WHERE b.type='d' AND b.id NOT IN
(SELECT DISTINCT def_block_id FROM refs WHERE def_block_id IS NOT NULL)
```

### Count Refs
```sql
SELECT COUNT(*) as cnt FROM refs
```

### Get Documents with Tag
```sql
SELECT block_id, value FROM attributes WHERE name='custom-semantic-tags'
```

### Documents in Notebook
```sql
SELECT id, content FROM blocks WHERE type='d' AND box='NOTEBOOK_ID'
```

---

## When to Use MCP vs Curl

| Use Case | Recommendation |
|----------|----------------|
| Search documents | Tier 1 (curl) |
| Create single document | Tier 1 (curl) |
| Get document content | Tier 1 (curl) |
| Bulk document creation | Tier 2 (MCP) |
| Complex backlink operations | Tier 2 (MCP) |
| Notebook-wide exports | Tier 2 (MCP) |

---

## Related Resources

- **Agent**: `/Users/adamkovacs/Documents/codebuild/.claude/agents/core/cortex-ops.md`
- **Hooks**: `cortex-post-task.sh`, `cortex-learning-capture.sh`
- **Docs**: `/Users/adamkovacs/Documents/codebuild/.claude/docs/CORTEX-API-OPS.md`
- **Commands**: `/cortex-search`, `/cortex-export`
