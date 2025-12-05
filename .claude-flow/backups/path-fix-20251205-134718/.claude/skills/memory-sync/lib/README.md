# Chunker Library

A comprehensive text and code chunking library for TypeScript/Node.js with support for recursive character chunking, parent-child document structures, and language-aware code splitting.

## Features

### 1. Recursive Character Chunking
- Configurable chunk size (default: 400 tokens)
- Configurable overlap (default: 50 tokens, 10-15%)
- Smart separator detection for clean breaks
- Respects natural boundaries (paragraphs, sentences, spaces)

### 2. Parent-Child Chunking
- Automatically creates hierarchical structure for long documents (>2000 tokens)
- Parent chunks contain metadata about their children
- Children reference their parent with `parent_id`
- Maintains chunk index and total count for context

### 3. Language-Aware Code Chunking
Specialized chunking strategies for:
- **TypeScript/JavaScript**: Splits on classes, functions, interfaces, types, constants
- **Python**: Splits on classes, functions (including async)
- **Markdown**: Splits on headers (##, ###, ####)

### 4. Utilities
- `estimateTokens()`: Rough token count estimation (1 token ≈ 4 characters)
- `flattenChunks()`: Convert parent-child structure to flat array
- `getChunkStats()`: Analyze chunk statistics (avg/min/max size, total tokens)

## API Reference

### `chunkText(text: string, options?: ChunkOptions): Chunk[]`
Basic recursive character chunking with smart separator detection.

**Options:**
- `chunkSize`: Number of tokens per chunk (default: 400)
- `chunkOverlap`: Number of overlapping tokens (default: 50)
- `separators`: Array of separators to try (default: ["\n\n", "\n", ". ", " "])

**Returns:** Array of `Chunk` objects with `text`, `index`, `start`, `end`, and optional `metadata`

### `chunkDocument(text: string, options?: ChunkOptions): ParentChildChunk[]`
Parent-child chunking for long documents (>2000 tokens).

**Options:** Same as `chunkText()`

**Returns:** Array of `ParentChildChunk` objects with optional `parent_id`, `chunk_index`, `total_chunks`, and `children` array

### `chunkCode(code: string, language: Language, options?: ChunkOptions): Chunk[]`
Language-aware code chunking.

**Languages:** `'typescript'` | `'javascript'` | `'python'` | `'markdown'`

**Options:** Same as `chunkText()` (separators are language-specific)

**Returns:** Array of `Chunk` objects optimized for code structure

### `estimateTokens(text: string): number`
Estimate token count using rough approximation (1 token ≈ 4 characters).

### `flattenChunks(parentChildChunks: ParentChildChunk[]): ParentChildChunk[]`
Flatten parent-child structure into a single-level array of child chunks.

### `getChunkStats(chunks: Chunk[]): ChunkStats`
Calculate statistics about chunks.

**Returns:**
```typescript
{
  totalChunks: number;
  avgChunkSize: number;
  minChunkSize: number;
  maxChunkSize: number;
  totalTokens: number;
}
```

## Usage Examples

### Basic Text Chunking
```typescript
import { chunkText } from './chunker';

const text = "Long document text...";
const chunks = chunkText(text, {
  chunkSize: 400,
  chunkOverlap: 50
});

console.log(`Created ${chunks.length} chunks`);
```

### Parent-Child Document Chunking
```typescript
import { chunkDocument, flattenChunks } from './chunker';

const longDoc = "Very long document text...";
const parentChunks = chunkDocument(longDoc);

// Access parent metadata
console.log(`Parent chunks: ${parentChunks.length}`);
console.log(`First parent has ${parentChunks[0].children?.length} children`);

// Get all child chunks for processing
const childChunks = flattenChunks(parentChunks);
```

### Language-Aware Code Chunking
```typescript
import { chunkCode } from './chunker';

const tsCode = `
export class MyClass {
  method1() { /* ... */ }
}

export function helperFn() { /* ... */ }
`;

const codeChunks = chunkCode(tsCode, 'typescript', {
  chunkSize: 300,
  chunkOverlap: 30
});
```

### Chunk Statistics
```typescript
import { getChunkStats } from './chunker';

const chunks = chunkText(document);
const stats = getChunkStats(chunks);

console.log(`Average chunk size: ${stats.avgChunkSize} tokens`);
console.log(`Total tokens: ${stats.totalTokens}`);
```

## Testing

Run the test suite:
```bash
npx tsx chunker.test.ts
```

All tests verify:
- ✓ Basic text chunking
- ✓ Long text with multiple chunks
- ✓ Parent-child hierarchical structure
- ✓ Chunk flattening
- ✓ TypeScript/JavaScript code chunking
- ✓ Python code chunking
- ✓ Markdown document chunking
- ✓ Chunk statistics
- ✓ Token estimation
- ✓ Overlap verification

## Implementation Details

### Token Estimation
Uses rough approximation of 1 token ≈ 4 characters. This is faster than precise tokenization and sufficient for chunking purposes.

### Smart Separator Detection
When chunking, the library tries separators in order:
1. Double newlines (paragraphs)
2. Single newlines (lines)
3. Periods with space (sentences)
4. Spaces (words)

Only accepts a separator if it's in the latter half of the chunk (>50%) to avoid tiny chunks.

### Overlap Strategy
Chunks overlap by moving the start position forward by `(chunkSize - overlap)`. This ensures context continuity across chunks for better semantic understanding.

### Parent-Child Threshold
Documents over 2000 tokens automatically use parent-child structure. Parents are ~2000 tokens each, containing multiple child chunks at the configured chunk size.

## File Path
`/Users/adamkovacs/Documents/codebuild/.claude/skills/memory-sync/lib/chunker.ts`

## Dependencies
- TypeScript (type definitions)
- Node.js runtime
- tsx (for testing)

## License
Part of the memory-sync skill library.
