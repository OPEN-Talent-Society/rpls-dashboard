/**
 * Text Chunking Library
 * Supports recursive character chunking, parent-child chunking, and language-aware code chunking
 */

export interface ChunkOptions {
  chunkSize?: number;      // in tokens (default: 400)
  chunkOverlap?: number;   // in tokens (default: 50)
  separators?: string[];   // default: ["\n\n", "\n", ". ", " "]
}

export interface Chunk {
  text: string;
  index: number;
  start: number;
  end: number;
  metadata?: Record<string, any>;
}

export interface ParentChildChunk extends Chunk {
  parent_id?: string;
  chunk_index?: number;
  total_chunks?: number;
  children?: ParentChildChunk[];
}

/**
 * Estimate token count (rough approximation: 1 token ≈ 4 characters)
 */
export function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

/**
 * Convert tokens to approximate character count
 */
function tokensToChars(tokens: number): number {
  return tokens * 4;
}

/**
 * Basic recursive character chunking
 */
export function chunkText(text: string, options: ChunkOptions = {}): Chunk[] {
  const {
    chunkSize = 400,
    chunkOverlap = 50,
    separators = ["\n\n", "\n", ". ", " "]
  } = options;

  const chunkSizeChars = tokensToChars(chunkSize);
  const overlapChars = tokensToChars(chunkOverlap);

  // If text is small enough, return as single chunk
  if (text.length <= chunkSizeChars) {
    return [{
      text,
      index: 0,
      start: 0,
      end: text.length
    }];
  }

  const chunks: Chunk[] = [];
  let startIndex = 0;
  let chunkIndex = 0;

  while (startIndex < text.length) {
    const endIndex = Math.min(startIndex + chunkSizeChars, text.length);
    let chunkText = text.slice(startIndex, endIndex);

    // Try to break at a separator for better chunks
    if (endIndex < text.length) {
      let bestSplit = chunkText.length;

      for (const separator of separators) {
        const lastIndex = chunkText.lastIndexOf(separator);
        if (lastIndex > chunkText.length * 0.5) { // Only if split is in latter half
          bestSplit = lastIndex + separator.length;
          break;
        }
      }

      chunkText = chunkText.slice(0, bestSplit);
    }

    chunks.push({
      text: chunkText.trim(),
      index: chunkIndex,
      start: startIndex,
      end: startIndex + chunkText.length
    });

    // Move forward with overlap
    startIndex += chunkText.length - overlapChars;

    // Ensure we make progress
    if (startIndex <= chunks[chunkIndex].start) {
      startIndex = chunks[chunkIndex].end;
    }

    chunkIndex++;
  }

  return chunks;
}

/**
 * Parent-child chunking for long documents
 * Creates parent chunks for documents > 2000 tokens
 */
export function chunkDocument(text: string, options: ChunkOptions = {}): ParentChildChunk[] {
  const {
    chunkSize = 400,
    chunkOverlap = 50,
    separators = ["\n\n", "\n", ". ", " "]
  } = options;

  const estimatedTokens = estimateTokens(text);
  const PARENT_THRESHOLD = 2000;

  // If document is small, just return regular chunks
  if (estimatedTokens <= PARENT_THRESHOLD) {
    return chunkText(text, options).map(chunk => ({
      ...chunk,
      metadata: { tokens: estimateTokens(chunk.text) }
    }));
  }

  // Create parent-child structure
  const parentChunkSize = tokensToChars(PARENT_THRESHOLD);
  const parentChunks: ParentChildChunk[] = [];
  let parentIndex = 0;

  for (let i = 0; i < text.length; i += parentChunkSize) {
    const parentEnd = Math.min(i + parentChunkSize, text.length);
    const parentText = text.slice(i, parentEnd);
    const parentId = `parent_${parentIndex}`;

    // Create child chunks from parent text
    const childChunks = chunkText(parentText, { chunkSize, chunkOverlap, separators });

    const parentChunk: ParentChildChunk = {
      text: parentText,
      index: parentIndex,
      start: i,
      end: parentEnd,
      metadata: {
        type: 'parent',
        tokens: estimateTokens(parentText),
        child_count: childChunks.length
      },
      children: childChunks.map((child, childIndex) => ({
        ...child,
        parent_id: parentId,
        chunk_index: childIndex,
        total_chunks: childChunks.length,
        start: i + child.start,
        end: i + child.end,
        metadata: {
          type: 'child',
          tokens: estimateTokens(child.text)
        }
      }))
    };

    parentChunks.push(parentChunk);
    parentIndex++;
  }

  return parentChunks;
}

/**
 * Language-aware code chunking
 */
export function chunkCode(
  code: string,
  language: 'typescript' | 'javascript' | 'python' | 'markdown',
  options: ChunkOptions = {}
): Chunk[] {
  const {
    chunkSize = 400,
    chunkOverlap = 50
  } = options;

  let separators: string[];

  switch (language) {
    case 'typescript':
    case 'javascript':
      separators = [
        '\nclass ',
        '\nexport class ',
        '\nfunction ',
        '\nexport function ',
        '\nconst ',
        '\nexport const ',
        '\ninterface ',
        '\nexport interface ',
        '\ntype ',
        '\nexport type ',
        '\n\n',
        '\n',
        '; ',
        ' '
      ];
      break;

    case 'python':
      separators = [
        '\nclass ',
        '\ndef ',
        '\nasync def ',
        '\n\n',
        '\n',
        '. ',
        ' '
      ];
      break;

    case 'markdown':
      separators = [
        '\n## ',
        '\n### ',
        '\n#### ',
        '\n\n',
        '\n',
        '. ',
        ' '
      ];
      break;

    default:
      separators = ['\n\n', '\n', '. ', ' '];
  }

  return chunkText(code, { chunkSize, chunkOverlap, separators });
}

/**
 * Utility: Flatten parent-child chunks into a flat array
 */
export function flattenChunks(parentChildChunks: ParentChildChunk[]): ParentChildChunk[] {
  const flattened: ParentChildChunk[] = [];

  for (const parent of parentChildChunks) {
    if (parent.children && parent.children.length > 0) {
      flattened.push(...parent.children);
    } else {
      flattened.push(parent);
    }
  }

  return flattened;
}

/**
 * Utility: Get chunk statistics
 */
export function getChunkStats(chunks: Chunk[]): {
  totalChunks: number;
  avgChunkSize: number;
  minChunkSize: number;
  maxChunkSize: number;
  totalTokens: number;
} {
  if (chunks.length === 0) {
    return {
      totalChunks: 0,
      avgChunkSize: 0,
      minChunkSize: 0,
      maxChunkSize: 0,
      totalTokens: 0
    };
  }

  const sizes = chunks.map(c => estimateTokens(c.text));
  const totalTokens = sizes.reduce((sum, size) => sum + size, 0);

  return {
    totalChunks: chunks.length,
    avgChunkSize: Math.round(totalTokens / chunks.length),
    minChunkSize: Math.min(...sizes),
    maxChunkSize: Math.max(...sizes),
    totalTokens
  };
}
