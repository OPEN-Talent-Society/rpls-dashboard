# Task List

## Epic A: Data Pipeline (ETL)
- [x] **Task A.1:** Verify DuckDB is installed and running in `etl_supabase.py`.
- [x] **Task A.2:** Implement `fact_hiring_attrition` loading logic.
- [x] **Task A.3:** Implement `fact_postings` loading logic.
- [x] **Task A.4:** Add Unit Tests for CSV parsing (Mock the file system).
- [x] **Task A.5:** Add Integration Test (Upsert to a local Supabase test project).
- [x] **Task A.6 (Mandatory):** Ingest high-volume CSVs (`employment_all_granularities`, `salaries_all_granularities`, `hiring_and_attrition_by_sector_occupation_state`, `postings_by_sector_occupation_state`) into new multi fact tables (naics2d, soc2d, state, date) with size guardrails.
- [x] **Task A.7 (Mandatory):** Load summary/overview/Table B CSVs into dedicated summary tables; add row-count + min/max date health checks per table.
- [x] **Task A.8 (Mandatory):** Add Supabase size estimator and hard stop at ~700 MB; log table sizes after ETL; document storage offload plan for overflow (consider parquet/export + CDN if nearing cap).

## Epic B: Frontend Core (SvelteKit)
- [x] **Task B.1:** Install `@supabase/supabase-js` in `rpls-dashboard`.
- [x] **Task B.2:** Create `src/lib/supabase.ts` client.
- [x] **Task B.3:** Create `src/routes/dashboard/+page.server.ts` to fetch Layoffs (moved to supabase store logic).
- [x] **Task B.4:** Create `LayoffChart.svelte` using the dynamic data.
- [x] **Task B.5:** Remove old JSON import logic (frontend now pulls from Supabase).
- [x] **Task B.6:** Wire stores/widgets to Supabase multi tables so sector/state/occupation filters use full granularity (headlines, salaries, hiring/attrition, layoffs).
- [ ] **Task B.7 (Mandatory):** Talent Market Scanner UI (sector-first) with sector/state/occupation filters across headlines, postings trend, salary trend, hiring vs attrition, layoffs/WARN.
- [ ] **Task B.8 (Mandatory):** Map view (state choropleth) for postings/hiring/attrition/salary driven by multi tables.
- [ ] **Task B.9 (Mandatory):** Data Lab: table + time-series builder with CSV/PNG export and shareable URLs.
- [ ] **Task B.10 (Mandatory):** My Market Check: occupation + state report card with benchmarks and shareable link.
- [ ] **Task B.11 (Mandatory):** Per-widget loading/error states and inline methodology/source footers.

## Epic C: Interactive Filters & Charts (Phase 2)
- [ ] **Task C.1:** Build a global filter store (date range, sector, occupation, state) with URL sync; add unit tests for reducer logic and serialization.
- [ ] **Task C.2:** Apply filters to Supabase queries across widgets (headlines, spotlight, hiring quadrant, salary, layoffs); add loading/error states per widget and integration tests that mock Supabase responses.
- [ ] **Task C.3:** Replace Chart.js with a more interactive charting lib (e.g., LayerChart/Recharts for Svelte) and refactor LayoffChart/Quadrant/Sector visualizations; add snapshot/render tests for chart configs.
- [ ] **Task C.4:** Add date-picker and sector/occupation dropdown UX with empty-state handling; test input validation and filter-reset behavior.
- [ ] **Task C.5:** Performance pass on client data shaping (memoized derived stores, minimal payload selects); add a perf guardrail test that rejects N+1 queries in mock runs.

## Epic D: Auth & Saved Views (Phase 2)
- [ ] **Task D.1:** Wire Supabase Auth (email magic link or OAuth) with session store in Svelte; add auth flow tests with mocked Supabase auth client.
- [ ] **Task D.2:** Gate “save view” actions behind auth; create `saved_views` table (schema + migration) and CRUD endpoints/server actions; add contract tests for the API shape.
- [ ] **Task D.3:** Persist and restore filters to/from saved views; add integration tests that round-trip a saved view and rehydrate the UI.
- [ ] **Task D.4:** Add basic RBAC/row-level security checks for saved views; add regression tests that verify unauthorized access is blocked.
- [ ] **Task D.5:** UX polish for auth states (loading, errors, logged-in header); add component tests for header/login button state machine.

## Epic E: Testing (London School TDD)
- [x] **Task E.1:** Create `tests/etl.spec.ts` - Test data transformation without connecting to DB.
- [x] **Task E.2:** Create `tests/components/Dashboard.spec.ts` - Mock the Supabase network response and verify UI renders the chart.
- [x] Added live Supabase integration test `tests/supabase.integration.test.ts` (requires env).
- [ ] **Task E.3:** Add filter-store unit tests (URL sync, defaults, reset) and integration tests covering filtered Supabase queries.
- [ ] **Task E.4:** Add chart config/render tests after the charting refactor (C.3).
- [ ] **Task E.5:** Add auth/saved-view tests (API contract + UI flows) tied to Epic D.
- [ ] **Task E.6:** Add AI pipeline tests (filter JSON generation, /api/analyze prompt/response validation) tied to Epic F.
- [ ] **Task E.7:** Add manifest/health checks (row counts, min/max dates) as CI guardrails; ensure they run against Supabase with safe limits.
- [ ] **Task E.8:** Add `/api/status` and `/api/sample` runtime health checks in CI to confirm Supabase data availability.
- [ ] **Task E.9:** Add data coverage checks for YoY availability by sector; report missing year-ago rows as warnings in CI.
- [ ] **Task E.10 (Mandatory):** Add size/regression check for multi tables (row counts vs expected months) to block deploy on partial loads.

## Epic F: AI & Insights (Phase 3)
- [ ] **Task F.1:** Install `ai`, `@google/generative-ai`, and add env plumbing for Gemini keys; add config validation tests to fail fast when env is missing.
- [ ] **Task F.2:** Implement text-to-filter JSON using `generateObject`; add unit tests with sample prompts to ensure schema-conformant outputs.
- [ ] **Task F.3:** Create `/api/analyze` (or SvelteKit endpoint) to accept chart data and stream Gemini insights; add contract tests for request/response schema and streaming chunks.
- [ ] **Task F.4:** Add guardrails (prompt templates, content filters, output validation with Zod) and redaction for PII; add regression tests for “bad prompt” and “toxic content” cases.
- [ ] **Task F.5:** Add caching for repeated analytics queries (keyed by filter hash); add tests for cache hit/miss and TTL behavior.
- [ ] **Task F.6:** Document AI safety boundaries in `.spec/v1/ai_architecture.md` and ensure code reflects them; add a lint/check that fails if required envs are absent in CI.
