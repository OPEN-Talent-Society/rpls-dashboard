# Smart Document Indexer

AI-powered document indexing with automatic tagging, descriptions, and semantic search. Index business documents (PDFs, DOCX, XLSX, transcriptions) to Qdrant with Supabase catalog.

## Features

- **AI-Generated Metadata**: Gemini 1.5 Flash generates descriptions, tags, and categories
- **Chunk Context Breadcrumbs**: Each chunk knows about its neighbors for navigation
- **Dual Storage**: Full content + vectors in Qdrant, lightweight catalog in Supabase
- **Smart Chunking**: Sentence-aware splitting with overlap for context preservation

## Supported File Types

| Type | Extensions | Extraction Method |
|------|------------|-------------------|
| PDF | `.pdf` | pdfplumber with page markers |
| Word | `.docx` | python-docx paragraphs |
| Excel | `.xlsx`, `.xls` | pandas with sheet markers |
| CSV | `.csv` | pandas to markdown |
| Subtitles | `.vtt`, `.srt` | Cleaned transcript text |
| Text | `.md`, `.txt`, `.json` | Direct read |

## Usage

### Index a Directory

```bash
# Index all documents in a directory
bash .claude/skills/memory-sync/scripts/index-documents-to-qdrant.sh /path/to/documents

# Dry run (preview what would be indexed)
bash .claude/skills/memory-sync/scripts/index-documents-to-qdrant.sh /path/to/documents --dry-run
```

### Search Indexed Documents

```bash
# Semantic search via Qdrant
curl -s "${QDRANT_URL}/collections/agent_memory/points/search" \
  -H "api-key: ${QDRANT_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [...],  # Your query embedding
    "filter": {"must": [{"key": "source", "match": {"value": "document_indexer"}}]},
    "limit": 10,
    "with_payload": true
  }'
```

### Browse Document Catalog (Supabase)

```bash
# List all indexed documents
curl "${SUPABASE_URL}/rest/v1/document_catalog?select=*&order=indexed_at.desc" \
  -H "apikey: ${SUPABASE_KEY}"

# Filter by category
curl "${SUPABASE_URL}/rest/v1/document_catalog?category=eq.training" \
  -H "apikey: ${SUPABASE_KEY}"

# Search by tag
curl "${SUPABASE_URL}/rest/v1/rpc/search_documents_by_tag" \
  -H "apikey: ${SUPABASE_KEY}" \
  -d '{"p_tag": "ai-training"}'
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Document Processing Pipeline                  │
├─────────────────────────────────────────────────────────────────┤
│  1. Extract Text (pdfplumber/python-docx/pandas)                │
│  2. Generate AI Metadata (Gemini 1.5 Flash)                     │
│     - Description (1-2 sentences)                               │
│     - Tags (3-7 relevant keywords)                              │
│     - Category (business, technical, training, etc.)            │
│  3. Smart Chunking with Breadcrumbs                             │
│     - Sentence-aware splitting                                  │
│     - Prev/Next chunk summaries                                 │
│  4. Generate Embeddings (gemini-embedding-001 + outputDimensionality: 768) │
│  5. Store in Qdrant (full content + vector)                     │
│  6. Store in Supabase (lightweight catalog)                     │
└─────────────────────────────────────────────────────────────────┘
```

## Payload Structure

Each chunk stored in Qdrant includes:

```json
{
  "doc_id": "abc123",
  "filepath": "documents/training/onboarding.pdf",
  "filename": "onboarding.pdf",
  "filetype": "pdf",
  "text": "Full chunk content...",
  "chunk_index": 2,
  "total_chunks": 15,
  "prev_chunk_summary": "Introduction to company culture...",
  "next_chunk_summary": "Benefits and compensation...",
  "doc_description": "Employee onboarding guide covering policies and procedures",
  "tags": ["onboarding", "hr", "policies", "employee-handbook"],
  "doc_category": "training",
  "source": "document_indexer",
  "category": "business_document",
  "indexed_at": "2024-12-09T01:30:00Z"
}
```

## Dependencies

Python packages (install if not present):
```bash
pip install pdfplumber python-docx pandas openpyxl tabulate
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `QDRANT_URL` | Qdrant endpoint (default: https://qdrant.harbor.fyi) |
| `QDRANT_API_KEY` | Qdrant API key |
| `GOOGLE_GEMINI_API_KEY` | Gemini API key for embeddings + tagging |
| `PUBLIC_SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase service role key |

## Supabase Setup

Run this migration in Supabase SQL Editor:
`.claude/skills/memory-sync/migrations/001_document_catalog.sql`

## Related Commands

- `/index-documents` - Index documents from a directory
- `/search-documents` - Search indexed documents semantically
- `/document-catalog` - Browse the document catalog
