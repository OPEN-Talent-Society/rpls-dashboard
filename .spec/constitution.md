# Project Constitution: RPLS Intelligence Platform

## 1. Core Philosophy
- **Spec-Driven Development (SDD):** All features must start with a Specification (`spec.md`) and Plan (`plan.md`) before code is written.
- **Data Gravity:** The database is the source of truth. We do not build "API Servers"; we build "Data Pipelines" and "Database Schemas".
- **London School TDD:** We test behavior, not implementation. We mock external dependencies (Supabase, File System) to ensure fast, deterministic unit tests.
- **Excellence over Perfection:** We ship high-ROI features. We do not gold-plate unused features.

## 2. Architecture Standards
- **ETL Layer:** Python + DuckDB + Polars. No manual CSV parsing loops.
- **Storage Layer:** Supabase (PostgreSQL). All business logic lives in the Database (RLS, Triggers) or the ETL layer.
- **API Layer:** PostgREST (via Supabase Client). No intermediate Backend API (FastAPI/Express) unless strictly necessary for complex orchestration.
- **Frontend Layer:** SvelteKit + Tailwind CSS.
- **Intelligence Layer:** pgvector for semantic search.

## 3. Coding Standards
- **Types:** Strict TypeScript in Frontend. Type hints in Python.
- **Testing:** 
  - Frontend: Vitest + Testing Library.
  - Backend (ETL): Pytest.
- **Documentation:** OpenAPI specs for all database interfaces.

## 4. Workflow
1. **Specify:** Define the User Story and Requirements.
2. **Plan:** detailed technical approach.
3. **Tasks:** Break down into atomic, verifiable steps.
4. **Implement:** Code + Test.
