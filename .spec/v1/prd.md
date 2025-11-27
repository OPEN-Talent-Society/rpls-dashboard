# Product Requirements Document (PRD) - v1.0
**Project:** RPLS Intelligence Platform (formerly Dashboard)
**Status:** Draft

## 1. Executive Summary
The RPLS Intelligence Platform transforms raw labor market CSV dumps into a real-time, queryable, and intelligent research tool. Unlike the previous static dashboard, this platform allows users to query historical trends, compare sectors dynamically, and receive AI-generated insights on labor market movements.

## 2. User Personas
*   **The Labor Economist (Alice):** Needs raw data access, export capabilities, and complex filtering (e.g., "Show me lay offs in Tech vs. Hiring in Health for 2023").
*   **The Strategic Planner (Bob):** Needs high-level summaries, "Red Flag" alerts (e.g., "Attrition spiking in Engineering"), and natural language answers.

## 3. Functional Requirements

### 3.1 Data Ingestion & Management (Core)
*   **FR-01:** System must ingest standard Revelio Labs CSV dumps via a robust pipeline.
*   **FR-02:** System must handle currency (`$100k`) and percentage (`5%`) sanitization automatically.
*   **FR-03:** Data must be stored in a normalized Star Schema (Fact/Dim tables).

### 3.2 Visualization & Querying (Core)
*   **FR-04:** Users can view a "Command Center" dashboard with top metrics (Health Index, Total Layoffs).
*   **FR-05:** Users can filter charts by Date Range, Sector, State, and Occupation.
*   **FR-06:** Quadrant Chart (Hiring vs. Attrition) must be dynamic/interactive.

### 3.3 Intelligence & Search (Enhancement)
*   **FR-07:** Users can search for sectors using natural language (Semantic Search).
*   **FR-08:** System provides AI-generated summaries of "Why" trends are happening (using Sector Summary text).
*   **FR-09:** **Query Intent Translation:** System translates natural language questions (e.g., "Show me high attrition in Tech") into structured Database Filters.
    *   *Guardrail:* The AI never queries the database directly with SQL. It outputs a JSON Filter Object validated by Zod schemas.
*   **FR-10:** **Contextual Summarization:** System generates executive summaries of the visualized data.
    *   *Model Strategy:* Use **Gemini 2.5 Flash Lite** for high-speed, low-cost summaries of simple tables. Use **Gemini 1.5 Pro** for complex reasoning on multi-year trends.

### 3.4 AI Guardrails & Security
*   **FR-11:** **Hallucination Prevention:** The AI UI must strictly distinguish between "Hard Data" (from DB) and "AI Analysis" (Generated text).
*   **FR-12:** **Read-Only Analysis:** AI agents have strictly Read-Only access to the data. They cannot mutate database records.
*   **FR-13:** **Prompt Injection Protection:** User inputs for semantic search are sanitized before being sent to the LLM.

### 3.5 User Experience (Excellence)
*   **FR-14:** **Command Palette (God Mode):** A global `Cmd+K` interface that accepts natural language or keywords to filter data instantly.
    *   *Tech:* AI Intent Translation maps "Tech layoffs CA" -> `{ sector: 'Tech', state: 'CA' }`.
*   **FR-15:** **Bi-Directional Data Linking:**
    *   Hovering AI text highlights chart elements.
    *   Hovering chart elements highlights relevant AI text.
*   **FR-16:** **Strict Accessibility:**
    *   All charts must have a companion `sr-only` HTML Table.
    *   Focus management for keyboard navigation (no focus traps).

## 4. Non-Functional Requirements
*   **Perceived Performance:**
    *   Hard Data (Charts) loads in < 300ms.
    *   AI Insights use **Streaming** (Time to First Token < 500ms).
    *   Filter actions use **Optimistic UI** (Update UI immediately, rollback on error).
*   **Scalability:** Database handles 5+ years of historical data (approx. 10M rows).
*   **Reliability:** ETL pipeline fails safely with alerts if CSV schema changes.

## 5. Success Metrics
*   **Data Freshness:** Time from "CSV Drop" to "Dashboard Update" < 5 minutes.
*   **Query Usage:** Number of custom filters applied per session > 3.
*   **Trust Score:** % of users who verify AI insights by interacting with linked data > 40%.
