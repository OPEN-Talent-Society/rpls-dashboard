#!/usr/bin/env python3
"""
RPLS Dashboard Data Processor
Converts Revelio Labs CSV files to static JSON for the dashboard.
"""

import csv
import json
import os
from datetime import datetime
from pathlib import Path
from typing import Iterable, List, Optional

# Paths (prefers canonical rpls_data; fallback to env override)
ROOT_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = Path(os.environ.get("RPLS_DATA_DIR", ROOT_DIR.parent / "rpls_data"))
OUTPUT_DIR = ROOT_DIR / "static" / "data"

def load_csv(filename):
    """Load CSV file and return list of dicts."""
    filepath = DATA_DIR / filename
    if not filepath.exists():
        raise FileNotFoundError(f"{filename} not found in {DATA_DIR}")

    with open(filepath, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        return list(reader)

def parse_currency(val):
    """Convert $XX,XXX string to float."""
    if not val:
        return None
    return float(val.replace('$', '').replace(',', ''))

def parse_percent(val):
    """Convert +X.X% or -X.X% to float."""
    if not val:
        return None
    return float(val.replace('%', '').replace('+', ''))


def _parse_month_key(key: str):
    for fmt in ("%B %Y", "%b %Y"):
        try:
            return datetime.strptime(key, fmt)
        except ValueError:
            continue
    return None


def latest_month_column(keys: Iterable[str]) -> Optional[str]:
    """Return the column name representing the latest month among the provided keys."""
    dated_keys: List[tuple[datetime, str]] = []
    for key in keys:
        parsed = _parse_month_key(key)
        if parsed:
            dated_keys.append((parsed, key))
    if not dated_keys:
        return None
    dated_keys.sort(key=lambda tup: tup[0])
    return dated_keys[-1][1]

def process_sector_summary():
    """Process sector summary data for Sector Spotlight Cards."""
    rows = load_csv("sector_summary.csv")
    sectors = []

    if not rows:
        return sectors

    month_cols = [c for c in rows[0].keys() if _parse_month_key(c)]
    month_cols.sort(key=lambda c: _parse_month_key(c))
    latest_col = month_cols[-1]
    prev_col = month_cols[-2] if len(month_cols) > 1 else month_cols[-1]
    yoy_col = next((c for c in rows[0].keys() if "YoY" in c), None)
    mom_col = next((c for c in rows[0].keys() if "MoM" in c), None)

    for row in rows:
        if row.get('Sector') == 'Total US':
            continue

        current = int(row.get(latest_col, '0').replace(',', '') or 0)
        prev = int(row.get(prev_col, '0').replace(',', '') or 0)
        yoy = parse_percent(row.get(yoy_col, '0%')) if yoy_col else None
        mom = parse_percent(row.get(mom_col, '0%')) if mom_col else None

        sectors.append({
            "name": row.get('Sector', ''),
            "current_postings": current,
            "prev_month_postings": prev,
            "yoy_change": yoy if yoy is not None else ((current - prev) / prev * 100 if prev else None),
            "mom_change": mom if mom is not None else None
        })

    return sorted(sectors, key=lambda x: x['current_postings'], reverse=True)

def process_salary_by_occupation():
    """Process salary data by occupation for Salary Reality Check."""
    rows = load_csv("salary_overview_soc.csv")
    salaries = []

    if not rows:
        return salaries

    month_cols = [c for c in rows[0].keys() if _parse_month_key(c)]
    month_cols.sort(key=lambda c: _parse_month_key(c))
    latest_col = month_cols[-1]
    prev_col = month_cols[-2] if len(month_cols) > 1 else month_cols[-1]
    yoy_col = next((c for c in rows[0].keys() if "Pct change YoY" in c), None)

    for row in rows:
        soc_code = row.get('soc2d_code', '')
        if soc_code == 'Total US' or not soc_code:
            continue

        salaries.append({
            "code": soc_code,
            "name": row.get('soc2d_name', ''),
            "salary": parse_currency(row.get(latest_col, '$0')),
            "prev_year_salary": parse_currency(row.get(prev_col, '$0')),
            "yoy_change": float(row.get(yoy_col, '0') or 0) if yoy_col else None
        })

    return salaries

def process_salary_by_state():
    """Process salary data by state."""
    rows = load_csv("salary_overview_state.csv")
    salaries = {}
    national_avg = 0.0

    if not rows:
        return salaries, national_avg

    month_cols = [c for c in rows[0].keys() if _parse_month_key(c)]
    month_cols.sort(key=lambda c: _parse_month_key(c))
    latest_col = month_cols[-1]
    yoy_col = next((c for c in rows[0].keys() if "Pct change YoY" in c), None)

    for row in rows:
        state = row.get('state', '')
        if not state:
            continue
            
        salary_val = parse_currency(row.get(latest_col, '$0'))
        
        if state == 'Total US':
            national_avg = salary_val or 0.0
            continue

        salaries[state] = {
            "salary": salary_val,
            "yoy_change": float(row.get(yoy_col, '0') or 0) if yoy_col else None
        }

    return salaries, national_avg

def process_hiring_attrition():
    """Process hiring and attrition by sector for Quadrant chart."""
    rows = load_csv("hiring_and_attrition_by_sector.csv")

    # Get latest month data
    latest_data = {}
    for row in rows:
        month = row.get('month', '')
        naics_code = row.get('naics2d_code', '')
        naics_name = row.get('naics2d_name', '')

        if naics_code == '00':  # Skip Unknown
            continue

        if month not in latest_data:
            latest_data[month] = []

        latest_data[month].append({
            "code": naics_code,
            "name": naics_name,
            "hiring_rate": float(row.get('rl_hiring_rate', '0') or 0),
            "attrition_rate": float(row.get('rl_attrition_rate', '0') or 0)
        })

    # Get most recent month
    if latest_data:
        latest_month = max(latest_data.keys())
        return {
            "month": latest_month,
            "sectors": latest_data[latest_month]
        }
    return {"month": "", "sectors": []}

def process_layoffs():
    """Process layoff data for Layoff Ticker."""
    rows = load_csv("total_layoffs.csv")
    layoffs = []

    for row in rows:
        month = row.get('month', '')
        notified = row.get('num_employees_notified', '')
        notices = row.get('num_notices_issued', '')
        laidoff = row.get('num_employees_laidoff', '')

        layoffs.append({
            "month": month,
            "employees_notified": int(float(notified)) if notified else None,
            "notices_issued": int(float(notices)) if notices else None,
            "employees_laidoff": int(float(laidoff)) if laidoff else None
        })

    return sorted(layoffs, key=lambda x: x['month'], reverse=True)

def process_layoffs_by_sector():
    """Process layoffs by sector."""
    rows = load_csv("layoffs_by_naics.csv")

    # Group by month
    by_month = {}
    for row in rows:
        month = row.get('month', '')
        if month not in by_month:
            by_month[month] = []

        by_month[month].append({
            "code": row.get('naics2d_code', ''),
            "name": row.get('naics2d_name', ''),
            "employees_laidoff": int(float(row.get('num_employees_laidoff', '0') or 0))
        })

    # Return latest month
    if by_month:
        latest_month = max(by_month.keys())
        return {
            "month": latest_month,
            "sectors": sorted(by_month[latest_month], key=lambda x: x['employees_laidoff'], reverse=True)
        }
    return {"month": "", "sectors": []}

def process_employment_trends():
    """Process national employment trends."""
    rows = load_csv("employment_national.csv")
    trends = []

    for row in rows:
        trends.append({
            "month": row.get('month', ''),
            "employment_nsa": int(float(row.get('employment_nsa', '0') or 0)),
            "employment_sa": int(float(row.get('employment_sa', '0') or 0))
        })

    return sorted(trends, key=lambda x: x['month'])

def process_hiring_trends():
    """Process national hiring/attrition trends."""
    rows = load_csv("hiring_and_attrition_total_us.csv")
    trends = []

    for row in rows:
        trends.append({
            "month": row.get('month', ''),
            "hiring_rate": float(row.get('rl_hiring_rate', '0') or 0),
            "attrition_rate": float(row.get('rl_attrition_rate', '0') or 0)
        })

    return sorted(trends, key=lambda x: x['month'])

def calculate_health_index(employment_trends, hiring_trends, layoffs):
    """Calculate Labor Market Health Index (0-100)."""
    if not employment_trends or not hiring_trends or not layoffs:
        return 50  # Default neutral

    # Get latest data
    latest_emp = employment_trends[-1] if employment_trends else {}
    prev_emp = employment_trends[-2] if len(employment_trends) > 1 else latest_emp
    latest_hiring = hiring_trends[-1] if hiring_trends else {}
    latest_layoffs = layoffs[0] if layoffs else {}
    prev_layoffs = layoffs[1] if len(layoffs) > 1 else latest_layoffs

    # Calculate component scores (0-100 each)
    scores = []

    # Employment growth (positive = good)
    if prev_emp.get('employment_sa'):
        emp_growth = (latest_emp.get('employment_sa', 0) - prev_emp['employment_sa']) / prev_emp['employment_sa']
        emp_score = 50 + (emp_growth * 10000)  # Scale to reasonable range
        scores.append(('employment', max(0, min(100, emp_score)), 0.25))

    # Hiring rate (higher = better, typical range 0.2-0.4)
    hiring_rate = latest_hiring.get('hiring_rate', 0.25)
    hiring_score = (hiring_rate - 0.15) / 0.25 * 100
    scores.append(('hiring', max(0, min(100, hiring_score)), 0.25))

    # Attrition rate (lower = better, typical range 0.2-0.4)
    attrition_rate = latest_hiring.get('attrition_rate', 0.25)
    attrition_score = 100 - ((attrition_rate - 0.15) / 0.25 * 100)
    scores.append(('attrition', max(0, min(100, attrition_score)), 0.20))

    # Net hiring (hiring - attrition, positive = good)
    net_hiring = hiring_rate - attrition_rate
    net_score = 50 + (net_hiring * 500)
    scores.append(('net_hiring', max(0, min(100, net_score)), 0.15))

    # Layoffs trend (decreasing = good)
    curr_layoffs = latest_layoffs.get('employees_laidoff') or 0
    prev_layoffs_val = prev_layoffs.get('employees_laidoff') or curr_layoffs
    if prev_layoffs_val > 0:
        layoff_change = (curr_layoffs - prev_layoffs_val) / prev_layoffs_val
        layoff_score = 50 - (layoff_change * 100)
        scores.append(('layoffs', max(0, min(100, layoff_score)), 0.15))

    # Weighted average
    if scores:
        weighted_sum = sum(score * weight for _, score, weight in scores)
        total_weight = sum(weight for _, _, weight in scores)
        return round(weighted_sum / total_weight)

    return 50

def classify_sector_quadrant(hiring_rate, attrition_rate):
    """Classify sector into quadrant based on hiring/attrition."""
    hiring_threshold = 0.28
    attrition_threshold = 0.26

    if hiring_rate > hiring_threshold:
        if attrition_rate < attrition_threshold:
            return "growth"
        else:
            return "churn_burn"
    else:
        if attrition_rate < attrition_threshold:
            return "stagnant"
        else:
            return "decline"

def main():
    """Main processing function."""
    print("Processing RPLS data...")

    # Create output directory
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Process all data
    sectors = process_sector_summary()
    salaries_soc = process_salary_by_occupation()
    salaries_state, national_avg_salary = process_salary_by_state()
    hiring_attrition = process_hiring_attrition()
    layoffs = process_layoffs()
    layoffs_by_sector = process_layoffs_by_sector()
    employment_trends = process_employment_trends()
    hiring_trends = process_hiring_trends()

    # Add quadrant classification to hiring/attrition data
    for sector in hiring_attrition.get('sectors', []):
        sector['quadrant'] = classify_sector_quadrant(
            sector['hiring_rate'],
            sector['attrition_rate']
        )

    # Calculate health index
    health_index = calculate_health_index(employment_trends, hiring_trends, layoffs)

    # Get latest data for summary
    latest_layoff = layoffs[0] if layoffs else {}
    latest_hiring = hiring_trends[-1] if hiring_trends else {}
    latest_emp = employment_trends[-1] if employment_trends else {}
    prev_emp = employment_trends[-2] if len(employment_trends) > 1 else {}

    # Determine health trend
    if len(employment_trends) >= 3:
        recent_growth = (latest_emp.get('employment_sa', 0) - prev_emp.get('employment_sa', 0))
        if recent_growth > 50000:
            health_trend = "improving"
        elif recent_growth < -50000:
            health_trend = "declining"
        else:
            health_trend = "stable"
    else:
        health_trend = "stable"

    # Build summary
    summary = {
        "updated_at": datetime.now().isoformat(),
        "data_month": latest_emp.get('month') or latest_hiring.get('month') or "",
        "health_index": health_index,
        "health_trend": health_trend,
        "headline_metrics": {
            "total_employment": latest_emp.get('employment_sa'),
            "employment_change": (latest_emp.get('employment_sa', 0) - prev_emp.get('employment_sa', 0)) if prev_emp else 0,
            "hiring_rate": latest_hiring.get('hiring_rate'),
            "attrition_rate": latest_hiring.get('attrition_rate'),
            "average_salary": national_avg_salary,
            "latest_layoffs": latest_layoff.get('employees_laidoff'),
            "total_sectors": len(sectors),
            "total_occupations": len(salaries_soc)
        },
        "top_sectors_by_postings": sectors[:5],
        "recent_layoffs": layoffs[:3]
    }

    # Write JSON files
    files_to_write = {
        "summary.json": summary,
        "sectors.json": sectors,
        "salaries_by_occupation.json": salaries_soc,
        "salaries_by_state.json": salaries_state,
        "hiring_attrition.json": hiring_attrition,
        "layoffs.json": layoffs,
        "layoffs_by_sector.json": layoffs_by_sector,
        "employment_trends.json": employment_trends,
        "hiring_trends.json": hiring_trends
    }

    for filename, data in files_to_write.items():
        filepath = OUTPUT_DIR / filename
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)
        print(f"  Wrote {filename}")

    print(f"\nHealth Index: {health_index}/100 ({health_trend})")
    print(f"Data files written to: {OUTPUT_DIR}")
    print("Done!")

if __name__ == "__main__":
    main()
