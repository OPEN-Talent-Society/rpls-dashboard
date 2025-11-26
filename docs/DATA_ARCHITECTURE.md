# RPLS Dashboard - Data Architecture

## Overview

This document defines the data architecture for the Open Talent Society RPLS Dashboard platform, built on Revelio Labs Public Labor Statistics data.

---

## 1. Data Source Inventory

### Raw CSV Files (40+ files, ~580MB total)

| Category | Files | Rows | Granularity | Update Freq |
|----------|-------|------|-------------|-------------|
| **Employment** | 5 files | ~1M+ | National/Sector/Occupation/State | Monthly |
| **Salaries** | 5 files | ~1.5M | National/Sector/Occupation/State | Monthly |
| **Hiring & Attrition** | 5 files | ~1M+ | National/Sector/Occupation/State | Monthly |
| **Job Postings** | 4 files | ~925K | National/Sector/Occupation/State | Monthly |
| **Layoffs (WARN)** | 3 files | ~3.7K | National/Sector/State | Monthly |
| **Summaries** | 12 files | ~500 | Pre-aggregated | Monthly |

### Key Dimension Codes

**NAICS 2-digit Sectors (17 categories):**
```
11 - Agriculture, Forestry, Fishing and Hunting
21 - Mining, Quarrying, and Oil and Gas Extraction
22 - Utilities
23 - Construction
31-33 - Manufacturing
42 - Wholesale Trade
44-45 - Retail Trade
48-49 - Transportation and Warehousing
51 - Information
52-53 - Financial Activities
54-56 - Professional and Business Services
61-62 - Education and Health Services
71-72 - Leisure and Hospitality
81 - Other Services
92 - Government/Public Administration
99 - Unclassified
```

**SOC 2-digit Occupations (23 categories):**
```
11 - Management
13 - Business and Financial Operations
15 - Computer and Mathematical
17 - Architecture and Engineering
19 - Life, Physical, and Social Science
21 - Community and Social Service
23 - Legal
25 - Educational Instruction and Library
27 - Arts, Design, Entertainment, Sports, and Media
29 - Healthcare Practitioners and Technical
31 - Healthcare Support
33 - Protective Service
35 - Food Preparation and Serving Related
37 - Building and Grounds Cleaning and Maintenance
39 - Personal Care and Service
41 - Sales and Related
43 - Office and Administrative Support
45 - Farming, Fishing, and Forestry
47 - Construction and Extraction
49 - Installation, Maintenance, and Repair
51 - Production
53 - Transportation and Material Moving
```

**States:** 50 US states + DC + "empty/Unknown"

---

## 2. Data Schema Definitions

### Core Fact Tables

#### `fact_employment`
```typescript
interface EmploymentFact {
  month: string;              // "YYYY-MM" format
  naics2d_code?: string;      // Sector code
  naics2d_name?: string;      // Sector name
  soc2d_code?: string;        // Occupation code
  soc2d_name?: string;        // Occupation name
  state?: string;             // State name
  employment_nsa: number;     // Non-seasonally adjusted
  employment_sa: number;      // Seasonally adjusted
}
```

#### `fact_salaries`
```typescript
interface SalaryFact {
  month: string;
  naics2d_code?: string;
  naics2d_name?: string;
  soc2d_code?: string;
  soc2d_name?: string;
  state?: string;
  count: number;              // Number of postings
  salary_nsa: string;         // "$XX,XXX" format
  salary_sa: string;          // "$XX,XXX" format
}
```

#### `fact_hiring_attrition`
```typescript
interface HiringAttritionFact {
  month: string;
  naics2d_code?: string;
  naics2d_name?: string;
  soc2d_code?: string;
  soc2d_name?: string;
  state?: string;
  rl_hiring_rate_nsa: number;    // 0.0-1.0 (annualized)
  rl_attrition_rate_nsa: number;
  rl_hiring_rate: number;        // Seasonally adjusted
  rl_attrition_rate: number;
}
```

#### `fact_postings`
```typescript
interface PostingsFact {
  month: string;
  naics2d_code?: string;
  naics2d_name?: string;
  soc2d_code?: string;
  soc2d_name?: string;
  state?: string;
  active_postings_nsa: number;
  active_postings_sa: number;
}
```

#### `fact_layoffs`
```typescript
interface LayoffsFact {
  month: string;
  naics2d_code?: string;
  naics2d_name?: string;
  state?: string;
  num_employees_notified: number;
  num_notices_issued: number;
  num_employees_laidoff: number;
}
```

### Pre-Aggregated Summary Tables

#### `summary_sector`
```typescript
interface SectorSummary {
  sector: string;
  current_month: number;      // Postings count
  prev_month: number;
  prev_year: number;
  yoy_change: string;         // "+X.X%" or "-X.X%"
  mom_change: string;
}
```

#### `summary_occupation`
Same structure as sector summary.

#### `summary_state`
Same structure as sector summary.

---

## 3. Derived Metrics & Calculations

### Labor Market Health Index (0-100)
```typescript
function calculateHealthIndex(data: MonthlySnapshot): number {
  const weights = {
    employment_growth: 0.25,    // MoM employment change
    hiring_rate: 0.20,          // Higher = healthier
    attrition_rate: -0.15,      // Higher = less healthy (negative weight)
    job_postings_growth: 0.20,  // MoM postings change
    salary_growth: 0.10,        // MoM salary change
    layoff_inverse: 0.10        // Lower layoffs = healthier
  };

  // Normalize each metric to 0-100 scale
  // Apply weights
  // Return composite score
}
```

### Hiring Difficulty Score
```typescript
function calculateHiringDifficulty(sector: string, state: string): number {
  // High postings + Low hiring rate = Difficult
  // Low postings + High hiring rate = Easy
  const postingsRatio = postings[sector][state] / nationalAvg;
  const hiringRate = hiring[sector][state];

  return postingsRatio / hiringRate; // Higher = more difficult
}
```

### Churn Classification
```typescript
type ChurnCategory =
  | 'growth'      // High hiring, low attrition
  | 'churn_burn'  // High hiring, high attrition
  | 'stagnant'    // Low hiring, low attrition
  | 'decline';    // Low hiring, high attrition

function classifyChurn(hiringRate: number, attritionRate: number): ChurnCategory {
  const hiringThreshold = 0.28;  // ~28% annualized
  const attritionThreshold = 0.26;

  if (hiringRate > hiringThreshold && attritionRate < attritionThreshold) return 'growth';
  if (hiringRate > hiringThreshold && attritionRate > attritionThreshold) return 'churn_burn';
  if (hiringRate < hiringThreshold && attritionRate < attritionThreshold) return 'stagnant';
  return 'decline';
}
```

---

## 4. Data Processing Pipeline

### Monthly Update Flow
```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Revelio CSVs   │────▶│  ETL Pipeline   │────▶│  JSON/SQLite    │
│  (Raw Monthly)  │     │  (Transform)    │     │  (Processed)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  Gemini API     │
                        │  (Summaries)    │
                        └─────────────────┘
                                │
                                ▼
                        ┌─────────────────┐
                        │  Static JSON    │
                        │  (CDN Deploy)   │
                        └─────────────────┘
```

### ETL Script Pseudocode
```python
def process_monthly_data(csv_dir: str, output_dir: str):
    # 1. Load summary CSVs (small files)
    sector_summary = load_csv('sector_summary.csv')
    occupation_summary = load_csv('occupation_summary.csv')
    state_summary = load_csv('state_summary.csv')
    salary_overview = load_csv('salary_overview_*.csv')

    # 2. Load time-series for trends (medium files)
    employment_national = load_csv('employment_national.csv')
    hiring_total = load_csv('hiring_and_attrition_total_us.csv')
    postings_total = load_csv('postings_total_us.csv')
    layoffs_total = load_csv('total_layoffs.csv')

    # 3. Skip large granular files for MVP (1M+ rows)
    # Use only when user drills down

    # 4. Calculate derived metrics
    health_index = calculate_health_index(...)
    sector_classifications = classify_all_sectors(...)

    # 5. Generate Gemini summaries
    sector_narratives = gemini_summarize(sector_summary)

    # 6. Output to JSON
    write_json('dashboard_data.json', {
        'updated_at': datetime.now(),
        'health_index': health_index,
        'sectors': sector_summary,
        'occupations': occupation_summary,
        'states': state_summary,
        'trends': {
            'employment': employment_national,
            'hiring': hiring_total,
            'postings': postings_total,
            'layoffs': layoffs_total
        },
        'narratives': sector_narratives
    })
```

---

## 5. API Design

### Static JSON Endpoints (CDN-friendly)

```
/api/v1/
├── summary.json              # Dashboard overview
├── health-index.json         # Labor market score
├── sectors/
│   ├── index.json            # All sectors summary
│   └── {naics_code}.json     # Individual sector detail
├── occupations/
│   ├── index.json
│   └── {soc_code}.json
├── states/
│   ├── index.json
│   └── {state_code}.json
├── trends/
│   ├── employment.json       # Time series
│   ├── salaries.json
│   ├── hiring.json
│   └── layoffs.json
└── narratives/
    └── latest.json           # Gemini-generated summaries
```

### Example Response: `summary.json`
```json
{
  "updated_at": "2025-11-06T08:30:00Z",
  "data_month": "2025-10",
  "health_index": 62,
  "health_trend": "stable",
  "headline_metrics": {
    "employment_change": -9100,
    "job_postings": 16250679,
    "postings_change_pct": -1.9,
    "avg_salary": 71780,
    "salary_change_pct": 0.67,
    "hiring_rate": 0.248,
    "attrition_rate": 0.249
  },
  "top_growing_sectors": ["Education and Health Services"],
  "top_declining_sectors": ["Government", "Retail Trade"],
  "narrative": "The U.S. labor market showed flat growth in October..."
}
```

---

## 6. Component Data Requirements

### Salary Reality Check
**Inputs:** SOC code (occupation), State
**Data needed:** `salaries_soc.csv` (latest month only, 24 rows)
**Response time:** < 100ms (client-side lookup)

### Sector Spotlight Cards
**Data needed:** `sector_summary.csv` (18 rows)
**Enrichment:** Gemini narrative per sector
**Response time:** < 200ms (static JSON)

### Layoff Ticker
**Data needed:** `total_layoffs.csv` (latest 3 months)
**Data needed:** `layoffs_by_naics.csv` (for sector breakdown)
**Update:** Real-time feel via CSS animation

### Hiring vs Attrition Quadrant
**Data needed:** `hiring_and_attrition_by_sector.csv` (latest month, 17 rows)
**Visualization:** Scatter plot with 4 quadrants
**Labels:** Sector names as data points

### Labor Market Pulse Dashboard
**Combines all above** into single-page view
**Additional:** Time-series charts from `*_total_us.csv` files

---

## 7. Storage Strategy

### Phase 1: Static JSON (MVP)
- Pre-process CSVs to JSON monthly
- Host on Vercel/Netlify CDN
- Client-side data fetching
- **Pros:** Free, fast, simple
- **Cons:** No drill-down to granular data

### Phase 2: SQLite + JSON (Enhanced)
- SQLite for granular queries (state × sector × occupation)
- JSON for dashboard summaries
- Edge functions for complex queries
- **Pros:** Full drill-down capability
- **Cons:** Slightly more complex deployment

### Phase 3: PostgreSQL (SaaS)
- Full relational database
- User-contributed benchmarks
- Historical analysis
- **Pros:** Enterprise-ready
- **Cons:** Hosting costs

---

## 8. Gemini Integration Points

| Feature | Gemini Model | Prompt Type | Caching |
|---------|--------------|-------------|---------|
| Sector narratives | gemini-1.5-flash | Summarization | Monthly |
| Salary negotiation tips | gemini-1.5-pro | Advisory | On-demand |
| Trend explanations | gemini-1.5-flash | Analysis | Weekly |
| Newsletter generation | gemini-1.5-pro | Content creation | Weekly |
| Chat interface | gemini-1.5-pro | Conversational | Session |

### Example Prompt: Sector Narrative
```
You are a labor economist writing for HR professionals.

Given this data for {sector_name}:
- Job Postings: {postings} ({mom_change} MoM, {yoy_change} YoY)
- Hiring Rate: {hiring_rate}
- Attrition Rate: {attrition_rate}
- Avg Salary: {salary}

Write a 2-sentence summary explaining what this means for recruiters
and HR leaders. Be specific and actionable. Avoid jargon.
```

---

## 9. File Mapping Reference

| Component Need | Primary File | Backup File |
|----------------|--------------|-------------|
| National employment trend | `employment_national.csv` | `employment_national_history.csv` |
| Sector breakdown | `sector_summary.csv` | `employment_naics.csv` |
| Occupation breakdown | `occupation_summary.csv` | `employment_soc.csv` |
| State breakdown | `state_summary.csv` | `employment_state.csv` |
| Salaries by role | `salary_overview_soc.csv` | `salaries_soc.csv` |
| Salaries by industry | `salary_overview_naics.csv` | `salaries_naics.csv` |
| Salaries by state | `salary_overview_state.csv` | `salaries_state.csv` |
| Hiring/attrition rates | `hiring_and_attrition_total_us.csv` | `hiring_*_summary.csv` |
| Layoff data | `total_layoffs.csv` | `layoffs_by_*.csv` |
| Job postings | `postings_total_us.csv` | `postings_by_*.csv` |

---

## 10. Data Freshness & SLA

| Metric | Source Update | Our Update | Staleness Tolerance |
|--------|---------------|------------|---------------------|
| Employment | 1st Thursday/month | Same day | 1 week |
| Salaries | 1st Thursday/month | Same day | 1 week |
| Hiring rates | 1st Thursday/month | Same day | 1 week |
| Layoffs | Weekly | Weekly | 1 week |
| Gemini narratives | N/A | Monthly | 1 month |

---

*Last updated: 2025-11-22*
*Version: 1.0.0*
