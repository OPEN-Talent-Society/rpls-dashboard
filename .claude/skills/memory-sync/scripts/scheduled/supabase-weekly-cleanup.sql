-- Supabase Weekly Cleanup Script
-- Purpose: Delete old learnings, remove failed patterns, vacuum tables
-- Schedule: Weekly on Sunday at 4:00 AM
-- Cron (using pg_cron): SELECT cron.schedule('supabase-weekly-cleanup', '0 4 * * 0', $$[SQL from this file]$$);
--
-- Manual execution:
--   psql $DATABASE_URL -f supabase-weekly-cleanup.sql
--
-- OR via Supabase SQL Editor:
--   Copy/paste this file and execute
--
-- Created: 2025-12-12

-- ============================================
-- CONFIGURATION
-- ============================================

-- Retention periods (days)
\set learnings_retention 180
\set patterns_retention 90

-- ============================================
-- DELETE OLD LEARNINGS (>180 days, no refs)
-- ============================================

-- Report before deletion
DO $$
DECLARE
    old_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO old_count
    FROM agent_learnings
    WHERE created_at < NOW() - INTERVAL '180 days'
    AND id NOT IN (
        -- Keep learnings that are referenced by patterns
        SELECT DISTINCT unnest(string_to_array(metadata->>'learning_ids', ','))::uuid
        FROM agent_patterns
        WHERE metadata->>'learning_ids' IS NOT NULL
    );

    RAISE NOTICE 'Found % old learnings (>180 days with no references)', old_count;
END $$;

-- Delete old unreferenced learnings
DELETE FROM agent_learnings
WHERE created_at < NOW() - INTERVAL '180 days'
AND id NOT IN (
    SELECT DISTINCT unnest(string_to_array(metadata->>'learning_ids', ','))::uuid
    FROM agent_patterns
    WHERE metadata->>'learning_ids' IS NOT NULL
);

-- Report deletion result
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % old learnings', deleted_count;
END $$;

-- ============================================
-- DELETE FAILED PATTERNS (success_count=0, >90 days)
-- ============================================

-- Report before deletion
DO $$
DECLARE
    failed_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO failed_count
    FROM agent_patterns
    WHERE created_at < NOW() - INTERVAL '90 days'
    AND success_count = 0;

    RAISE NOTICE 'Found % failed patterns (success_count=0, >90 days)', failed_count;
END $$;

-- Delete failed patterns
DELETE FROM agent_patterns
WHERE created_at < NOW() - INTERVAL '90 days'
AND success_count = 0;

-- Report deletion result
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % failed patterns', deleted_count;
END $$;

-- ============================================
-- DELETE DUPLICATE LEARNINGS (same task_id + context)
-- ============================================

-- Report before deletion
DO $$
DECLARE
    dupe_count INTEGER;
BEGIN
    WITH duplicates AS (
        SELECT
            id,
            ROW_NUMBER() OVER (
                PARTITION BY task_id, context
                ORDER BY created_at DESC
            ) as rn
        FROM agent_learnings
        WHERE task_id IS NOT NULL
    )
    SELECT COUNT(*) INTO dupe_count
    FROM duplicates
    WHERE rn > 1;

    RAISE NOTICE 'Found % duplicate learnings (same task_id + context)', dupe_count;
END $$;

-- Delete duplicates (keep most recent)
WITH duplicates AS (
    SELECT
        id,
        ROW_NUMBER() OVER (
            PARTITION BY task_id, context
            ORDER BY created_at DESC
        ) as rn
    FROM agent_learnings
    WHERE task_id IS NOT NULL
)
DELETE FROM agent_learnings
WHERE id IN (
    SELECT id FROM duplicates WHERE rn > 1
);

-- Report deletion result
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % duplicate learnings', deleted_count;
END $$;

-- ============================================
-- DELETE ORPHANED TELEMETRY (>7 days)
-- ============================================

-- Report before deletion
DO $$
DECLARE
    telem_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO telem_count
    FROM operations_telemetry
    WHERE timestamp < NOW() - INTERVAL '7 days';

    RAISE NOTICE 'Found % old telemetry records (>7 days)', telem_count;
END $$;

-- Delete old telemetry
DELETE FROM operations_telemetry
WHERE timestamp < NOW() - INTERVAL '7 days';

-- Report deletion result
DO $$
DECLARE
    deleted_count INTEGER;
BEGIN
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RAISE NOTICE 'Deleted % telemetry records', deleted_count;
END $$;

-- ============================================
-- VACUUM TABLES TO RECLAIM SPACE
-- ============================================

-- Vacuum agent_learnings
VACUUM ANALYZE agent_learnings;
RAISE NOTICE 'Vacuumed agent_learnings table';

-- Vacuum agent_patterns
VACUUM ANALYZE agent_patterns;
RAISE NOTICE 'Vacuumed agent_patterns table';

-- Vacuum operations_telemetry
VACUUM ANALYZE operations_telemetry;
RAISE NOTICE 'Vacuumed operations_telemetry table';

-- ============================================
-- UPDATE TABLE STATISTICS
-- ============================================

-- Analyze all tables for query optimization
ANALYZE agent_learnings;
ANALYZE agent_patterns;
ANALYZE operations_telemetry;

RAISE NOTICE 'Updated table statistics';

-- ============================================
-- FINAL REPORT
-- ============================================

DO $$
DECLARE
    learnings_count INTEGER;
    patterns_count INTEGER;
    telemetry_count INTEGER;
    total_size TEXT;
BEGIN
    -- Count remaining records
    SELECT COUNT(*) INTO learnings_count FROM agent_learnings;
    SELECT COUNT(*) INTO patterns_count FROM agent_patterns;
    SELECT COUNT(*) INTO telemetry_count FROM operations_telemetry;

    -- Get database size
    SELECT pg_size_pretty(pg_database_size(current_database())) INTO total_size;

    -- Print report
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Weekly Cleanup Complete';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Remaining records:';
    RAISE NOTICE '  - agent_learnings: %', learnings_count;
    RAISE NOTICE '  - agent_patterns: %', patterns_count;
    RAISE NOTICE '  - operations_telemetry: %', telemetry_count;
    RAISE NOTICE 'Database size: %', total_size;
    RAISE NOTICE '============================================';
END $$;

-- ============================================
-- SETUP pg_cron JOB (Optional - Run Once)
-- ============================================

-- Uncomment to setup automated weekly execution via pg_cron
-- Requires pg_cron extension to be enabled in Supabase
--
-- SELECT cron.schedule(
--     'supabase-weekly-cleanup',
--     '0 4 * * 0',  -- Every Sunday at 4:00 AM
--     $$
--     -- Delete old learnings (>180 days, no refs)
--     DELETE FROM agent_learnings
--     WHERE created_at < NOW() - INTERVAL '180 days'
--     AND id NOT IN (
--         SELECT DISTINCT unnest(string_to_array(metadata->>'learning_ids', ','))::uuid
--         FROM agent_patterns
--         WHERE metadata->>'learning_ids' IS NOT NULL
--     );
--
--     -- Delete failed patterns (>90 days, success_count=0)
--     DELETE FROM agent_patterns
--     WHERE created_at < NOW() - INTERVAL '90 days'
--     AND success_count = 0;
--
--     -- Delete duplicate learnings
--     WITH duplicates AS (
--         SELECT id, ROW_NUMBER() OVER (
--             PARTITION BY task_id, context ORDER BY created_at DESC
--         ) as rn FROM agent_learnings WHERE task_id IS NOT NULL
--     )
--     DELETE FROM agent_learnings WHERE id IN (
--         SELECT id FROM duplicates WHERE rn > 1
--     );
--
--     -- Delete old telemetry (>7 days)
--     DELETE FROM operations_telemetry
--     WHERE timestamp < NOW() - INTERVAL '7 days';
--
--     -- Vacuum tables
--     VACUUM ANALYZE agent_learnings;
--     VACUUM ANALYZE agent_patterns;
--     VACUUM ANALYZE operations_telemetry;
--     $$
-- );

-- To check scheduled jobs:
-- SELECT * FROM cron.job;

-- To unschedule:
-- SELECT cron.unschedule('supabase-weekly-cleanup');
