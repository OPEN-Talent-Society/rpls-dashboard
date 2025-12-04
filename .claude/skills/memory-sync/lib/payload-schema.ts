/**
 * Qdrant Payload Schema and Validation Library
 *
 * Provides TypeScript interfaces, Zod schemas, and utility functions
 * for validating and creating Qdrant payloads across all memory backends.
 */

import { z } from 'zod';

// ============================================================================
// TYPESCRIPT INTERFACES
// ============================================================================

/**
 * Standardized payload structure for Qdrant points
 */
export interface QdrantPayload {
  // === REQUIRED FIELDS ===
  type: 'learning' | 'pattern' | 'episode' | 'wiki' | 'code';
  source: 'supabase' | 'agentdb' | 'cortex' | 'github' | 'academy-wiki';
  topic: string;
  content: string; // truncated to ~1000 chars for efficient retrieval

  // === TIMESTAMPS ===
  created_at: string; // ISO 8601 format
  indexed_at: string; // ISO 8601 format

  // === HIERARCHICAL (for chunked documents) ===
  parent_id?: string;
  chunk_index?: number;
  total_chunks?: number;
  is_parent?: boolean;

  // === CATEGORIZATION ===
  category?: string;
  tags?: string[];
  agent?: string;

  // === RELATIONS ===
  related_ids?: string[];
  source_id?: string; // original UUID from source system

  // === CODE-SPECIFIC ===
  file_path?: string;
  language?: string;
  symbols?: string[];

  // === QUALITY METRICS ===
  reward?: number; // 0-1 for ReasoningBank patterns
  success?: boolean;
  confidence?: number; // 0-1
}

// ============================================================================
// ZOD VALIDATION SCHEMAS
// ============================================================================

/**
 * Zod schema for runtime validation of Qdrant payloads
 */
export const QdrantPayloadSchema = z.object({
  // Required fields
  type: z.enum(['learning', 'pattern', 'episode', 'wiki', 'code']),
  source: z.enum(['supabase', 'agentdb', 'cortex', 'github', 'academy-wiki']),
  topic: z.string().min(1, 'Topic cannot be empty'),
  content: z.string().min(1, 'Content cannot be empty').max(1000, 'Content exceeds 1000 characters'),

  // Timestamps
  created_at: z.string().datetime({ message: 'Invalid ISO 8601 timestamp' }),
  indexed_at: z.string().datetime({ message: 'Invalid ISO 8601 timestamp' }),

  // Hierarchical fields
  parent_id: z.string().uuid().optional(),
  chunk_index: z.number().int().nonnegative().optional(),
  total_chunks: z.number().int().positive().optional(),
  is_parent: z.boolean().optional(),

  // Categorization
  category: z.string().optional(),
  tags: z.array(z.string()).optional(),
  agent: z.string().optional(),

  // Relations
  related_ids: z.array(z.string().uuid()).optional(),
  source_id: z.string().uuid().optional(),

  // Code-specific
  file_path: z.string().optional(),
  language: z.string().optional(),
  symbols: z.array(z.string()).optional(),

  // Quality metrics
  reward: z.number().min(0).max(1).optional(),
  success: z.boolean().optional(),
  confidence: z.number().min(0).max(1).optional(),
}).strict(); // Reject unknown properties

// ============================================================================
// VALIDATION FUNCTIONS
// ============================================================================

/**
 * Validates a payload object against the Qdrant schema
 *
 * @param data - The payload to validate
 * @returns Validation result with parsed data or errors
 */
export function validatePayload(data: unknown): {
  success: boolean;
  data?: QdrantPayload;
  errors?: z.ZodError;
} {
  const result = QdrantPayloadSchema.safeParse(data);

  if (result.success) {
    return {
      success: true,
      data: result.data as QdrantPayload,
    };
  } else {
    return {
      success: false,
      errors: result.error,
    };
  }
}

// ============================================================================
// PAYLOAD CREATION HELPERS
// ============================================================================

/**
 * Creates a validated Qdrant payload with required fields
 *
 * @param type - Type of content (learning, pattern, episode, wiki, code)
 * @param source - Source system (supabase, agentdb, cortex, github, academy-wiki)
 * @param data - Additional payload data
 * @returns Validated QdrantPayload object
 * @throws Error if validation fails
 */
export function createPayload(
  type: QdrantPayload['type'],
  source: QdrantPayload['source'],
  data: Partial<Omit<QdrantPayload, 'type' | 'source' | 'indexed_at'>>
): QdrantPayload {
  const payload = {
    type,
    source,
    indexed_at: new Date().toISOString(),
    ...data,
  };

  const validation = validatePayload(payload);

  if (!validation.success) {
    throw new Error(
      `Payload validation failed: ${validation.errors?.issues.map(i => i.message).join(', ')}`
    );
  }

  return validation.data!;
}

// ============================================================================
// CONTENT SANITIZATION
// ============================================================================

/**
 * Sanitizes and truncates content for efficient embedding and retrieval
 *
 * @param text - Raw content text
 * @param maxLength - Maximum length (default: 1000)
 * @returns Sanitized and truncated content
 */
export function sanitizeContent(text: string, maxLength: number = 1000): string {
  if (!text) return '';

  // Remove excessive whitespace
  let sanitized = text
    .replace(/\r\n/g, '\n') // Normalize line endings
    .replace(/\n{3,}/g, '\n\n') // Collapse multiple newlines
    .replace(/[ \t]+/g, ' ') // Collapse multiple spaces
    .trim();

  // Truncate if needed
  if (sanitized.length > maxLength) {
    // Try to truncate at sentence boundary
    const truncated = sanitized.substring(0, maxLength);
    const lastPeriod = truncated.lastIndexOf('.');
    const lastNewline = truncated.lastIndexOf('\n');
    const breakPoint = Math.max(lastPeriod, lastNewline);

    if (breakPoint > maxLength * 0.8) {
      // Good break point found (within last 20%)
      sanitized = truncated.substring(0, breakPoint + 1).trim();
    } else {
      // No good break point, truncate at word boundary
      const lastSpace = truncated.lastIndexOf(' ');
      sanitized = (lastSpace > 0 ? truncated.substring(0, lastSpace) : truncated).trim() + '...';
    }
  }

  return sanitized;
}

// ============================================================================
// TYPE GUARDS
// ============================================================================

/**
 * Type guard to check if an object is a valid QdrantPayload
 */
export function isQdrantPayload(obj: unknown): obj is QdrantPayload {
  return validatePayload(obj).success;
}

// ============================================================================
// PAYLOAD TEMPLATES
// ============================================================================

/**
 * Creates a learning payload (Supabase source)
 */
export function createLearningPayload(
  topic: string,
  content: string,
  data?: Partial<QdrantPayload>
): QdrantPayload {
  return createPayload('learning', 'supabase', {
    topic,
    content: sanitizeContent(content),
    created_at: new Date().toISOString(),
    ...data,
  });
}

/**
 * Creates a pattern payload (AgentDB ReasoningBank source)
 */
export function createPatternPayload(
  topic: string,
  content: string,
  reward: number,
  success: boolean,
  data?: Partial<QdrantPayload>
): QdrantPayload {
  return createPayload('pattern', 'agentdb', {
    topic,
    content: sanitizeContent(content),
    created_at: new Date().toISOString(),
    reward,
    success,
    ...data,
  });
}

/**
 * Creates an episode payload (AgentDB episodes source)
 */
export function createEpisodePayload(
  topic: string,
  content: string,
  agent: string,
  data?: Partial<QdrantPayload>
): QdrantPayload {
  return createPayload('episode', 'agentdb', {
    topic,
    content: sanitizeContent(content),
    created_at: new Date().toISOString(),
    agent,
    ...data,
  });
}

/**
 * Creates a wiki payload (Cortex SiYuan source)
 */
export function createWikiPayload(
  topic: string,
  content: string,
  data?: Partial<QdrantPayload>
): QdrantPayload {
  return createPayload('wiki', 'cortex', {
    topic,
    content: sanitizeContent(content),
    created_at: new Date().toISOString(),
    ...data,
  });
}

/**
 * Creates a code payload (GitHub source)
 */
export function createCodePayload(
  topic: string,
  content: string,
  file_path: string,
  language: string,
  data?: Partial<QdrantPayload>
): QdrantPayload {
  return createPayload('code', 'github', {
    topic,
    content: sanitizeContent(content),
    created_at: new Date().toISOString(),
    file_path,
    language,
    ...data,
  });
}

// ============================================================================
// EXPORTS
// ============================================================================

export default {
  // Types
  QdrantPayloadSchema,

  // Validation
  validatePayload,
  isQdrantPayload,

  // Creation
  createPayload,
  createLearningPayload,
  createPatternPayload,
  createEpisodePayload,
  createWikiPayload,
  createCodePayload,

  // Utilities
  sanitizeContent,
};
