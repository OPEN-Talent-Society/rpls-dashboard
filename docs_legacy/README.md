# Documentation Map & Current Architecture

This repo keeps specs under `docs/`. There is no `.spec` folder; use the files below:

- `docs/spec.md` – product epics/scope (RPLS dashboard slices).
- `docs/TECHNICAL_SPECS.md` – legacy Svelte tech notes.
- `docs/DATA_ARCHITECTURE.md` – canonical RPLS data tables and dimensions.
- `.spec/` – spec-driven files (constitution, PRD, plan, tasks, AI architecture, design system) under `.spec/v1/*.md`.

## Source of Truth (current stack)
- Data: `rpls_data/` CSVs → `backend/etl.py` builds `backend/rpls.duckdb`.
- API: FastAPI in `backend/main.py` (endpoints `/api/summary`, `/api/sector-spotlight`, `/api/salaries/*`, `/api/hiring-quadrant`, `/api/layoffs-summary`, `/api/history`, `/api/top-movers`, etc.).
- Frontend: SvelteKit (`src/routes/+page.svelte`) calling the API (`src/lib/stores/data.ts`), built with `VITE_API_BASE` (default http://127.0.0.1:9055 in local preview).

## Supabase scaffold (optional)
- `backend/etl_supabase.py`, `backend/requirements_etl.txt`, `supabase/schema.sql`, `src/lib/supabase.ts` are scaffolding for pushing cleaned data into Supabase; they are not wired into the current runtime.

## Validation/Tests
- `backend/validate.py` – quick manifest/API health check.
- `backend/test_api.py` – TestClient smoke tests for summary, salaries, spotlight, quadrant.

## Next doc updates to consider
- Refresh `docs/TECHNICAL_SPECS.md` to match the current FastAPI + SvelteKit + DuckDB stack (and note Supabase is optional).
- Add a short API surface README pointing to live endpoints and response shapes.
