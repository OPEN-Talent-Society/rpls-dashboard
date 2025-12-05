---
name: "RuVector Development"
description: "Distributed vector database for semantic search, agent memory, and codebase understanding. Use when indexing project files, searching specifications semantically, building knowledge graphs, or enhancing agent context retrieval during development."
version: "1.0.0"
category: "development-tools"
tags: ["vector-db", "semantic-search", "embeddings", "knowledge-graph", "agent-memory"]
---

# RuVector Development Skill

## What This Skill Does

RuVector is a distributed vector database with self-learning capabilities, designed to enhance Claude Code development workflows through:

- **Semantic Search**: Find relevant code, specs, and docs by meaning, not just keywords
- **Agent Memory**: Persistent vector-based memory for agentic workflows
- **Knowledge Graphs**: Cypher query support for relationship traversal
- **Codebase Understanding**: Index and query your entire project semantically
- **Self-Learning**: GNN layers that improve retrieval quality over time

## Prerequisites

- Node.js 18+
- pnpm (required package manager)
- RuVector CLI: `pnpm add -g ruvector` or use via `pnpm dlx ruvector`

## Quick Start

```bash
# Initialize RuVector in your project
pnpm dlx ruvector init

# Index your codebase
pnpm dlx ruvector index --dir ./src --recursive

# Semantic search
pnpm dlx ruvector search "authentication flow with JWT tokens"

# Start the RuVector server
pnpm dlx ruvector serve --port 8787
```

---

## Complete Guide

### Installation & Setup

#### Local Development Setup

```bash
# Install RuVector globally (recommended for development)
pnpm add -g ruvector

# Or use directly without global install
pnpm dlx ruvector --version

# Initialize in project root
cd /path/to/your/project
pnpm dlx ruvector init

# This creates:
# - .ruvector/config.json - Configuration
# - .ruvector/index/ - Vector index storage
# - .ruvector/graphs/ - Knowledge graph data
```

#### Configuration Options

```json
{
  "ruvector": {
    "indexPath": ".ruvector/index",
    "graphPath": ".ruvector/graphs",
    "embedding": {
      "model": "text-embedding-3-small",
      "dimensions": 1536
    },
    "index": {
      "type": "hnsw",
      "m": 16,
      "efConstruction": 200,
      "efSearch": 100
    },
    "learning": {
      "enabled": true,
      "gnnLayers": 3,
      "adaptiveThreshold": 0.7
    }
  }
}
```

### Indexing Your Codebase

#### Index Project Files

```bash
# Index specific directory
pnpm dlx ruvector index --dir ./src

# Index with file patterns
pnpm dlx ruvector index --dir . --include "**/*.ts,**/*.md" --exclude "node_modules/**"

# Index specifications
pnpm dlx ruvector index --dir ./specs --recursive --tag "specifications"

# Index with custom metadata
pnpm dlx ruvector index --dir ./docs --metadata '{"type": "documentation", "priority": "high"}'

# Watch mode for live updates
pnpm dlx ruvector index --dir ./src --watch
```

#### Index File Types Supported

| File Type | Chunking Strategy | Embedding Quality |
|-----------|------------------|-------------------|
| TypeScript/JavaScript | AST-aware | Excellent |
| Markdown | Section-based | Excellent |
| JSON/YAML | Schema-aware | Good |
| Python | AST-aware | Excellent |
| Plain Text | Paragraph-based | Good |

### Semantic Search

#### Basic Search

```bash
# Simple semantic search
pnpm dlx ruvector search "user authentication implementation"

# Search with filters
pnpm dlx ruvector search "database schema" --filter "tag:specifications"

# Search with similarity threshold
pnpm dlx ruvector search "error handling patterns" --threshold 0.8

# Get more results
pnpm dlx ruvector search "API endpoints" --limit 20

# JSON output for programmatic use
pnpm dlx ruvector search "payment processing" --json
```

#### Advanced Search Options

```bash
# Hybrid search (semantic + keyword)
pnpm dlx ruvector search "JWT token" --mode hybrid --keyword-weight 0.3

# Search with date filtering
pnpm dlx ruvector search "recent changes" --after "2025-01-01"

# Search specific collections
pnpm dlx ruvector search "user model" --collection specs

# Re-ranking with cross-encoder
pnpm dlx ruvector search "complex query" --rerank --rerank-model cross-encoder
```

#### Search Result Format

```json
{
  "query": "user authentication",
  "results": [
    {
      "id": "specs/auth.md#section-2",
      "content": "JWT-based authentication with refresh tokens...",
      "similarity": 0.94,
      "metadata": {
        "file": "specs/auth.md",
        "section": "Authentication Flow",
        "tags": ["auth", "security"]
      }
    }
  ],
  "searchTime": "45ms",
  "totalResults": 12
}
```

### Knowledge Graph Queries

#### Cypher Query Support

```bash
# Find all files related to a concept
pnpm dlx ruvector query "MATCH (f:File)-[:REFERENCES]->(c:Concept {name: 'authentication'}) RETURN f"

# Find dependency chains
pnpm dlx ruvector query "MATCH path = (a:Module)-[:IMPORTS*1..3]->(b:Module) WHERE a.name = 'app.ts' RETURN path"

# Find similar code patterns
pnpm dlx ruvector query "MATCH (p:Pattern {type: 'error-handling'})-[:SIMILAR_TO]->(q:Pattern) RETURN q LIMIT 5"

# Build relationship graph
pnpm dlx ruvector graph build --dir ./src --output graph.json
```

#### Graph Visualization

```bash
# Export graph for visualization
pnpm dlx ruvector graph export --format dot --output codebase.dot

# Start interactive graph explorer
pnpm dlx ruvector graph explore --port 8788
```

### Agent Memory Integration

#### Store Agent Context

```bash
# Store memory with namespace
pnpm dlx ruvector memory store \
  --namespace "agent/architect" \
  --key "decision-2025-01-15" \
  --value "Chose PostgreSQL for primary database due to JSONB support" \
  --metadata '{"priority": "high", "category": "architecture"}'

# Store conversation context
pnpm dlx ruvector memory store \
  --namespace "session/abc123" \
  --key "context" \
  --value "User is implementing payment processing with Stripe" \
  --ttl 3600
```

#### Retrieve Relevant Memory

```bash
# Semantic memory retrieval
pnpm dlx ruvector memory search \
  --namespace "agent/*" \
  --query "database selection decisions" \
  --limit 5

# Get specific memory
pnpm dlx ruvector memory get \
  --namespace "agent/architect" \
  --key "decision-2025-01-15"

# List all memories in namespace
pnpm dlx ruvector memory list \
  --namespace "agent/architect" \
  --pattern "decision-*"
```

#### Memory Patterns for Agentic-Flow

```bash
# Integration with agentic-flow swarms
/opt/homebrew/bin/agentic-flow swarm init --topology mesh --memory-backend ruvector

# Agent spawning with vector memory
/opt/homebrew/bin/agentic-flow agent spawn --type researcher \
  --memory-namespace "swarm/research" \
  --memory-backend ruvector

# Cross-agent memory sharing
pnpm dlx ruvector memory sync \
  --from "agent/coder" \
  --to "agent/reviewer" \
  --filter "decisions/*"
```

### Self-Learning Features

#### Enable Learning Mode

```bash
# Enable self-learning GNN
pnpm dlx ruvector config set learning.enabled true

# Train on user feedback
pnpm dlx ruvector learn feedback \
  --query "authentication" \
  --relevant "specs/auth.md#section-2" \
  --irrelevant "specs/database.md#tables"

# Batch training from logs
pnpm dlx ruvector learn batch --feedback-file ./feedback.json

# Check learning metrics
pnpm dlx ruvector learn status
```

#### Learning Metrics

```
📊 Learning Status
├── GNN Layers: 3
├── Training Iterations: 1,247
├── Accuracy Improvement: +18.4%
├── Last Training: 2 hours ago
└── Feedback Samples: 523
```

### Development Workflows

#### Indexing Specs for Semantic Search

```bash
# Index all specification documents
pnpm dlx ruvector index \
  --dir ./specs \
  --recursive \
  --include "**/*.md" \
  --collection specs \
  --metadata '{"type": "specification", "project": "campfire"}'

# Search specs semantically
pnpm dlx ruvector search "user role permissions" --collection specs

# Find related specs
pnpm dlx ruvector query \
  "MATCH (s:Spec)-[:REFERENCES]->(t:Topic {name: 'authentication'}) RETURN s.file, s.section"
```

#### Building Agent Context

```bash
# Pre-load context for agent tasks
pnpm dlx ruvector search "payment processing implementation" \
  --limit 10 \
  --json | /opt/homebrew/bin/agentic-flow memory store \
  --namespace "agent/context" \
  --key "task-payment" \
  --stdin

# Build comprehensive context
pnpm dlx ruvector context build \
  --query "implement user authentication" \
  --sources specs,src,docs \
  --depth 3 \
  --output context.json
```

#### Codebase Understanding

```bash
# Generate codebase overview
pnpm dlx ruvector analyze \
  --dir ./src \
  --output analysis.json \
  --include-graph \
  --include-patterns

# Find code patterns
pnpm dlx ruvector patterns find \
  --dir ./src \
  --type "error-handling,validation,api-calls"

# Detect code smells
pnpm dlx ruvector analyze \
  --dir ./src \
  --check code-smells \
  --threshold 0.7
```

### API Reference

#### HTTP API (when server is running)

```bash
# Start server
pnpm dlx ruvector serve --port 8787

# Search endpoint
curl -X POST http://localhost:8787/api/search \
  -H "Content-Type: application/json" \
  -d '{"query": "user authentication", "limit": 10}'

# Index endpoint
curl -X POST http://localhost:8787/api/index \
  -H "Content-Type: application/json" \
  -d '{"content": "...", "metadata": {...}}'

# Memory endpoint
curl -X POST http://localhost:8787/api/memory \
  -H "Content-Type: application/json" \
  -d '{"action": "store", "namespace": "agent/test", "key": "k1", "value": "v1"}'
```

#### Node.js SDK

```javascript
import { RuVector } from 'ruvector';

// Initialize client
const rv = new RuVector({
  indexPath: '.ruvector/index',
  embedding: { model: 'text-embedding-3-small' }
});

// Index content
await rv.index({
  content: 'User authentication with JWT...',
  metadata: { file: 'auth.md', section: 'overview' }
});

// Search
const results = await rv.search('authentication flow', { limit: 5 });

// Graph query
const related = await rv.query(
  "MATCH (f:File)-[:REFERENCES]->(c:Concept {name: 'auth'}) RETURN f"
);

// Memory operations
await rv.memory.store('agent/context', 'task-1', { data: '...' });
const context = await rv.memory.search('agent/*', 'recent decisions');
```

### Integration with Project-Campfire

#### Recommended Setup

```bash
# 1. Initialize RuVector in project root
cd /path/to/project-campfire
pnpm dlx ruvector init

# 2. Index specifications
pnpm dlx ruvector index --dir ./specs --recursive --collection specs

# 3. Index source code
pnpm dlx ruvector index --dir ./apps/web/src --recursive --collection source

# 4. Index documentation
pnpm dlx ruvector index --dir ./docs --recursive --collection docs

# 5. Build knowledge graph
pnpm dlx ruvector graph build --collections specs,source,docs

# 6. Add to .gitignore
echo ".ruvector/" >> .gitignore
```

#### Claude Code Hook Integration

Add to `/Users/adamkovacs/Documents/codebuild/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Read|Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "pnpm dlx ruvector search --query \"$(cat | jq -r '.tool_input.file_path // \"\"')\" --limit 3 --json 2>/dev/null || true"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "cat | jq -r '.tool_input.file_path // \"\"' | xargs -I {} pnpm dlx ruvector index --file \"{}\" 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

### Performance Tuning

#### Index Optimization

```bash
# Optimize HNSW index
pnpm dlx ruvector optimize --type index

# Compress embeddings
pnpm dlx ruvector optimize --type embeddings --compression pq

# Rebuild index
pnpm dlx ruvector rebuild --collection specs
```

#### Query Performance

```bash
# Check query latency
pnpm dlx ruvector benchmark --queries ./test-queries.json

# Tune HNSW parameters
pnpm dlx ruvector config set index.efSearch 150

# Enable caching
pnpm dlx ruvector config set cache.enabled true
pnpm dlx ruvector config set cache.ttl 3600
```

### Troubleshooting

#### Common Issues

**Index not found:**
```bash
pnpm dlx ruvector init  # Reinitialize
pnpm dlx ruvector index --dir . --recursive  # Rebuild
```

**Slow searches:**
```bash
pnpm dlx ruvector optimize --type index
pnpm dlx ruvector config set index.efSearch 100  # Lower for speed
```

**Memory issues:**
```bash
pnpm dlx ruvector config set embedding.batchSize 50  # Reduce batch size
pnpm dlx ruvector config set index.memoryLimit "2G"  # Set limit
```

### Exit Codes

- `0`: Success
- `1`: General error
- `2`: Index not found
- `3`: Query syntax error
- `4`: Connection failed

### Related Skills

- `agentic-flow` - Multi-agent orchestration with RuVector memory backend
- `agentdb-vector-search` - AgentDB integration for vector operations
- `reasoningbank-intelligence` - Reasoning patterns with semantic retrieval

### Best Practices

1. **Index Strategically**: Focus on specs and high-value docs first
2. **Use Collections**: Separate specs, source, and docs for targeted search
3. **Enable Learning**: Let GNN improve retrieval over time
4. **Namespace Memory**: Use clear namespaces for agent memory
5. **Periodic Optimization**: Run `ruvector optimize` weekly
6. **Monitor Performance**: Check `ruvector benchmark` regularly
7. **Backup Indexes**: Include `.ruvector/` in backups

### Future P3 Platform Integration

When RuVector becomes a platform feature:
- User-facing semantic search on course content
- AI-powered recommendation engine
- Knowledge graph visualization for learning paths
- Personalized content retrieval based on user progress

---

**Package**: [ruvector](https://github.com/ruvnet/ruvector) v0.1.24+
**Requires**: Node.js 18+, pnpm
