# Execution Plan

## Phase 1: Foundation (Core Data & UI, Mandatory)
**Goal:** Fully load RPLS data (including granularity files) and ship a sector-first dashboard for HR/TA.  
**Status:** Supabase schema + multi tables are live; ETL loads all granularity + summary tables; dashboard stores now read from Supabase multi tables. Next: build the sector-first UI (Scanner) and map.
1.  **Setup:** Supabase schema (core + multi tables) with size guardrails; normalize NAICS/SOC dims.
2.  **ETL:** Load *all* CSVs (layoffs, hiring, salaries, postings, employment) plus multi-dimension files; add summary/overview/Table B tables; block if payload > ~700 MB.
3.  **Frontend:** Sector-first “Talent Market Scanner” with sector/state/occupation filters (headlines, postings trend, salary trend, hiring vs attrition, layoffs/WARN); wire map.
4.  **Transparency:** In-app methodology and per-chart sourcing; health/status checks.

## Phase 2: Enhancements (Interactive Dashboard, Mandatory)
**Goal:** Deep drill and comparison views without login.
1.  **Filters:** Global date/sector/occupation/state with URL sync and shareable links.
2.  **Charts:** Upgrade to interactive charting (LayerChart/ECharts/Plotly) for all widgets; add map (state choropleth).
3.  **Views:** Data Lab (table + time-series builder) and My Market Check (occupation/state report card); export PNG/CSV.

## Phase 3: Intelligence (AI & Search)
**Goal:** Add "Reasoning" to the data using Gemini & Vercel AI SDK.
1.  **Infrastructure:**
    *   Install `ai` and `@google/generative-ai`.
    *   Configure `GoogleGenerativeAIProvider` with API Keys.
2.  **Feature: Smart Filters (Flash Lite):**
    *   Implement `generateObject` (Vercel AI) to convert text input to Filter JSON.
    *   Connect Filter JSON to Supabase Query Builder.
3.  **Feature: Chart Insights (Flash):**
    *   Create an API route `/api/analyze` that accepts chart data.
    *   Stream text response to the client using `streamText`.
4.  **Optimization:**
    *   Implement caching for frequent queries.
    *   Add "Guardrails" middleware to sanitize inputs.
