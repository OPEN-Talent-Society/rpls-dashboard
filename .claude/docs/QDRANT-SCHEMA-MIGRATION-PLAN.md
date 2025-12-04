# Qdrant Schema Migration Plan

## Overview
Migration from 3 incompatible schemas to unified standard for agent_memory collection.

## Current State (491 points)
- **Type 1 (wiki)**: ~300 points from academy-wiki
- **Type 2 (learning)**: ~150 points from supabase-sync
- **Type 3 (episode)**: ~41 points from agentdb

## Unified Schema Benefits

### 1. Consistent Top-Level Fields
All points now have:
- `type`: Standardized classification (wiki/learning/episode/decision/pattern/finding/tool)
- `source`: Origin system tracking (academy-wiki/supabase-sync/agentdb/cortex-siyuan/nocodb-sync/manual)
- `content`: Primary text for embedding (REQUIRED for semantic search)
- `indexed_at`: ISO 8601 timestamp (e.g., 2025-12-03T22:45:00Z)
- `topic`: Human-readable title/subject
- `category`: Categorical classification for filtering

### 2. Type-Specific Metadata Nesting
Original fields preserved in `metadata.{type}` object:
- **metadata.wiki**: file_path, markdown_headers, last_modified, word_count
- **metadata.learning**: notebook_id, block_id, tags, related_tasks, learning_type
- **metadata.episode**: session_id, task, input, output, critique, reward, success, agentdb_id, created_at, latency_ms, tokens_used

### 3. Versioning & Tracking
- `embedding_model`: Track which model generated vectors
- `updated_at`: Last modification timestamp
- `version`: Schema version (starts at 1, increment on breaking changes)

## Migration Approach

### Phase 1: Read-Only Analysis (CURRENT)
```bash
# Query existing points to understand distribution
curl -X POST "https://qdrant.aienablement.academy/collections/agent_memory/points/scroll" \
  -H "api-key: $QDRANT_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"limit": 100, "with_payload": true, "with_vector": false}'

# Count by type
# wiki: grep '"category": "academy-wiki"'
# learning: grep '"category": "cortex-siyuan"'
# episode: grep '"source": "agentdb"'
```

### Phase 2: Schema Transformation Script
Create `scripts/ml/migrate-qdrant-schema.js`:

```javascript
// Transform Type 1 (wiki) to unified
function transformWiki(oldPayload) {
  return {
    type: "wiki",
    source: oldPayload.source || "academy-wiki",
    content: oldPayload.content,
    indexed_at: oldPayload.indexed_at,
    topic: oldPayload.topic,
    category: "academy-wiki",
    metadata: {
      wiki: {
        file_path: oldPayload.topic, // topic was file path
        markdown_headers: extractHeaders(oldPayload.content),
        last_modified: oldPayload.indexed_at,
        word_count: oldPayload.content.split(/\s+/).length
      }
    },
    embedding_model: "text-embedding-3-small",
    version: 1
  };
}

// Transform Type 2 (learning) to unified
function transformLearning(oldPayload) {
  return {
    type: "learning",
    source: oldPayload.source || "supabase-sync",
    content: oldPayload.content,
    indexed_at: oldPayload.created_at || new Date().toISOString(),
    topic: oldPayload.topic,
    category: "cortex-siyuan",
    metadata: {
      learning: {
        notebook_id: oldPayload.notebook_id,
        block_id: oldPayload.block_id,
        tags: oldPayload.tags || [],
        related_tasks: oldPayload.related_tasks || [],
        learning_type: inferLearningType(oldPayload.content)
      }
    },
    embedding_model: "text-embedding-3-small",
    version: 1
  };
}

// Transform Type 3 (episode) to unified
function transformEpisode(oldPayload) {
  // Construct content from episode fields for embedding
  const content = `Task: ${oldPayload.task}. Input: ${oldPayload.input}. Output: ${oldPayload.output}. Critique: ${oldPayload.critique}`;

  return {
    type: "episode",
    source: "agentdb",
    content: content,
    indexed_at: oldPayload.created_at,
    topic: oldPayload.task,
    category: "development",
    metadata: {
      episode: {
        session_id: oldPayload.session_id,
        task: oldPayload.task,
        input: oldPayload.input,
        output: oldPayload.output,
        critique: oldPayload.critique,
        reward: oldPayload.reward,
        success: oldPayload.success,
        agentdb_id: oldPayload.agentdb_id,
        created_at: oldPayload.created_at,
        latency_ms: oldPayload.latency_ms,
        tokens_used: oldPayload.tokens_used
      }
    },
    embedding_model: "text-embedding-3-small",
    version: 1
  };
}
```

### Phase 3: Batch Migration
Use Qdrant batch upsert to update points in-place:

```javascript
// Scroll through all points
const points = await scrollAllPoints('agent_memory');

// Transform in batches of 100
const batchSize = 100;
for (let i = 0; i < points.length; i += batchSize) {
  const batch = points.slice(i, i + batchSize);

  const transformedPoints = batch.map(point => {
    let newPayload;

    // Detect type and transform
    if (point.payload.category === 'academy-wiki') {
      newPayload = transformWiki(point.payload);
    } else if (point.payload.category === 'cortex-siyuan') {
      newPayload = transformLearning(point.payload);
    } else if (point.payload.source === 'agentdb') {
      newPayload = transformEpisode(point.payload);
    } else {
      console.warn(`Unknown type for point ${point.id}`);
      return null;
    }

    return {
      id: point.id,
      vector: point.vector, // Keep existing vector
      payload: newPayload
    };
  }).filter(p => p !== null);

  // Upsert batch
  await qdrantClient.upsert('agent_memory', {
    wait: true,
    points: transformedPoints
  });

  console.log(`Migrated batch ${i / batchSize + 1} (${transformedPoints.length} points)`);
}
```

### Phase 4: Validation
```javascript
// Verify all points have required fields
const validation = await qdrantClient.scroll('agent_memory', {
  limit: 1000,
  with_payload: true,
  filter: {
    must_not: [
      { has_id: [] }
    ]
  }
});

// Check schema compliance
validation.points.forEach(point => {
  const p = point.payload;

  // Required fields
  assert(p.type, 'Missing type');
  assert(p.source, 'Missing source');
  assert(p.content, 'Missing content');
  assert(p.indexed_at, 'Missing indexed_at');
  assert(p.version === 1, 'Invalid version');

  // Type-specific metadata
  if (p.type === 'wiki') {
    assert(p.metadata.wiki, 'Missing wiki metadata');
  } else if (p.type === 'learning') {
    assert(p.metadata.learning, 'Missing learning metadata');
  } else if (p.type === 'episode') {
    assert(p.metadata.episode, 'Missing episode metadata');
  }
});

console.log('Schema validation passed!');
```

### Phase 5: Update Indexing Scripts
Update all sync scripts to use unified schema:

**academy-wiki-to-qdrant.js**:
```javascript
const payload = {
  type: "wiki",
  source: "academy-wiki",
  content: fileContent,
  indexed_at: new Date().toISOString(),
  topic: filePath,
  category: "academy-wiki",
  metadata: {
    wiki: {
      file_path: filePath,
      markdown_headers: extractHeaders(fileContent),
      last_modified: fs.statSync(filePath).mtime.toISOString(),
      word_count: fileContent.split(/\s+/).length
    }
  },
  embedding_model: "text-embedding-3-small",
  version: 1
};
```

**supabase-to-qdrant.js**:
```javascript
const payload = {
  type: "learning",
  source: "supabase-sync",
  content: row.content,
  indexed_at: new Date().toISOString(),
  topic: row.title,
  category: "cortex-siyuan",
  metadata: {
    learning: {
      notebook_id: row.notebook_id,
      block_id: row.block_id,
      tags: row.tags,
      related_tasks: row.related_tasks,
      learning_type: row.learning_type
    }
  },
  embedding_model: "text-embedding-3-small",
  version: 1
};
```

**agentdb-to-qdrant.js**:
```javascript
const payload = {
  type: "episode",
  source: "agentdb",
  content: `Task: ${row.task}. Input: ${row.input}. Output: ${row.output}. Critique: ${row.critique}`,
  indexed_at: row.created_at,
  topic: row.task,
  category: "development",
  metadata: {
    episode: {
      session_id: row.session_id,
      task: row.task,
      input: row.input,
      output: row.output,
      critique: row.critique,
      reward: row.reward,
      success: row.success,
      agentdb_id: row.id,
      created_at: row.created_at,
      latency_ms: row.latency_ms,
      tokens_used: row.tokens_used
    }
  },
  embedding_model: "text-embedding-3-small",
  version: 1
};
```

## Benefits After Migration

### 1. Unified Filtering
```javascript
// Filter by type
filter: { must: [{ key: "type", match: { value: "learning" } }] }

// Filter by source
filter: { must: [{ key: "source", match: { value: "agentdb" } }] }

// Filter by date range
filter: {
  must: [{
    key: "indexed_at",
    range: {
      gte: "2025-12-01T00:00:00Z",
      lte: "2025-12-03T23:59:59Z"
    }
  }]
}

// Filter successful episodes only
filter: {
  must: [
    { key: "type", match: { value: "episode" } },
    { key: "metadata.episode.success", match: { value: true } }
  ]
}
```

### 2. Consistent Search
All searches now use `content` field for semantic matching:
```javascript
// Search all memory types
POST /collections/agent_memory/points/search
{
  "vector": embedding,
  "limit": 10,
  "with_payload": true
}

// Results include type, source, topic for easy classification
```

### 3. Version Management
Future schema changes increment `version` field:
- v1: Initial unified schema (2025-12-03)
- v2: Add user_id for multi-tenant support
- v3: Add vector compression flags

Migration scripts detect version and upgrade incrementally.

## Timeline
- **Phase 1** (Analysis): 1 hour - DONE
- **Phase 2** (Script Development): 2 hours
- **Phase 3** (Migration): 30 minutes (491 points × 100ms = ~50s + safety margin)
- **Phase 4** (Validation): 30 minutes
- **Phase 5** (Update Scripts): 1 hour

**Total**: ~5 hours of development + 1 hour of execution

## Rollback Plan
Before migration:
1. Export all points to JSON: `qdrant-backup.py export`
2. Store backup in NAS: `/data/backups/qdrant/pre-migration-2025-12-03.json`
3. If migration fails, restore from backup: `qdrant-backup.py restore`

## Success Criteria
- ✅ All 491 points migrated successfully
- ✅ No vectors regenerated (preserve existing embeddings)
- ✅ All original data preserved in metadata
- ✅ Schema validation passes 100%
- ✅ Search performance unchanged or improved
- ✅ All sync scripts updated and tested

## Next Steps
1. **Review schema** with stakeholders
2. **Develop migration script** (Phase 2)
3. **Test on subset** (10 points from each type)
4. **Backup production** data
5. **Execute migration** (Phase 3)
6. **Validate results** (Phase 4)
7. **Update documentation** and sync scripts (Phase 5)
