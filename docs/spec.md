---
id: rpls-dashboard-spec
title: RPLS Dashboard Spec
owner: product
status: draft
last_reviewed_at: 2025-01-24
tags:
  - data-viz
  - rpls
  - dashboard
---

# RPLS Dashboard Spec (SPARC-aligned)

## 1. Context Snapshot
- Goals/KPIs:
  - Complete, trusted RPLS dashboard (all CSVs ingested).
  - <1s p95 API responses for common queries.
  - Users can find top movers and trends in <8s (scan).
- Constraints:
  - Local dev; minimal external infra. Gemini via server-side proxy. Light CTAs.
- Users / JTBD:
  - TA leads: identify hot/cold sectors/states fast; share summary.
  - HRBPs: see hiring/attrition movement; get prompts for managers.
  - Analysts/Econ: trend consistency; exportable, cited numbers.

## 2. Solution Options
| Option | Summary | Benefits | Risks | Effort | Decision |
| --- | --- | --- | --- | --- | --- |
| A | DuckDB/SQLite + custom API | Fast, local, no external deps | Need careful schema/cache | Med | Chosen |
| B | Supabase/Postgres | Managed DB, auth ready | Overhead/latency; ops complexity | High | Rejected |
| C | Client-side CSV parsing | Zero backend | Slow, inconsistent, no trust | Low | Rejected |

## 3. Release Slices
| Slice | Target Users | Scope | Acceptance Criteria | Metrics | Owner |
| --- | --- | --- | --- | --- | --- |
| Foundation | Internal | ETL all CSVs → DuckDB; canonical schema; `/datasets` | All tables present; ingest metadata exposed | 100% CSV coverage | Codex |
| Core UI | TA/HR/Econ | `/search`, `/query`, `/top-movers`; 3 visuals; banner | Queries correct deltas; visuals load <1s; banner shows version | p95 <1s common queries | Codex |
| Depth | Power users | SOC/NAICS drilldowns; comparison | SOC/NAICS views correct; comparisons work | Spot checks | Codex |
| Assist | Content/TA | Gemini summaries with citations/version | Outputs <=3 sentences citing numbers; version shown | Manual QA | Codex |

## 4. Delivery Plan
- Dependencies: DuckDB/SQLite; pandas for ETL; Recharts; simple SVG map; Gemini server-side proxy.
- Timeline & Milestones: phased (see epics below).
- Required Reviews: self-review; no formal security/legal.

## 5. Risk Register
| Risk | Impact | Likelihood | Mitigation | Trigger | Owner |
| --- | --- | --- | --- | --- | --- |
| Wrong joins/deltas | High | Med | Canonical schema, tests/spot-checks | QA failures | Codex |
| Gemini hallucinations | Med | Med | Tight prompts, limited context, version stamp | Off-topic outputs | Codex |
| Performance slow | Med | Med | Precompute deltas, cache warmup | p95 >1s | Codex |
| Adoption (trust) | Med | Med | Version/banner, caveats, numeric citations | User feedback | Codex |

## 6. Open Questions & Follow-Ups
- [ ] Auth/multi-tenant needed later? (assumed no)
- [ ] Export formats beyond copy/PNG? (assumed no)

## 7. Recommendation
- Proceed with DuckDB, canonical schema, minimal strong visuals, then depth and Gemini assist.

## 8. Next Steps
1. Phase 1: ETL all CSVs → DuckDB + `/datasets`.
2. Phase 2: `/search` + `/query` + `/top-movers`.
3. Phase 3: Core visuals + banner + top-movers strip.
4. Phase 4: SOC/NAICS depth + comparisons.
5. Phase 5: Gemini assist with guardrails.
6. Phase 6: Polish/perf; exports with version.

---

# Epics (parallel-friendly, with tasks)

## Epic: Data & ETL Backbone
**Goal:** Ingest all CSVs; canonical schema; DuckDB build; ingest metadata.

Tasks (noob-friendly):
- [ ] List all CSVs in `rpls_data` and document columns.
- [ ] Define schema: dimensions (sector/naics2d_code+name, state, soc2d_code+name, national); metrics (employment, postings, hiring_rate, attrition_rate, salary, layoffs), sa/nsa flags, units.
- [ ] Write ETL script (Python): load CSVs, normalize dates, parse money/numbers, write to DuckDB/SQLite.
- [ ] Compute MoM/YoY deltas and rank changes per dimension/metric.
- [ ] Create views: `top_movers_<metric>_<dimension>` (top/bottom N).
- [ ] Store ingest metadata (timestamp, file list, row counts, min/max month) in a table.
- [ ] Validation: script prints row counts, min/max dates, NaN/null counts per table.

Acceptance Criteria:
- All CSVs ingested into DuckDB with documented column mappings and units; no missing tables.
- Validation report shows row counts and min/max dates matching expectations; no unparsed columns.
- Views for deltas and top movers exist and return non-empty results.
- DuckDB file path and version recorded; ingest metadata table populated.

## Epic: Query/Search API Layer
**Goal:** Provide consistent endpoints over DuckDB with metadata.

Tasks:
- [ ] Add DB connection module (read-only) with warm cache on startup.
- [ ] Implement `/datasets`: returns manifest (tables, rows, min/max month, ingest time).
- [ ] Implement `/search`: search across sector/state/SOC names/codes; returns id/type/label.
- [ ] Implement `/query`: params (dimension_type/id, metric, window, sa/nsa, aggregate) → returns series + deltas + version metadata.
- [ ] Implement `/top-movers`: params (metric, dimension_type, count, window) → returns top/bottom movers.
- [ ] Input validation: whitelist dimensions/metrics; sanitize window params.
- [ ] Add version/ingest info to responses.
- [ ] Keep legacy endpoints mapped to DB for compatibility.

Acceptance Criteria:
- `/datasets` returns manifest with ingest time, table list, row counts, min/max month.
- `/search` finds sector/state/SOC codes/names; p95 <200ms locally.
- `/query` returns correct series/deltas vs golden snapshot for at least 3 fixtures (sector, state, SOC).
- `/top-movers` returns correct ordered movers for a sample metric/dimension; includes version/ingest metadata.
- Input validation rejects bad params with clear errors.

## Epic: Core Visuals & UX
**Goal:** Deliver the primary, fast visuals with trust cues.

Tasks:
- [ ] Add short-history trends: mini sparklines (3–6 months) for Market Temperature (dual-line hiring vs attrition) and for Sector Pulse/Spotlight tiles (employment/postings/salary).
- [ ] Add an oversized hero strip with headline + dual-line mini-chart (hiring vs attrition) and a movers ticker.
- [ ] Add data/version banner (release month, ingest time, caveats).
- [ ] Add search bar wired to `/search` to set filters.
- [ ] Hiring vs Attrition line/area chart (Recharts) for Total US + filter (sector/state).
- [ ] Postings/Layoffs choropleth (simple SVG map) + top/bottom lists.
- [ ] Sector Pulse grid (employment/postings/salary pct change with arrows).
- [ ] Top movers strip above the fold.
- [ ] Table view with pagination for numeric detail (linked to filters).
- [ ] Copy summary/export with version footer.

Acceptance Criteria:
- Page renders with default filter (Total US) and shows all three visuals without errors.
- Data/version banner shows release month, ingest time, and a short caveat.
- Search updates filters across visuals; loading/empty/error states are handled gracefully.
- p95 render time for visuals <1s on local data; top-movers strip matches API results.
- Copy/export includes version/footer text.

## Epic: SOC/NAICS Depth
**Goal:** Drill into occupations and sectors with richer metrics.

Tasks:
- [ ] SOC drilldown page: salaries, postings, hiring/attrition by SOC; sortable table; sparkline.
- [ ] NAICS drilldown page: layoffs_by_naics, salary_overview_naics, table_b_naics.
- [ ] Comparison view: sector vs state vs national trend (two-series line).
- [ ] Wire to `/query` for data; reuse top-movers where relevant.

Acceptance Criteria:
- SOC drilldown loads with default SOC list, sortable columns, and inline sparkline; data matches `/query`.
- NAICS drilldown shows layoffs/salary overviews; values match API.
- Comparison view supports selecting two entities (e.g., sector vs national) and renders correct series.

## Epic: Gemini Assist (Guardrailed)
**Goal:** AI summaries that are short, cited, and versioned.

Tasks:
- [ ] Tighten server-side prompt: “use provided numbers only, cite units, <=3 sentences, include release/version”.
- [ ] Context assembly: pass only current filters + top movers + key stats, not raw tables.
- [ ] UI buttons: “Explain this chart”, “3 manager prompts”; display version stamp with output.
- [ ] Error handling and rate limiting; handle missing key gracefully.

Acceptance Criteria:
- Prompt template enforced server-side; context limited to current filter + top movers/stats.
- Outputs ≤3 sentences, include version/release stamp, and cite provided numbers.
- UI buttons work; failure states show friendly error if key missing.

## Epic: Performance & Polish
**Goal:** Keep it fast, accessible, and resilient.

Tasks:
- [ ] Precompute caches for common queries; warm on startup.
- [ ] Pagination for heavy tables; limit payload sizes.
- [ ] Accessibility/contrast check; responsive layouts.
- [ ] Error/empty states with link to raw numbers.
- [ ] Export/copy summary includes version footer.
- [ ] Motion polish: staged load animation and parallax/tilt on feature panels; consistent hover states.
- [ ] Visual motif: commit to a single background motif (e.g., scanlines/oscilloscope or dotfield) applied consistently.
- [ ] Color discipline: primary teal, secondary electric blue, danger coral; warning amber only; avoid accent sprawl.

Acceptance Criteria:
- p95 API for common queries <1s locally; caches warmed.
- Large tables paginated; payload sizes capped.
- Basic a11y/contrast pass; mobile layout usable.
- Error/empty states present; exports include version/footer.

## Epic: Ops/Runbook
**Goal:** Repeatable setup and release.

Tasks:
- [ ] Scripts: `etl` (build DB), `serve` (API), `dev`/`build` (frontend).
- [ ] Optional container recipe for API + static front.
- [ ] Runbook: ingest new RPLS release → validate → deploy; include validation checklist.
- [ ] Decision log: schema choices, infra choice (DuckDB), prompt guardrails, versioning approach.

Acceptance Criteria:
- Scripts run end-to-end from clean clone to running app.
- Runbook documents ingest/validate/deploy with validation gates (row counts, dates, sample joins).
- Decision log exists with key choices and dates.

---

# Phased Plan (recap)
- Phase 1: ETL all CSVs → DuckDB + `/datasets`.
- Phase 2: `/search` + `/query` + `/top-movers` over DB.
- Phase 3: Core visuals (3 charts), banner, top-movers strip.
- Phase 4: SOC/NAICS depth + comparisons.
- Phase 5: Gemini assist with guardrails.
- Phase 6: Polish/perf; exports with version.
