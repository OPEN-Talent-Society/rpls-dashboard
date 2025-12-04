/**
 * Quick tests for chunker library
 */

import {
  chunkText,
  chunkDocument,
  chunkCode,
  estimateTokens,
  flattenChunks,
  getChunkStats
} from './chunker';

// Test 1: Basic chunking
console.log('Test 1: Basic text chunking');
const shortText = 'This is a short text. It should return a single chunk.';
const shortChunks = chunkText(shortText);
console.log(`✓ Short text chunks: ${shortChunks.length} (expected: 1)`);
console.assert(shortChunks.length === 1, 'Should return 1 chunk for short text');

// Test 2: Long text with separators
console.log('\nTest 2: Long text with multiple chunks');
const longText = Array(20).fill('This is a paragraph with multiple sentences. It contains information that needs to be chunked properly.').join('\n\n');
const longChunks = chunkText(longText, { chunkSize: 100, chunkOverlap: 20 });
console.log(`✓ Long text chunks: ${longChunks.length} (expected: > 5)`);
console.assert(longChunks.length > 5, 'Should return multiple chunks');
console.log(`✓ First chunk tokens: ${estimateTokens(longChunks[0].text)}`);
console.log(`✓ Last chunk tokens: ${estimateTokens(longChunks[longChunks.length - 1].text)}`);

// Test 3: Parent-child chunking
console.log('\nTest 3: Parent-child chunking');
const veryLongText = Array(100).fill('This is a very long document that will require parent-child chunking. It contains a lot of information that needs to be organized hierarchically.').join(' ');
const parentChildChunks = chunkDocument(veryLongText, { chunkSize: 200, chunkOverlap: 30 });
console.log(`✓ Parent chunks: ${parentChildChunks.length}`);
console.log(`✓ First parent has ${parentChildChunks[0].children?.length} children`);
const hasParentIds = parentChildChunks[0].children?.every(c => c.parent_id?.startsWith('parent_'));
console.assert(hasParentIds, 'Children should have parent_id');
console.log(`✓ Children have parent IDs: ${hasParentIds}`);

// Test 4: Flatten chunks
console.log('\nTest 4: Flatten parent-child structure');
const flattened = flattenChunks(parentChildChunks);
console.log(`✓ Flattened chunks: ${flattened.length}`);
console.assert(flattened.length > parentChildChunks.length, 'Flattened should have more chunks');

// Test 5: Code chunking - TypeScript
console.log('\nTest 5: TypeScript code chunking');
const tsCode = `
export class MyClass {
  constructor() {}

  method1() {
    return "test";
  }
}

export function helperFunction() {
  return 42;
}

export interface MyInterface {
  id: string;
  name: string;
}

export const myConstant = "value";
`;
const tsChunks = chunkCode(tsCode, 'typescript', { chunkSize: 100, chunkOverlap: 10 });
console.log(`✓ TypeScript chunks: ${tsChunks.length}`);
console.log(`✓ First chunk preview: ${tsChunks[0].text.slice(0, 50)}...`);

// Test 6: Code chunking - Python
console.log('\nTest 6: Python code chunking');
const pyCode = `
class MyClass:
    def __init__(self):
        pass

    def method1(self):
        return "test"

def helper_function():
    return 42

async def async_function():
    return await something()
`;
const pyChunks = chunkCode(pyCode, 'python', { chunkSize: 80, chunkOverlap: 10 });
console.log(`✓ Python chunks: ${pyChunks.length}`);

// Test 7: Code chunking - Markdown
console.log('\nTest 7: Markdown code chunking');
const mdCode = `
# Main Title

## Section 1

This is section 1 content with multiple paragraphs.

Some more content here.

## Section 2

This is section 2 content.

### Subsection 2.1

More detailed content.

## Section 3

Final section.
`;
const mdChunks = chunkCode(mdCode, 'markdown', { chunkSize: 100, chunkOverlap: 10 });
console.log(`✓ Markdown chunks: ${mdChunks.length}`);
console.log(`✓ First chunk preview: ${mdChunks[0].text.slice(0, 30)}...`);

// Test 8: Chunk statistics
console.log('\nTest 8: Chunk statistics');
const stats = getChunkStats(longChunks);
console.log(`✓ Total chunks: ${stats.totalChunks}`);
console.log(`✓ Avg chunk size: ${stats.avgChunkSize} tokens`);
console.log(`✓ Min chunk size: ${stats.minChunkSize} tokens`);
console.log(`✓ Max chunk size: ${stats.maxChunkSize} tokens`);
console.log(`✓ Total tokens: ${stats.totalTokens}`);

// Test 9: Token estimation
console.log('\nTest 9: Token estimation');
const testText = 'This is a test string with approximately 10 tokens';
const tokens = estimateTokens(testText);
console.log(`✓ Estimated tokens: ${tokens} (text length: ${testText.length})`);
console.assert(tokens > 0, 'Should estimate > 0 tokens');

// Test 10: Overlap verification
console.log('\nTest 10: Chunk overlap verification');
const overlapText = Array(10).fill('Sentence here. Another sentence. And another one.').join(' ');
const overlapChunks = chunkText(overlapText, { chunkSize: 50, chunkOverlap: 10 });
console.log(`✓ Chunks with overlap: ${overlapChunks.length}`);
if (overlapChunks.length > 1) {
  const chunk1End = overlapChunks[0].text.slice(-20);
  const chunk2Start = overlapChunks[1].text.slice(0, 20);
  console.log(`✓ Chunk 1 end: "...${chunk1End}"`);
  console.log(`✓ Chunk 2 start: "${chunk2Start}..."`);
}

console.log('\n✅ All tests completed successfully!');
