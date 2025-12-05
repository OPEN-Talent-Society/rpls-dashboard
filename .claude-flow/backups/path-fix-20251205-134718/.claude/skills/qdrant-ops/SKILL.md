# Qdrant Vector Database Operations

## Overview

**Qdrant** is a high-performance vector database that powers semantic search and similarity matching across our memory system. It enables Claude Code to find relevant context, patterns, and learnings based on meaning rather than exact keyword matches.

### Role in Memory System
- **Semantic Search**: Find similar tasks, patterns, and code by meaning
- **Context Retrieval**: Pull relevant memories for new tasks
- **Pattern Recognition**: Identify similar problems and solutions
- **Code Discovery**: Search codebase semantically ("authentication flow" finds auth code)
- **Learning Indexing**: Store and retrieve learned patterns efficiently

### Architecture Position
```
Supabase (source) → Qdrant (vector search) → Claude Code (retrieval)
     ↓                      ↓                        ↓
  Structured data      Semantic index          Context-aware AI
```

## Configuration

### Endpoint
```bash
QDRANT_URL=http://qdrant.harbor.fyi
QDRANT_API_KEY=<optional-for-cloud>
```

### Embedding Model (STANDARD)
**PRIMARY: Gemini text-embedding-004**
- **Model**: `text-embedding-004` (Google Gemini)
- **Dimensions**: 768
- **Cost**: FREE (1500 requests/minute)
- **Speed**: ~300ms for 1K tokens
- **Quality**: Superior semantic understanding
- **Status**: This is our chosen approach - NOT migrating to FastEmbed

**FALLBACK ONLY: Qdrant MCP Server with FastEmbed**
- **Model**: `BAAI/bge-small-en-v1.5` (384 dims)
- **Use Case**: Optional fallback only, not primary approach
- **Note**: We prioritize direct Gemini API calls over MCP server

**Why Gemini over FastEmbed:**
1. Higher quality semantic understanding
2. Free tier is sufficient (1500 req/min)
3. Already configured and working
4. Direct API control vs MCP abstraction

### Health Check
```bash
curl http://qdrant.harbor.fyi/healthz
# Response: {"status":"ok"}
```

## Collections Schema

### 1. agent_memory
**Purpose**: Session memories and task context

**Schema**:
```json
{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "session_id": "keyword",
    "task_id": "integer",
    "content": "text",
    "timestamp": "datetime",
    "status": "keyword",
    "tags": "keyword[]"
  }
}
```

**Note**: All collections use 768 dimensions to match Gemini embeddings.

**Indexed Fields**: `session_id`, `task_id`, `status`, `tags`

**Example Document**:
```json
{
  "id": "mem_20251203_001",
  "vector": [0.123, 0.456, ...],
  "payload": {
    "session_id": "session-20251203-155940",
    "task_id": 226,
    "content": "Implemented NocoDB batch update pattern with 10-record limit",
    "timestamp": "2025-12-03T15:59:40Z",
    "status": "completed",
    "tags": ["nocodb", "batch-operations", "learning"]
  }
}
```

### 2. learnings
**Purpose**: Learned patterns and insights

**Schema**:
```json
{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "learning_type": "keyword",
    "category": "keyword",
    "problem": "text",
    "solution": "text",
    "effectiveness": "float",
    "created_at": "datetime"
  }
}
```

**Indexed Fields**: `learning_type`, `category`, `effectiveness`

**Example Document**:
```json
{
  "id": "learn_nocodb_batch",
  "vector": [0.234, 0.567, ...],
  "payload": {
    "learning_type": "technical-constraint",
    "category": "api-limits",
    "problem": "NocoDB updateRecords fails with >10 records",
    "solution": "Split updates into batches of 10 using array chunking",
    "effectiveness": 0.95,
    "created_at": "2025-12-03T16:00:00Z"
  }
}
```

### 3. patterns
**Purpose**: Successful approaches and strategies

**Schema**:
```json
{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "pattern_name": "keyword",
    "context": "text",
    "implementation": "text",
    "success_rate": "float",
    "use_count": "integer",
    "last_used": "datetime"
  }
}
```

**Indexed Fields**: `pattern_name`, `success_rate`, `use_count`

**Example Document**:
```json
{
  "id": "pattern_parallel_batch",
  "vector": [0.345, 0.678, ...],
  "payload": {
    "pattern_name": "parallel-batch-operations",
    "context": "When multiple independent operations need execution",
    "implementation": "Use BatchTool with multiple tool calls in single message",
    "success_rate": 0.92,
    "use_count": 47,
    "last_used": "2025-12-03T16:00:00Z"
  }
}
```

### 4. codebase
**Purpose**: Code snippets and implementations

**Schema**:
```json
{
  "vectors": {
    "size": 768,
    "distance": "Cosine"
  },
  "payload_schema": {
    "file_path": "keyword",
    "language": "keyword",
    "code_snippet": "text",
    "description": "text",
    "tags": "keyword[]",
    "last_modified": "datetime"
  }
}
```

**Indexed Fields**: `file_path`, `language`, `tags`

**Example Document**:
```json
{
  "id": "code_nocodb_batch_helper",
  "vector": [0.456, 0.789, ...],
  "payload": {
    "file_path": "/Users/adamkovacs/.claude/utils/nocodb-batch.js",
    "language": "javascript",
    "code_snippet": "function chunkArray(arr, size) { return Array.from({ length: Math.ceil(arr.length / size) }, (_, i) => arr.slice(i * size, i * size + size)); }",
    "description": "Utility to split array into chunks for batch operations",
    "tags": ["utility", "batch", "nocodb"],
    "last_modified": "2025-12-03T16:00:00Z"
  }
}
```

## Operations

### Index Data (from Supabase)

**Purpose**: Sync structured data from Supabase to Qdrant with vector embeddings

**Workflow**:
1. Query Supabase for new/updated records
2. Generate embeddings using Gemini API (768 dims)
3. Upsert to Qdrant with metadata

**Example (Index Task Memory)**:
```bash
# 1. Get task from Supabase
curl -X GET "https://your-supabase.supabase.co/rest/v1/tasks?id=eq.226" \
  -H "apikey: YOUR_SUPABASE_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_KEY"

# 2. Generate embedding (via Gemini API - FREE)
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "models/text-embedding-004",
    "content": {
      "parts": [{
        "text": "Implemented NocoDB batch update pattern with 10-record limit"
      }]
    }
  }'

# 3. Upsert to Qdrant
curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/points" \
  -H "Content-Type: application/json" \
  -d '{
    "points": [
      {
        "id": "mem_20251203_001",
        "vector": [0.123, 0.456, ...],
        "payload": {
          "session_id": "session-20251203-155940",
          "task_id": 226,
          "content": "Implemented NocoDB batch update pattern with 10-record limit",
          "timestamp": "2025-12-03T15:59:40Z",
          "status": "completed",
          "tags": ["nocodb", "batch-operations", "learning"]
        }
      }
    ]
  }'
```

### Semantic Search

**Purpose**: Find similar content by meaning, not keywords

**Basic Search**:
```bash
# 1. Generate query embedding (using Gemini - FREE)
curl "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "models/text-embedding-004",
    "content": {
      "parts": [{
        "text": "How do I handle batch operations with NocoDB?"
      }]
    }
  }'

# 2. Search Qdrant
curl -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/search" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.234, 0.567, ...],
    "limit": 5,
    "with_payload": true,
    "with_vector": false
  }'
```

**Filtered Search** (with metadata filters):
```bash
curl -X POST "http://qdrant.harbor.fyi/collections/learnings/points/search" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [0.234, 0.567, ...],
    "limit": 10,
    "filter": {
      "must": [
        {
          "key": "category",
          "match": {
            "value": "api-limits"
          }
        },
        {
          "key": "effectiveness",
          "range": {
            "gte": 0.8
          }
        }
      ]
    },
    "with_payload": true
  }'
```

**Scroll (Retrieve All)**:
```bash
curl -X POST "http://qdrant.harbor.fyi/collections/patterns/points/scroll" \
  -H "Content-Type: application/json" \
  -d '{
    "limit": 100,
    "with_payload": true,
    "with_vector": false,
    "filter": {
      "must": [
        {
          "key": "success_rate",
          "range": {
            "gte": 0.9
          }
        }
      ]
    }
  }'
```

### Collection Management

**Create Collection**:
```bash
# STANDARD: All collections use 768 dimensions for Gemini compatibility
curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory" \
  -H "Content-Type: application/json" \
  -d '{
    "vectors": {
      "size": 768,
      "distance": "Cosine"
    },
    "optimizers_config": {
      "default_segment_number": 2
    },
    "replication_factor": 1
  }'
```

**Create Payload Index**:
```bash
# Index session_id for fast filtering
curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/index" \
  -H "Content-Type: application/json" \
  -d '{
    "field_name": "session_id",
    "field_schema": "keyword"
  }'

# Index timestamp for time-based queries
curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/index" \
  -H "Content-Type: application/json" \
  -d '{
    "field_name": "timestamp",
    "field_schema": "datetime"
  }'
```

**Get Collection Info**:
```bash
curl -X GET "http://qdrant.harbor.fyi/collections/agent_memory"
```

**Delete Collection**:
```bash
curl -X DELETE "http://qdrant.harbor.fyi/collections/agent_memory"
```

**Delete Points by Filter**:
```bash
# Delete old memories (>30 days)
curl -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/delete" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "must": [
        {
          "key": "timestamp",
          "range": {
            "lt": "2025-11-03T00:00:00Z"
          }
        }
      ]
    }
  }'
```

**Count Points**:
```bash
curl -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/count" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "must": [
        {
          "key": "status",
          "match": {
            "value": "completed"
          }
        }
      ]
    }
  }'
```

## Integration Points

### 1. Pre-Task Memory Lookup

**Hook**: `.claude/hooks/pre-task-memory-lookup.sh`

**Purpose**: Load relevant context before starting a task

**Flow**:
```bash
#!/bin/bash
# Pre-task hook: Search Qdrant for similar tasks using Gemini embeddings

TASK_DESC="$1"

# Generate embedding for task description (using Gemini - FREE, 768 dims)
EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"models/text-embedding-004\",\"content\":{\"parts\":[{\"text\":\"$TASK_DESC\"}]}}" \
  | jq -r '.embedding.values')

# Search all collections for relevant context
for collection in agent_memory learnings patterns codebase; do
  curl -s -X POST "http://qdrant.harbor.fyi/collections/$collection/points/search" \
    -H "Content-Type: application/json" \
    -d "{
      \"vector\": $EMBEDDING,
      \"limit\": 3,
      \"with_payload\": true
    }" | jq '.result'
done
```

**Usage**: Automatically runs when starting a task via `/task-start`

### 2. Post-Task Indexing

**Hook**: `.claude/hooks/post-task-index.sh`

**Purpose**: Index completed work for future retrieval

**Flow**:
```bash
#!/bin/bash
# Post-task hook: Index task results to Qdrant

TASK_ID="$1"
CONTENT="$2"
LEARNINGS="$3"

# Index task memory
curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/points" \
  -H "Content-Type: application/json" \
  -d "{
    \"points\": [{
      \"id\": \"task_${TASK_ID}\",
      \"vector\": $(generate_embedding "$CONTENT"),
      \"payload\": {
        \"task_id\": $TASK_ID,
        \"content\": \"$CONTENT\",
        \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
        \"status\": \"completed\"
      }
    }]
  }"

# Index learnings if any
if [ -n "$LEARNINGS" ]; then
  curl -X PUT "http://qdrant.harbor.fyi/collections/learnings/points" \
    -H "Content-Type: application/json" \
    -d "{...}"
fi
```

**Usage**: Automatically runs when completing a task via `/task-complete`

### 3. Manual Search Commands

**Slash Command**: `/memory-search`

**Purpose**: Interactive semantic search across all collections

**Usage**:
```bash
# Search for similar tasks
/memory-search "How to implement batch operations?"

# Search learnings only
/memory-search "API rate limit solutions" --collection learnings

# Search with filters
/memory-search "authentication flow" --collection codebase --language javascript

# Time-based search
/memory-search "yesterday's work" --since 2025-12-02
```

**Implementation**: `.claude/commands/memory/memory-search.md`

## Common Operations

### Bulk Index from Supabase

**Scenario**: Initial sync of all Supabase tasks to Qdrant

```bash
#!/bin/bash
# Bulk index script

# 1. Get all completed tasks from Supabase
TASKS=$(curl -s -X GET \
  "https://your-supabase.supabase.co/rest/v1/tasks?Status=eq.Done&select=*" \
  -H "apikey: $SUPABASE_KEY" \
  -H "Authorization: Bearer $SUPABASE_KEY")

# 2. Process each task
echo "$TASKS" | jq -c '.[]' | while read task; do
  TASK_ID=$(echo "$task" | jq -r '.Id')
  CONTENT=$(echo "$task" | jq -r '."task name" + " " + .Description')

  # Generate embedding (using Gemini - FREE, 768 dims)
  EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"models/text-embedding-004\",\"content\":{\"parts\":[{\"text\":\"$CONTENT\"}]}}" \
    | jq '.embedding.values')

  # Upsert to Qdrant
  curl -X PUT "http://qdrant.harbor.fyi/collections/agent_memory/points" \
    -H "Content-Type: application/json" \
    -d "{
      \"points\": [{
        \"id\": \"task_${TASK_ID}\",
        \"vector\": $EMBEDDING,
        \"payload\": $(echo "$task" | jq '{
          task_id: .Id,
          content: (."task name" + " " + .Description),
          status: .Status,
          timestamp: .CreatedAt
        }')
      }]
    }"

  echo "Indexed task $TASK_ID"
done
```

### Find Similar Code Patterns

**Scenario**: Discover similar implementations in codebase

```bash
#!/bin/bash
# Search for similar code

QUERY="batch update pattern with error handling"

# Generate embedding (using Gemini - FREE, 768 dims)
EMBEDDING=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"models/text-embedding-004\",\"content\":{\"parts\":[{\"text\":\"$QUERY\"}]}}" \
  | jq '.embedding.values')

# Search codebase collection
curl -X POST "http://qdrant.harbor.fyi/collections/codebase/points/search" \
  -H "Content-Type: application/json" \
  -d "{
    \"vector\": $EMBEDDING,
    \"limit\": 5,
    \"with_payload\": true,
    \"score_threshold\": 0.7
  }" | jq -r '.result[] | "\(.score): \(.payload.file_path)\n\(.payload.description)\n"'
```

### Archive Old Memories

**Scenario**: Clean up memories older than 30 days

```bash
#!/bin/bash
# Archive old memories

CUTOFF_DATE=$(date -u -d "30 days ago" +%Y-%m-%dT%H:%M:%SZ)

# Query old memories
OLD_MEMORIES=$(curl -s -X POST \
  "http://qdrant.harbor.fyi/collections/agent_memory/points/scroll" \
  -H "Content-Type: application/json" \
  -d "{
    \"filter\": {
      \"must\": [{
        \"key\": \"timestamp\",
        \"range\": {\"lt\": \"$CUTOFF_DATE\"}
      }]
    },
    \"limit\": 1000,
    \"with_payload\": true
  }")

# Move to archive collection (create if not exists)
curl -X PUT "http://qdrant.harbor.fyi/collections/archive/points" \
  -H "Content-Type: application/json" \
  -d "{\"points\": $(echo "$OLD_MEMORIES" | jq '.result.points')}"

# Delete from agent_memory
curl -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/delete" \
  -H "Content-Type: application/json" \
  -d "{
    \"filter\": {
      \"must\": [{
        \"key\": \"timestamp\",
        \"range\": {\"lt\": \"$CUTOFF_DATE\"}
      }]
    }
  }"

echo "Archived memories older than $CUTOFF_DATE"
```

## Performance Tuning

### Indexing Speed
- **Batch inserts**: Upsert up to 100 points per request
- **Parallel processing**: Use multiple workers for large datasets
- **Async operations**: Don't wait for embedding generation

### Search Optimization
- **HNSW parameters**: Adjust `ef_construct` and `m` for speed/accuracy tradeoff
- **Payload indexing**: Index frequently filtered fields (status, tags, dates)
- **Score threshold**: Filter low-similarity results early (>0.7 for strict matches)

### Storage Management
- **Quantization**: Enable scalar quantization for 4x memory reduction
- **Compression**: Use on-disk storage for large collections
- **Archival**: Move old data to separate collections

## Monitoring

### Health Check
```bash
curl http://qdrant.harbor.fyi/healthz
```

### Collection Stats
```bash
curl http://qdrant.harbor.fyi/collections/agent_memory | jq '{
  points_count: .result.points_count,
  segments_count: .result.segments_count,
  vectors_count: .result.vectors_count,
  indexed_vectors_count: .result.indexed_vectors_count
}'
```

### Search Performance
```bash
# Add profiling to search
curl -X POST "http://qdrant.harbor.fyi/collections/agent_memory/points/search" \
  -H "Content-Type: application/json" \
  -d '{
    "vector": [...],
    "limit": 10,
    "with_payload": true,
    "params": {
      "hnsw_ef": 128,
      "exact": false
    }
  }' -w "\nTime: %{time_total}s\n"
```

## Troubleshooting

### Issue: Slow search performance
**Solution**:
- Check collection size: `curl http://qdrant.harbor.fyi/collections/agent_memory | jq .result.points_count`
- Increase HNSW ef parameter: `"params": {"hnsw_ef": 256}`
- Enable payload indexing for filtered fields

### Issue: Out of memory errors
**Solution**:
- Enable quantization: `"quantization_config": {"scalar": {"type": "int8"}}`
- Move to on-disk storage: `"on_disk_payload": true`
- Archive old collections

### Issue: Low similarity scores
**Solution**:
- Verify embedding model consistency (always use same model)
- Check query formulation (add more context)
- Review distance metric (Cosine vs Euclidean)

## Best Practices

1. **Always use Gemini embeddings (768 dims)** - This is our standard, NOT FastEmbed
2. **All collections MUST use 768 dimensions** - For Gemini compatibility
3. **Use direct Gemini API calls** - Prioritize over MCP server for control
4. **Index new learnings immediately** - Don't wait for batch sync
5. **Index metadata for filtering** - status, tags, timestamps are essential
6. **Archive regularly** - Keep active collections lean (<100K points)
7. **Monitor query performance** - Set alerts for >500ms searches
8. **Version control schemas** - Document collection structure changes
9. **Test search queries** - Validate similarity scores before production use

**EMBEDDING MODEL POLICY:**
- PRIMARY: Gemini text-embedding-004 (768 dims) - FREE, high quality
- FALLBACK: FastEmbed via MCP (384 dims) - Optional only
- NEVER mix: Collections must use consistent embedding models

## References

- Qdrant Documentation: https://qdrant.tech/documentation/
- Gemini Embeddings API: https://ai.google.dev/gemini-api/docs/embeddings
- Gemini Free Tier: 1500 requests/minute (sufficient for our workload)
- Cortex Integration: `.claude/docs/CORTEX-API-OPS.md`
- Memory SOP: `.claude/docs/MEMORY-SOP.md`
- Indexing Script: `.claude/skills/memory-sync/scripts/index-to-qdrant.sh`
