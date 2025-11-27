# RPLS Dashboard - Technical Specifications

## Tech Stack Decision

Current implementation: **FastAPI (DuckDB) + React/Vite + Tailwind** for local/on-prem. Earlier Svelte sketches remain in the repo; React is the active frontend.

### Recommended Stack (for hosted): **SvelteKit + Tailwind + Vercel**

| Layer | Technology | Rationale |
|-------|------------|-----------|
| Framework | SvelteKit | Fast, lightweight, great DX, SSG support |
| Styling | Tailwind CSS | Rapid prototyping, consistent design |
| Charts | Chart.js / Recharts | Simple, accessible, well-documented |
| Maps | Leaflet.js | Free, lightweight, US state choropleth |
| AI | Gemini API | Native integration, cost-effective |
| Hosting | Vercel | Free tier, edge functions, CDN |
| Data | Static JSON | No backend needed for MVP |

### Alternative: Next.js (if React preferred)
- Heavier but more ecosystem support
- Better if integrating with existing JD Auditor (React-based)

---

## Component 1: Salary Reality Check Calculator

### Purpose
Users input occupation + state, get instant salary benchmark from RPLS data.

### User Flow
```
┌─────────────────────────────────────────────────────────┐
│  💰 Salary Reality Check                                │
├─────────────────────────────────────────────────────────┤
│  What's your role?                                      │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [Dropdown: Select Occupation]            ▼      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  Where do you work?                                     │
│  ┌─────────────────────────────────────────────────┐   │
│  │ [Dropdown: Select State]                 ▼      │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [  Check Market Rate  ]                               │
├─────────────────────────────────────────────────────────┤
│  📊 RESULTS                                             │
│                                                         │
│  Computer and Mathematical in California                │
│                                                         │
│  Market Salary: $108,500                               │
│  ████████████████████░░░░ 75th percentile              │
│                                                         │
│  💡 Gemini Tip: "Tech salaries in CA are cooling.      │
│     Consider negotiating remote flexibility instead     │
│     of higher base."                                    │
│                                                         │
│  [Share] [Compare Another]                              │
└─────────────────────────────────────────────────────────┘
```

### Data Requirements
```typescript
// Source: salaries_soc.csv + salaries_state.csv (latest month)
interface SalaryLookup {
  occupation: {
    code: string;      // "15"
    name: string;      // "Computer and Mathematical"
    salary: number;    // 108500
  };
  state: {
    name: string;      // "California"
    salary: number;    // 72093
    adjustment: number; // 1.15 (15% above national avg)
  };
  combined_estimate: number;  // occupation_salary * state_adjustment
}
```

### Component Structure
```
src/components/SalaryCheck/
├── SalaryCheck.svelte        # Main container
├── OccupationSelect.svelte   # Dropdown with SOC codes
├── StateSelect.svelte        # Dropdown with US states
├── SalaryResult.svelte       # Display card with bar
├── GeminiTip.svelte          # AI-generated advice
└── salary-data.json          # Pre-processed lookup table
```

### API Calls
```typescript
// No runtime API needed - all client-side
// Pre-generate salary-data.json from CSVs

// Optional: Gemini API for tips
async function getSalaryTip(occupation: string, state: string, salary: number) {
  const response = await fetch('/api/gemini/salary-tip', {
    method: 'POST',
    body: JSON.stringify({ occupation, state, salary })
  });
  return response.json();
}
```

### Gemini Prompt (Salary Tips)
```
Role: You are a career coach specializing in compensation.

Context:
- Occupation: {occupation}
- State: {state}
- Current market salary: ${salary}
- YoY salary change: {yoy_change}%
- Hiring rate in this field: {hiring_rate}%

Task: Write a 1-2 sentence negotiation tip. Be specific to this
role and location. If hiring is slow, suggest non-salary benefits.
If salaries are rising, encourage asking for more.

Keep it under 30 words. Be actionable.
```

### Estimated Effort: 2-3 days

---

## Component 2: Sector Spotlight Cards

### Purpose
Visual "Winners & Losers" cards showing sector performance at a glance.

### User Flow
```
┌─────────────────────────────────────────────────────────┐
│  📈 Sector Spotlight - October 2025                     │
├─────────────────────────────────────────────────────────┤
│  🏆 TOP PERFORMERS                                      │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ Education &      │  │ Financial        │            │
│  │ Health Services  │  │ Activities       │            │
│  │                  │  │                  │            │
│  │ +22,000 jobs     │  │ +9,600 jobs      │            │
│  │ ▲ 3.0% postings  │  │ ▼ 2.3% postings  │            │
│  │                  │  │                  │            │
│  │ "Healthcare      │  │ "Banks are       │            │
│  │ hiring boom..."  │  │ consolidating.." │            │
│  └──────────────────┘  └──────────────────┘            │
│                                                         │
│  📉 COOLING DOWN                                        │
│  ┌──────────────────┐  ┌──────────────────┐            │
│  │ Government       │  │ Retail Trade     │            │
│  │                  │  │                  │            │
│  │ -22,200 jobs     │  │ -8,500 jobs      │            │
│  │ ▼ 23.1% YoY      │  │ ▼ 22.0% YoY      │            │
│  │                  │  │                  │            │
│  │ "Federal hiring  │  │ "Holiday surge   │            │
│  │ freeze impact.." │  │ not happening.." │            │
│  └──────────────────┘  └──────────────────┘            │
│                                                         │
│  [View All 17 Sectors →]                               │
└─────────────────────────────────────────────────────────┘
```

### Data Requirements
```typescript
// Source: sector_summary.csv + employment change calculation
interface SectorCard {
  name: string;
  naics_code: string;
  metrics: {
    postings_current: number;
    postings_mom_change: string;  // "-1.9%"
    postings_yoy_change: string;  // "-18.0%"
    employment_change?: number;    // From employment_naics.csv
  };
  classification: 'growing' | 'stable' | 'declining';
  narrative: string;  // Gemini-generated
}
```

### Component Structure
```
src/components/SectorSpotlight/
├── SectorSpotlight.svelte    # Container with tabs
├── SectorCard.svelte         # Individual card
├── SectorGrid.svelte         # Layout grid
├── TrendIndicator.svelte     # ▲/▼ arrows with color
└── sector-data.json          # Pre-processed with narratives
```

### Gemini Prompt (Sector Narrative)
```
Role: Labor market analyst writing for HR professionals.

Data for {sector_name}:
- Job postings: {postings} ({mom_change} vs last month)
- YoY change: {yoy_change}
- Employment change: {employment_change} jobs

Write ONE sentence (max 15 words) explaining what's happening
in this sector. Use plain language. Be specific about cause
if obvious (e.g., "seasonal", "federal cuts", "AI impact").
```

### Estimated Effort: 2 days

---

## Component 3: Layoff Ticker / Alert System

### Purpose
Real-time scrolling ticker of WARN notices + email subscription for sector alerts.

### User Flow
```
┌─────────────────────────────────────────────────────────┐
│  ⚠️ LAYOFF WATCH                                        │
│  ═══════════════════════════════════════════════════   │
│  ← Manufacturing: 5,200 notified | Tech: 2,100 laid   │
│    off | Government: 22,200 jobs cut | Healthcare:    │
│    +22,000 (hiring!) | Total Oct: 43,626 notices →    │
│  ═══════════════════════════════════════════════════   │
│                                                         │
│  🔔 Get Alerts                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Email: [                    ] [Subscribe]       │   │
│  │                                                 │   │
│  │ Alert me when:                                  │   │
│  │ ☑ My sector has >10% layoff increase           │   │
│  │ ☐ Any sector has mass layoff event             │   │
│  │ ☑ Weekly digest of all WARN notices            │   │
│  │                                                 │   │
│  │ My sector: [Healthcare           ▼]            │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### Data Requirements
```typescript
// Source: total_layoffs.csv + layoffs_by_naics.csv
interface LayoffTicker {
  month: string;
  total_notified: number;
  total_laid_off: number;
  by_sector: {
    sector: string;
    notified: number;
    laid_off: number;
    change_vs_last_month: string;
  }[];
  alerts: {
    type: 'surge' | 'decline' | 'mass_event';
    sector: string;
    message: string;
  }[];
}
```

### Component Structure
```
src/components/LayoffTicker/
├── LayoffTicker.svelte       # Scrolling ticker
├── AlertSignup.svelte        # Email subscription form
├── SectorFilter.svelte       # Sector preference dropdown
├── TickerItem.svelte         # Individual ticker segment
└── layoff-data.json          # Current month data
```

### Animation CSS
```css
.ticker-wrapper {
  overflow: hidden;
  white-space: nowrap;
}

.ticker-content {
  display: inline-block;
  animation: scroll-left 30s linear infinite;
}

@keyframes scroll-left {
  0% { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}

.ticker-content:hover {
  animation-play-state: paused;
}
```

### Email Integration (Optional)
- Use Buttondown, ConvertKit, or Mailchimp API
- Webhook triggers when new layoff data processed
- Segment by sector preference

### Estimated Effort: 2-3 days (ticker only), +2 days (email alerts)

---

## Component 4: Hiring vs Attrition Quadrant

### Purpose
Scatter plot visualization showing sector "personality" based on dynamism.

### User Flow
```
┌─────────────────────────────────────────────────────────┐
│  🔄 Market Dynamism Quadrant                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  High                                                   │
│  Attrition  ┌─────────────────┬─────────────────┐      │
│     ▲       │   CHURN & BURN  │    GROWTH       │      │
│     │       │                 │                 │      │
│     │       │  • Hospitality  │  • Healthcare   │      │
│     │       │  • Retail       │  • Education    │      │
│     │       │                 │                 │      │
│     │       ├─────────────────┼─────────────────┤      │
│     │       │   DECLINE       │    STAGNANT     │      │
│     │       │                 │                 │      │
│     │       │  • Government   │  • Utilities    │      │
│     │       │  • Mining       │  • Finance      │      │
│     │       │                 │                 │      │
│     │       └─────────────────┴─────────────────┘      │
│     └──────────────────────────────────────────▶       │
│  Low                                        High       │
│  Attrition                              Hiring Rate    │
│                                                         │
│  💡 Click any sector dot for details                   │
│                                                         │
│  Legend: ● Growing  ○ Declining  Size = Employment    │
└─────────────────────────────────────────────────────────┘
```

### Data Requirements
```typescript
// Source: hiring_and_attrition_by_sector.csv (latest month)
interface QuadrantPoint {
  sector: string;
  naics_code: string;
  hiring_rate: number;      // X-axis (0.0-0.5)
  attrition_rate: number;   // Y-axis (0.0-0.5)
  employment: number;       // Bubble size
  quadrant: 'growth' | 'churn_burn' | 'stagnant' | 'decline';
  color: string;            // Based on quadrant
}
```

### Component Structure
```
src/components/Quadrant/
├── QuadrantChart.svelte      # Main scatter plot
├── QuadrantLegend.svelte     # Quadrant labels
├── SectorTooltip.svelte      # Hover details
├── quadrant-utils.ts         # Classification logic
└── quadrant-data.json        # Pre-calculated positions
```

### Chart.js Configuration
```typescript
const quadrantConfig = {
  type: 'scatter',
  data: {
    datasets: [{
      label: 'Sectors',
      data: sectors.map(s => ({
        x: s.hiring_rate,
        y: s.attrition_rate,
        r: Math.sqrt(s.employment) / 1000, // Bubble size
        label: s.sector
      })),
      backgroundColor: sectors.map(s => quadrantColor(s.quadrant))
    }]
  },
  options: {
    scales: {
      x: { min: 0.15, max: 0.40, title: { text: 'Hiring Rate' } },
      y: { min: 0.15, max: 0.35, title: { text: 'Attrition Rate' } }
    },
    plugins: {
      annotation: {
        annotations: {
          verticalLine: { type: 'line', xMin: 0.27, xMax: 0.27 },
          horizontalLine: { type: 'line', yMin: 0.26, yMax: 0.26 }
        }
      }
    }
  }
};
```

### Quadrant Classification Logic
```typescript
function classifyQuadrant(hiring: number, attrition: number): string {
  const H_THRESH = 0.27;  // National avg hiring rate
  const A_THRESH = 0.26;  // National avg attrition rate

  if (hiring >= H_THRESH && attrition < A_THRESH) return 'growth';
  if (hiring >= H_THRESH && attrition >= A_THRESH) return 'churn_burn';
  if (hiring < H_THRESH && attrition < A_THRESH) return 'stagnant';
  return 'decline';
}
```

### Estimated Effort: 2-3 days

---

## Component 5: Labor Market Pulse Dashboard

### Purpose
Unified landing page combining all components into cohesive experience.

### User Flow
```
┌─────────────────────────────────────────────────────────────┐
│  OPEN TALENT SOCIETY                                        │
│  Labor Market Pulse                         October 2025    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  MARKET HEALTH INDEX                                │   │
│  │                                                     │   │
│  │       ████████████████░░░░░░░░  62/100             │   │
│  │       STABLE (▼ 2 pts from Sep)                    │   │
│  │                                                     │   │
│  │  "The labor market is cooling but stable. Hiring   │   │
│  │   has slowed across most sectors except healthcare.│   │
│  │   Government cuts drove October's -9.1K jobs."     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  ⚠️ LAYOFF TICKER ←←← scrolling... →→→             │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌──────────────────────┐  ┌──────────────────────────┐   │
│  │ KEY METRICS          │  │ SECTOR SPOTLIGHT         │   │
│  │                      │  │                          │   │
│  │ Employment: -9.1K    │  │ 🏆 Healthcare +22K       │   │
│  │ Postings:   16.2M    │  │ 📉 Government -22K       │   │
│  │ Avg Salary: $71,780  │  │ 📉 Retail -8.5K          │   │
│  │ Hiring:     24.8%    │  │                          │   │
│  │ Attrition:  24.9%    │  │ [View All →]             │   │
│  └──────────────────────┘  └──────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ HIRING VS ATTRITION QUADRANT                        │   │
│  │                                                     │   │
│  │              [Scatter Plot Here]                   │   │
│  │                                                     │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 💰 SALARY REALITY CHECK                             │   │
│  │                                                     │   │
│  │  [Select Occupation ▼] [Select State ▼] [Check]   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ─────────────────────────────────────────────────────────  │
│  Data: Revelio Labs RPLS | Updated: Nov 6, 2025           │
│  Built by Open Talent Society | CC BY-SA 4.0              │
└─────────────────────────────────────────────────────────────┘
```

### Page Structure
```
src/routes/
├── +page.svelte              # Dashboard landing
├── +layout.svelte            # Global layout
├── salary/+page.svelte       # Standalone salary tool
├── sectors/+page.svelte      # Full sector list
├── states/+page.svelte       # State-by-state view
└── about/+page.svelte        # Methodology & credits
```

### Component Composition
```svelte
<!-- +page.svelte -->
<script>
  import HealthIndex from '$lib/components/HealthIndex.svelte';
  import LayoffTicker from '$lib/components/LayoffTicker.svelte';
  import KeyMetrics from '$lib/components/KeyMetrics.svelte';
  import SectorSpotlight from '$lib/components/SectorSpotlight.svelte';
  import QuadrantChart from '$lib/components/QuadrantChart.svelte';
  import SalaryCheck from '$lib/components/SalaryCheck.svelte';

  export let data; // From +page.ts load function
</script>

<main class="max-w-6xl mx-auto p-4">
  <header class="mb-8">
    <h1>Labor Market Pulse</h1>
    <p class="text-gray-500">October 2025</p>
  </header>

  <HealthIndex score={data.healthIndex} trend={data.healthTrend} />

  <LayoffTicker items={data.layoffs} />

  <div class="grid md:grid-cols-2 gap-4 my-8">
    <KeyMetrics metrics={data.metrics} />
    <SectorSpotlight sectors={data.topSectors} />
  </div>

  <QuadrantChart data={data.quadrant} />

  <SalaryCheck occupations={data.occupations} states={data.states} />

  <footer class="mt-12 text-center text-sm text-gray-400">
    Data: Revelio Labs RPLS | Updated: {data.updatedAt}
  </footer>
</main>
```

### Estimated Effort: 3-4 days (assembly + styling)

---

## Shared Infrastructure

### Data Loading Pattern
```typescript
// src/lib/data/loader.ts
import summaryData from '$lib/data/summary.json';
import sectorData from '$lib/data/sectors.json';
import salaryData from '$lib/data/salaries.json';

export function loadDashboardData() {
  return {
    metrics: summaryData.headline_metrics,
    healthIndex: summaryData.health_index,
    healthTrend: summaryData.health_trend,
    topSectors: sectorData.slice(0, 4),
    layoffs: summaryData.layoff_ticker,
    quadrant: sectorData.map(s => ({
      sector: s.name,
      hiring: s.hiring_rate,
      attrition: s.attrition_rate
    })),
    occupations: salaryData.occupations,
    states: salaryData.states,
    updatedAt: summaryData.updated_at
  };
}
```

### Gemini API Route
```typescript
// src/routes/api/gemini/+server.ts
import { GEMINI_API_KEY } from '$env/static/private';
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

export async function POST({ request }) {
  const { prompt, type } = await request.json();

  const model = genAI.getGenerativeModel({
    model: type === 'complex' ? 'gemini-1.5-pro' : 'gemini-1.5-flash'
  });

  const result = await model.generateContent(prompt);
  return Response.json({ text: result.response.text() });
}
```

### Pre-processing Script
```python
# scripts/process_rpls.py
import pandas as pd
import json
from pathlib import Path

DATA_DIR = Path('../revelio-data')
OUTPUT_DIR = Path('../src/lib/data')

def process_all():
    # 1. Summary metrics
    summary = {
        'updated_at': '2025-11-06',
        'data_month': '2025-10',
        'health_index': calculate_health_index(),
        'headline_metrics': get_headline_metrics(),
        'layoff_ticker': get_layoff_ticker()
    }
    write_json('summary.json', summary)

    # 2. Sector data
    sectors = process_sectors()
    write_json('sectors.json', sectors)

    # 3. Salary lookup
    salaries = process_salaries()
    write_json('salaries.json', salaries)

if __name__ == '__main__':
    process_all()
```

---

## Total Estimated Effort

| Component | Days | Dependencies |
|-----------|------|--------------|
| Data Architecture | ✅ Done | - |
| Technical Specs | ✅ Done | - |
| Pre-processing Script | 1 | Python, CSVs |
| Salary Reality Check | 2-3 | Pre-processing |
| Sector Spotlight | 2 | Pre-processing |
| Layoff Ticker | 2 | Pre-processing |
| Quadrant Chart | 2-3 | Pre-processing |
| Dashboard Assembly | 3-4 | All components |
| Gemini Integration | 2 | API key |
| Polish & Testing | 2 | All |
| **TOTAL** | **16-19 days** | |

### Recommended Sprint Plan

**Week 1:**
- Day 1-2: Pre-processing script + JSON generation
- Day 3-4: Salary Reality Check
- Day 5: Sector Spotlight Cards

**Week 2:**
- Day 1-2: Layoff Ticker
- Day 3-4: Quadrant Chart
- Day 5: Dashboard assembly

**Week 3:**
- Day 1-2: Gemini integration
- Day 3-4: Polish, testing, documentation
- Day 5: Deploy to Vercel

---

*Last updated: 2025-11-22*
*Version: 1.0.0*
