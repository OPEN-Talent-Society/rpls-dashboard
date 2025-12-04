/**
 * Practical usage examples for the chunker library
 */

import {
  chunkText,
  chunkDocument,
  chunkCode,
  estimateTokens,
  flattenChunks,
  getChunkStats,
  type Chunk,
  type ParentChildChunk
} from './chunker';

// Example 1: Simple text chunking for embedding
console.log('=== Example 1: Text Chunking for Embeddings ===');
const article = `
Artificial Intelligence has transformed how we approach problem-solving in software development.
Machine learning models can now understand context, generate code, and even debug complex issues.

The emergence of large language models has particularly revolutionized the field. These models
can process natural language, understand intent, and produce human-like responses. This has
opened up new possibilities for human-computer interaction.

However, challenges remain. Token limits, context windows, and computational costs are real
constraints that developers must work with. Effective chunking strategies help maximize the
utility of these powerful models.
`.trim();

const chunks = chunkText(article, {
  chunkSize: 100,  // ~400 characters
  chunkOverlap: 20  // ~80 characters overlap
});

console.log(`Created ${chunks.length} chunks from article`);
chunks.forEach((chunk, i) => {
  console.log(`\nChunk ${i + 1} (${estimateTokens(chunk.text)} tokens):`);
  console.log(chunk.text.slice(0, 80) + '...');
});

// Example 2: Long document with parent-child structure
console.log('\n\n=== Example 2: Parent-Child Structure for Large Documents ===');
const longReport = Array(50).fill(`
This is a section of a very long research report. It contains detailed analysis,
data points, and comprehensive findings that span multiple pages. The document
needs to be chunked intelligently to maintain hierarchical relationships while
ensuring each chunk is semantically coherent and useful for retrieval.
`).join('\n\n');

const parentChildChunks = chunkDocument(longReport, {
  chunkSize: 200,
  chunkOverlap: 30
});

console.log(`Parent chunks: ${parentChildChunks.length}`);
parentChildChunks.forEach((parent, i) => {
  console.log(`\nParent ${i + 1}:`);
  console.log(`  - Tokens: ${parent.metadata?.tokens}`);
  console.log(`  - Children: ${parent.children?.length}`);
  console.log(`  - Child tokens: ${parent.children?.map(c => c.metadata?.tokens).join(', ')}`);
});

// Get all child chunks for embedding
const allChildren = flattenChunks(parentChildChunks);
console.log(`\nTotal child chunks for embedding: ${allChildren.length}`);

// Example 3: Code chunking for documentation
console.log('\n\n=== Example 3: TypeScript Code Chunking ===');
const typescriptCode = `
import { Request, Response, NextFunction } from 'express';

export interface User {
  id: string;
  email: string;
  name: string;
  createdAt: Date;
}

export class UserService {
  constructor(private db: Database) {}

  async findById(id: string): Promise<User | null> {
    return this.db.users.findOne({ id });
  }

  async create(data: Omit<User, 'id' | 'createdAt'>): Promise<User> {
    const user: User = {
      ...data,
      id: generateId(),
      createdAt: new Date()
    };
    await this.db.users.insert(user);
    return user;
  }

  async update(id: string, data: Partial<User>): Promise<User | null> {
    return this.db.users.updateOne({ id }, data);
  }

  async delete(id: string): Promise<boolean> {
    const result = await this.db.users.deleteOne({ id });
    return result.deletedCount > 0;
  }
}

export function authMiddleware(req: Request, res: Response, next: NextFunction) {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  // Verify token...
  next();
}

export const API_VERSION = 'v1';
export const MAX_REQUESTS_PER_HOUR = 1000;
`;

const codeChunks = chunkCode(typescriptCode, 'typescript', {
  chunkSize: 150,
  chunkOverlap: 20
});

console.log(`Code chunks: ${codeChunks.length}`);
codeChunks.forEach((chunk, i) => {
  const preview = chunk.text.trim().split('\n')[0];
  console.log(`\nChunk ${i + 1}: ${preview}`);
  console.log(`  Tokens: ${estimateTokens(chunk.text)}`);
});

// Example 4: Python code chunking
console.log('\n\n=== Example 4: Python Code Chunking ===');
const pythonCode = `
import asyncio
from typing import Optional, List

class DataProcessor:
    def __init__(self, config: dict):
        self.config = config
        self.cache = {}

    def process(self, data: List[dict]) -> List[dict]:
        """Process a list of data items."""
        return [self._transform(item) for item in data]

    def _transform(self, item: dict) -> dict:
        """Transform a single data item."""
        return {k: v.upper() if isinstance(v, str) else v for k, v in item.items()}

async def fetch_data(url: str) -> Optional[dict]:
    """Fetch data from a URL asynchronously."""
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            if response.status == 200:
                return await response.json()
    return None

def calculate_metrics(data: List[float]) -> dict:
    """Calculate statistical metrics."""
    return {
        'mean': sum(data) / len(data),
        'min': min(data),
        'max': max(data)
    }
`;

const pyChunks = chunkCode(pythonCode, 'python', {
  chunkSize: 120,
  chunkOverlap: 15
});

console.log(`Python chunks: ${pyChunks.length}`);
pyChunks.forEach((chunk, i) => {
  const preview = chunk.text.trim().split('\n')[0];
  console.log(`\nChunk ${i + 1}: ${preview}`);
  console.log(`  Tokens: ${estimateTokens(chunk.text)}`);
});

// Example 5: Markdown documentation chunking
console.log('\n\n=== Example 5: Markdown Documentation Chunking ===');
const markdown = `
# User Authentication System

## Overview

This system handles user authentication using JWT tokens and secure password hashing.

## Authentication Flow

### Registration

When a user registers, the following steps occur:
1. Validate email format
2. Check if email already exists
3. Hash password using bcrypt
4. Generate verification token
5. Send verification email

### Login

The login process includes:
1. Verify credentials
2. Generate JWT token
3. Set secure cookie
4. Return user data

### Password Reset

Users can reset their password by:
1. Requesting a reset link
2. Receiving email with token
3. Setting new password

## Security Considerations

### Token Expiry

Tokens expire after 24 hours for security.

### Rate Limiting

Login attempts are limited to 5 per hour per IP.
`;

const mdChunks = chunkCode(markdown, 'markdown', {
  chunkSize: 100,
  chunkOverlap: 15
});

console.log(`Markdown chunks: ${mdChunks.length}`);
mdChunks.forEach((chunk, i) => {
  const preview = chunk.text.trim().split('\n')[0];
  console.log(`\nChunk ${i + 1}: ${preview}`);
  console.log(`  Tokens: ${estimateTokens(chunk.text)}`);
});

// Example 6: Chunk statistics and analysis
console.log('\n\n=== Example 6: Chunk Statistics ===');
const allChunks = [
  ...chunks,
  ...codeChunks,
  ...pyChunks,
  ...mdChunks
];

const stats = getChunkStats(allChunks);
console.log('Overall Statistics:');
console.log(`  Total chunks: ${stats.totalChunks}`);
console.log(`  Average size: ${stats.avgChunkSize} tokens`);
console.log(`  Min size: ${stats.minChunkSize} tokens`);
console.log(`  Max size: ${stats.maxChunkSize} tokens`);
console.log(`  Total tokens: ${stats.totalTokens}`);
console.log(`  Estimated cost (@ $0.0001/token): $${(stats.totalTokens * 0.0001).toFixed(4)}`);

// Example 7: Real-world scenario - preparing for embedding
console.log('\n\n=== Example 7: Preparing Chunks for Embedding Pipeline ===');
interface EmbeddingChunk {
  id: string;
  text: string;
  tokens: number;
  metadata: {
    source: string;
    type: 'text' | 'code';
    language?: string;
    parent_id?: string;
    chunk_index?: number;
  };
}

function prepareForEmbedding(chunks: Chunk[], source: string, type: 'text' | 'code', language?: string): EmbeddingChunk[] {
  return chunks.map((chunk, i) => ({
    id: `${source}_${i}`,
    text: chunk.text,
    tokens: estimateTokens(chunk.text),
    metadata: {
      source,
      type,
      language,
      chunk_index: chunk.index
    }
  }));
}

const textForEmbedding = prepareForEmbedding(chunks, 'article.txt', 'text');
const codeForEmbedding = prepareForEmbedding(codeChunks, 'UserService.ts', 'code', 'typescript');

console.log(`Prepared ${textForEmbedding.length} text chunks for embedding`);
console.log(`Prepared ${codeForEmbedding.length} code chunks for embedding`);
console.log('\nSample embedding chunk:');
console.log(JSON.stringify(textForEmbedding[0], null, 2));
