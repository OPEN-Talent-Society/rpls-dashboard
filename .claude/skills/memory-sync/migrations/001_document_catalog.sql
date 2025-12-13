-- Document Catalog Tables for Smart Document Indexer
-- Run this in Supabase SQL Editor

-- Document Catalog: Main table for document metadata
CREATE TABLE IF NOT EXISTS document_catalog (
    id SERIAL PRIMARY KEY,
    doc_id TEXT UNIQUE NOT NULL,
    filepath TEXT NOT NULL,
    filename TEXT NOT NULL,
    filetype TEXT NOT NULL,
    description TEXT,
    tags JSONB DEFAULT '[]'::jsonb,
    category TEXT DEFAULT 'general',
    total_chunks INTEGER DEFAULT 1,
    word_count INTEGER DEFAULT 0,
    indexed_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for document_catalog
CREATE INDEX IF NOT EXISTS idx_document_catalog_doc_id ON document_catalog(doc_id);
CREATE INDEX IF NOT EXISTS idx_document_catalog_category ON document_catalog(category);
CREATE INDEX IF NOT EXISTS idx_document_catalog_filetype ON document_catalog(filetype);
CREATE INDEX IF NOT EXISTS idx_document_catalog_tags ON document_catalog USING GIN (tags);

-- Document Chunks: Lightweight index for chunk navigation
CREATE TABLE IF NOT EXISTS document_chunks (
    id SERIAL PRIMARY KEY,
    chunk_id TEXT UNIQUE NOT NULL,
    doc_id TEXT NOT NULL REFERENCES document_catalog(doc_id) ON DELETE CASCADE,
    chunk_index INTEGER NOT NULL,
    total_chunks INTEGER NOT NULL,
    prev_chunk_summary TEXT,
    next_chunk_summary TEXT,
    preview TEXT,  -- First 100 chars for quick preview
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for document_chunks
CREATE INDEX IF NOT EXISTS idx_document_chunks_doc_id ON document_chunks(doc_id);
CREATE INDEX IF NOT EXISTS idx_document_chunks_chunk_id ON document_chunks(chunk_id);

-- Enable Row Level Security
ALTER TABLE document_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE document_chunks ENABLE ROW LEVEL SECURITY;

-- Policies (allow service role full access)
CREATE POLICY "Service role full access to document_catalog"
    ON document_catalog FOR ALL
    USING (true)
    WITH CHECK (true);

CREATE POLICY "Service role full access to document_chunks"
    ON document_chunks FOR ALL
    USING (true)
    WITH CHECK (true);

-- Useful views
CREATE OR REPLACE VIEW document_summary AS
SELECT
    dc.doc_id,
    dc.filename,
    dc.filetype,
    dc.description,
    dc.tags,
    dc.category,
    dc.total_chunks,
    dc.word_count,
    dc.indexed_at,
    COUNT(ch.id) as chunks_indexed
FROM document_catalog dc
LEFT JOIN document_chunks ch ON dc.doc_id = ch.doc_id
GROUP BY dc.id;

-- Function to get document with all chunks
CREATE OR REPLACE FUNCTION get_document_chunks(p_doc_id TEXT)
RETURNS TABLE (
    chunk_id TEXT,
    chunk_index INTEGER,
    total_chunks INTEGER,
    prev_summary TEXT,
    next_summary TEXT,
    preview TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ch.chunk_id,
        ch.chunk_index,
        ch.total_chunks,
        ch.prev_chunk_summary,
        ch.next_chunk_summary,
        ch.preview
    FROM document_chunks ch
    WHERE ch.doc_id = p_doc_id
    ORDER BY ch.chunk_index;
END;
$$ LANGUAGE plpgsql;

-- Function to search documents by tags
CREATE OR REPLACE FUNCTION search_documents_by_tag(p_tag TEXT)
RETURNS SETOF document_catalog AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM document_catalog
    WHERE tags @> jsonb_build_array(p_tag);
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE document_catalog IS 'Catalog of indexed documents with AI-generated metadata';
COMMENT ON TABLE document_chunks IS 'Lightweight chunk index for navigation (full content in Qdrant)';
