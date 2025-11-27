# Execution Plan

## Phase 1: Foundation (Core Data & UI)
**Goal:** Replace the Python-to-JSON script with a Database-backed App.
1.  **Setup:** Initialize Supabase Project & Schema.
2.  **ETL:** Finalize `etl_supabase.py` to handle all CSV types (Layoffs, Hiring, Salaries).
3.  **Backend:** None (Serverless).
4.  **Frontend:** Connect SvelteKit to Supabase. Re-implement "Sector Spotlight" using DB queries.

## Phase 2: Enhancements (Interactive Dashboard)
**Goal:** Enable dynamic user queries.
1.  **Filters:** Add global Date/Sector state management in Svelte.
2.  **Charts:** Replace Chart.js with Recharts/LayerChart.
3.  **Auth:** Enable Supabase Auth to allow "Saving" views.

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
