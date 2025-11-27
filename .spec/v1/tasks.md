# Task List

## Epic A: Data Pipeline (ETL)
- [ ] **Task A.1:** Verify DuckDB is installed and running in `etl_supabase.py`.
- [ ] **Task A.2:** Implement `fact_hiring_attrition` loading logic.
- [ ] **Task A.3:** Implement `fact_postings` loading logic.
- [ ] **Task A.4:** Add Unit Tests for CSV parsing (Mock the file system).
- [ ] **Task A.5:** Add Integration Test (Upsert to a local Supabase mock or test project).

## Epic B: Frontend Core (SvelteKit)
- [ ] **Task B.1:** Install `@supabase/supabase-js` in `rpls-dashboard`.
- [ ] **Task B.2:** Create `src/lib/supabase.ts` client.
- [ ] **Task B.3:** Create `src/routes/dashboard/+page.server.ts` to fetch Layoffs.
- [ ] **Task B.4:** Create `LayoffChart.svelte` using the dynamic data.
- [ ] **Task B.5:** Remove old JSON import logic.

## Epic E: Testing (London School TDD)
- [ ] **Task E.1:** Create `tests/etl.spec.py` - Test data transformation without connecting to DB.
- [ ] **Task E.2:** Create `tests/components/Dashboard.spec.ts` - Mock the Supabase network response and verify UI renders the chart.
