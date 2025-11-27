# Task List

## Epic A: Data Pipeline (ETL)
- [x] **Task A.1:** Verify DuckDB is installed and running in `etl_supabase.py`.
- [x] **Task A.2:** Implement `fact_hiring_attrition` loading logic.
- [x] **Task A.3:** Implement `fact_postings` loading logic.
- [ ] **Task A.4:** Add Unit Tests for CSV parsing (Mock the file system).
- [x] **Task A.5:** Add Integration Test (Upsert to a local Supabase test project).

## Epic B: Frontend Core (SvelteKit)
- [x] **Task B.1:** Install `@supabase/supabase-js` in `rpls-dashboard`.
- [x] **Task B.2:** Create `src/lib/supabase.ts` client.
- [x] **Task B.3:** Create `src/routes/dashboard/+page.server.ts` to fetch Layoffs (moved to supabase store logic).
- [ ] **Task B.4:** Create `LayoffChart.svelte` using the dynamic data.
- [x] **Task B.5:** Remove old JSON import logic (frontend now pulls from Supabase).

## Epic E: Testing (London School TDD)
- [ ] **Task E.1:** Create `tests/etl.spec.py` - Test data transformation without connecting to DB.
- [ ] **Task E.2:** Create `tests/components/Dashboard.spec.ts` - Mock the Supabase network response and verify UI renders the chart.
- [x] Added live Supabase integration test `tests/supabase.integration.test.ts` (requires env).
