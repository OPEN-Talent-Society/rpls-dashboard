import os
from pathlib import Path
from typing import Dict, List, Optional

import duckdb
import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Load environment variables early
load_dotenv()

DB_PATH = Path(os.getenv("DB_PATH", Path(__file__).resolve().parent / "rpls.duckdb"))
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
GEMINI_ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
)

MONEY_COLS = {"salary_sa", "salary_nsa"}

NAICS_NAMES: Dict[str, str] = {
    "00": "Total US",
    "11": "Agriculture, Forestry, Fishing and Hunting",
    "21": "Mining, Quarrying, and Oil and Gas Extraction",
    "22": "Utilities",
    "23": "Construction",
    "31-33": "Manufacturing",
    "42": "Wholesale Trade",
    "44-45": "Retail Trade",
    "48-49": "Transportation and Warehousing",
    "51": "Information",
    "52-53": "Finance, Insurance, Real Estate, and Leasing",
    "54-56": "Professional and Business Services",
    "61-62": "Education and Health Services",
    "71-72": "Leisure and Hospitality",
    "81": "Other Services",
    "92": "Government",
    "99": "Unclassified",
}

app = FastAPI(title="RPLS Dashboard API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class QueryRequest(BaseModel):
    dimension_type: str
    id: Optional[str] = None
    metric: str
    sa: bool = True
    limit_months: Optional[int] = None


def ensure_db_exists():
    if not DB_PATH.exists():
        raise HTTPException(status_code=500, detail=f"DB not found at {DB_PATH}. Run etl.py")


def get_con():
    """Open a short-lived read-only DuckDB connection with single-threaded execution."""
    ensure_db_exists()
    return duckdb.connect(str(DB_PATH), read_only=True, config={"threads": 1})


def value_expr(col_expr: str) -> str:
    base = col_expr.split(".")[-1]
    if base in MONEY_COLS:
        return f"TRY_CAST(REPLACE(REPLACE({col_expr}, '$',''), ',','') AS DOUBLE)"
    return f"TRY_CAST({col_expr} AS DOUBLE)"


# mapping: dimension -> metric -> table/col info
MAP = {
    "sector": {
        "employment": {"table": "employment_naics", "dim": "naics2d_code", "sa_col": "employment_sa", "nsa_col": "employment_nsa"},
        "postings": {"table": "postings_by_sector", "dim": "naics2d_code", "sa_col": "active_postings_sa", "nsa_col": "active_postings_nsa"},
        "salary": {"table": "salaries_naics", "dim": "naics2d_code", "sa_col": "salary_sa", "nsa_col": "salary_nsa"},
        "hiring_rate": {"table": "hiring_and_attrition_by_sector", "dim": "naics2d_code", "col": "rl_hiring_rate"},
        "attrition_rate": {"table": "hiring_and_attrition_by_sector", "dim": "naics2d_code", "col": "rl_attrition_rate"},
        "layoffs": {"table": "layoffs_by_naics", "dim": "naics2d", "col": "num_employees_laidoff"},
    },
    "state": {
        "employment": {"table": "employment_state", "dim": "state", "sa_col": "employment_sa", "nsa_col": "employment_nsa"},
        "postings": {"table": "postings_by_state", "dim": "state", "sa_col": "active_postings_sa", "nsa_col": "active_postings_nsa"},
        "salary": {"table": "salaries_state", "dim": "state", "sa_col": "salary_sa", "nsa_col": "salary_nsa"},
        "hiring_rate": {"table": "hiring_and_attrition_by_state", "dim": "state", "col": "rl_hiring_rate"},
        "attrition_rate": {"table": "hiring_and_attrition_by_state", "dim": "state", "col": "rl_attrition_rate"},
        "layoffs": {"table": "layoffs_by_state", "dim": "state", "col": "num_employees_laidoff"},
    },
    "soc": {
        "employment": {"table": "employment_soc", "dim": "soc2d_code", "sa_col": "employment_sa", "nsa_col": "employment_nsa"},
        "postings": {"table": "postings_by_occupation", "dim": "soc2d_code", "sa_col": "active_postings_sa", "nsa_col": "active_postings_nsa"},
        "salary": {"table": "salaries_soc", "dim": "soc2d_code", "sa_col": "salary_sa", "nsa_col": "salary_nsa"},
        "hiring_rate": {"table": "hiring_and_attrition_by_occupation", "dim": "soc2d_code", "col": "rl_hiring_rate"},
        "attrition_rate": {"table": "hiring_and_attrition_by_occupation", "dim": "soc2d_code", "col": "rl_attrition_rate"},
    },
    "national": {
        "employment": {"table": "employment_national", "dim": None, "sa_col": "employment_sa", "nsa_col": "employment_nsa"},
        "postings": {"table": "postings_total_us", "dim": None, "sa_col": "active_postings_sa", "nsa_col": "active_postings_nsa"},
        "salary": {"table": "salaries_national", "dim": None, "sa_col": "salary_sa", "nsa_col": "salary_nsa"},
        "hiring_rate": {"table": "hiring_and_attrition_total_us", "dim": None, "col": "rl_hiring_rate"},
        "attrition_rate": {"table": "hiring_and_attrition_total_us", "dim": None, "col": "rl_attrition_rate"},
        "layoffs": {"table": "total_layoffs", "dim": None, "col": "num_employees_laidoff"},
    },
}


def resolve_mapping(dimension_type: str, metric: str, sa: bool):
    if dimension_type not in MAP or metric not in MAP[dimension_type]:
        raise HTTPException(status_code=400, detail="Unsupported dimension/metric")
    cfg = MAP[dimension_type][metric]
    table = cfg["table"]
    dim_col = cfg.get("dim")
    col = cfg.get("col")
    sa_col = cfg.get("sa_col")
    nsa_col = cfg.get("nsa_col")
    value_col = col or (sa_col if sa or not nsa_col else nsa_col)
    needs_money = value_col in MONEY_COLS
    return table, dim_col, value_col, needs_money


@app.get("/api/health")
def health():
    return {"status": "ok", "db_exists": DB_PATH.exists()}


@app.get("/api/datasets")
def datasets():
    try:
        with get_con() as con:
            rows = con.execute("SELECT * FROM metadata").fetchall()
            cols = [c[1] for c in con.execute("PRAGMA table_info('metadata')").fetchall()]
            result = [dict(zip(cols, row)) for row in rows]
            return {"datasets": result}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/api/search")
def search(q: str = Query("")):
    q_lower = q.lower()
    results: List[Dict] = []
    try:
        with get_con() as con:
            sector_codes = [
                row[0] for row in con.execute("SELECT DISTINCT naics2d_code FROM employment_naics").fetchall()
            ]
            for code in sector_codes:
                name = NAICS_NAMES.get(code, code)
                label = f"{code} - {name}"
                if q_lower in label.lower():
                    results.append({"type": "sector", "id": code, "label": label})

            for state, in con.execute("SELECT DISTINCT state FROM postings_by_state").fetchall():
                if q_lower in state.lower():
                    results.append({"type": "state", "id": state, "label": state})

            for code, name in con.execute("SELECT DISTINCT soc2d_code, soc2d_name FROM salaries_soc").fetchall():
                label = f"{code} - {name}"
                if q_lower in label.lower():
                    results.append({"type": "soc", "id": code, "label": label})
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    return {"results": results[:20]}


@app.post("/api/query")
def api_query(body: QueryRequest):
    table, dim_col, value_col, needs_money = resolve_mapping(body.dimension_type, body.metric, body.sa)
    val_expr = value_expr(value_col)  # cast to numeric
    params: List = []
    sql = f"SELECT month, {val_expr} AS value FROM {table}"
    if dim_col:
        if not body.id:
            raise HTTPException(status_code=400, detail="id is required for this dimension")
        sql += f" WHERE {dim_col} = ?"
        params.append(body.id)
    sql += " ORDER BY month"
    if body.limit_months:
        sql = f"SELECT * FROM ({sql}) ORDER BY month DESC LIMIT {body.limit_months}"
        sql = f"SELECT * FROM ({sql}) ORDER BY month"
    try:
        with get_con() as con:
            rows = con.execute(sql, params).fetchall()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    series = [{"month": r[0], "value": r[1]} for r in rows]
    latest = series[-1]["value"] if series else None
    prev = series[-2]["value"] if len(series) > 1 else None
    pct_change = None
    if latest is not None and prev not in (None, 0):
        try:
            pct_change = (latest - prev) / prev * 100
        except Exception:
            pct_change = None
    return {
        "dimension_type": body.dimension_type,
        "id": body.id,
        "metric": body.metric,
        "series": series,
        "latest": latest,
        "prev": prev,
        "pct_change": pct_change,
    }


@app.get("/api/history")
def api_history(
    dimension_type: str = Query(..., description="sector|state|soc|national"),
    metric: str = Query(..., description="employment|postings|salary|hiring_rate|attrition_rate|layoffs"),
    id: Optional[str] = None,
    sa: bool = True,
    limit_months: int = Query(6, ge=1, le=24),
):
    table, dim_col, value_col, needs_money = resolve_mapping(dimension_type, metric, sa)
    val_expr = value_expr(value_col)
    params: List = []
    sql = f"SELECT month, {val_expr} AS value FROM {table}"
    if dim_col:
        if not id:
            raise HTTPException(status_code=400, detail="id is required for this dimension")
        sql += f" WHERE {dim_col} = ?"
        params.append(id)
    sql += " ORDER BY month DESC LIMIT ?"
    params.append(limit_months)
    sql = f"SELECT * FROM ({sql}) ORDER BY month"
    try:
        with get_con() as con:
            rows = con.execute(sql, params).fetchall()
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))
    series = [{"month": r[0], "value": r[1]} for r in rows]
    latest = series[-1]["value"] if series else None
    prev = series[-2]["value"] if len(series) > 1 else None
    pct_change = None
    if latest is not None and prev not in (None, 0):
        try:
            pct_change = (latest - prev) / prev * 100
        except Exception:
            pct_change = None
    return {
        "dimension_type": dimension_type,
        "id": id,
        "metric": metric,
        "series": series,
        "latest": latest,
        "prev": prev,
        "pct_change": pct_change,
    }


@app.get("/api/top-movers")
def api_top_movers(
    dimension_type: str = Query(..., description="sector|state|soc"),
    metric: str = Query(..., description="employment|postings|salary|hiring_rate|attrition_rate|layoffs"),
    count: int = 5,
    sa: bool = True,
    direction: str = Query("desc", description="desc|asc"),
):
    table, dim_col, value_col, needs_money = resolve_mapping(dimension_type, metric, sa)
    if not dim_col:
        raise HTTPException(status_code=400, detail="Top movers requires a dimension column")
    l_val_expr = value_expr(f"l.{value_col}")
    p_val_expr = value_expr(f"p.{value_col}")
    order_clause = "DESC" if direction == "desc" else "ASC"
    sql = f"""
    WITH months AS (SELECT DISTINCT month FROM {table}),
    latest_m AS (SELECT month FROM months ORDER BY month DESC LIMIT 1),
    prev_m AS (SELECT month FROM months ORDER BY month DESC OFFSET 1 LIMIT 1)
    SELECT
      l.{dim_col} AS dimension,
      {l_val_expr} AS value,
      {p_val_expr} AS prev_value,
      CASE WHEN {p_val_expr} IS NULL OR {p_val_expr}=0 THEN NULL
           ELSE ({l_val_expr} - {p_val_expr})/ {p_val_expr} * 100 END AS pct_change,
      l.month AS month,
      p.month AS prev_month
    FROM {table} l
    LEFT JOIN {table} p ON l.{dim_col}=p.{dim_col} AND p.month=(SELECT month FROM prev_m)
    WHERE l.month=(SELECT month FROM latest_m)
    ORDER BY pct_change {order_clause} NULLS LAST
    LIMIT {count};
    """
    try:
        with get_con() as con:
            rows = con.execute(sql).fetchall()
            cols = [d[0] for d in con.description]
            data = [dict(zip(cols, r)) for r in rows]
            return {"dimension_type": dimension_type, "metric": metric, "data": data}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/api/market-temperature")
def market_temperature():
    with get_con() as con:
        row = con.execute(
            "SELECT month, rl_hiring_rate, rl_attrition_rate FROM hiring_and_attrition_total_us ORDER BY month DESC LIMIT 2"
        ).fetchall()
    if not row:
        raise HTTPException(status_code=404, detail="No data")
    latest = row[0]
    prev = row[1] if len(row) > 1 else None
    trend = "cooling"
    if prev and latest[1] > prev[1]:
        trend = "heating"
    return {
        "month": latest[0],
        "hiring_rate": latest[1],
        "attrition_rate": latest[2],
        "trend": trend,
    }


@app.get("/api/sector-pulse")
def sector_pulse():
    with get_con() as con:
        latest_month = con.execute("SELECT MAX(month) FROM employment_naics").fetchone()[0]
        prev_month = con.execute(
            "SELECT month FROM (SELECT DISTINCT month FROM employment_naics ORDER BY month DESC LIMIT 2) ORDER BY month LIMIT 1"
        ).fetchone()[0]
        if latest_month is None or prev_month is None:
            raise HTTPException(status_code=404, detail="Not enough data for sector pulse")
        sql = f"""
        SELECT
          e.naics2d_code,
          '{latest_month}' AS month,
          '{prev_month}' AS prev_month,
          {value_expr('e.employment_sa')} AS employment,
          {value_expr('p.active_postings_sa')} AS postings,
          {value_expr('s.salary_sa')} AS salary,
          CASE WHEN {value_expr('pe.employment_sa')} IS NULL OR {value_expr('pe.employment_sa')}=0 THEN NULL
               ELSE ({value_expr('e.employment_sa')} - {value_expr('pe.employment_sa')})/{value_expr('pe.employment_sa')}*100 END AS employment_pct_change,
          CASE WHEN {value_expr('pp.active_postings_sa')} IS NULL OR {value_expr('pp.active_postings_sa')}=0 THEN NULL
               ELSE ({value_expr('p.active_postings_sa')} - {value_expr('pp.active_postings_sa')})/{value_expr('pp.active_postings_sa')}*100 END AS postings_pct_change,
          CASE WHEN {value_expr('ps.salary_sa')} IS NULL OR {value_expr('ps.salary_sa')}=0 THEN NULL
               ELSE ({value_expr('s.salary_sa')} - {value_expr('ps.salary_sa')})/{value_expr('ps.salary_sa')}*100 END AS salary_pct_change
        FROM employment_naics e
        LEFT JOIN employment_naics pe ON pe.naics2d_code=e.naics2d_code AND pe.month='{prev_month}'
        LEFT JOIN postings_by_sector p ON p.naics2d_code=e.naics2d_code AND p.month='{latest_month}'
        LEFT JOIN postings_by_sector pp ON pp.naics2d_code=e.naics2d_code AND pp.month='{prev_month}'
        LEFT JOIN salaries_naics s ON s.naics2d_code=e.naics2d_code AND s.month='{latest_month}'
        LEFT JOIN salaries_naics ps ON ps.naics2d_code=e.naics2d_code AND ps.month='{prev_month}'
        WHERE e.month='{latest_month}'
        """
        rows = con.execute(sql).fetchall()
        cols = [c[0] for c in con.description]
        data = [dict(zip(cols, r)) for r in rows]
    # add sector names
    for row in data:
        row["sector"] = NAICS_NAMES.get(row["naics2d_code"], row["naics2d_code"])
    return data


@app.get("/api/sector-spotlight")
def sector_spotlight():
    winners = api_top_movers("sector", "employment", count=3, direction="desc")["data"]
    losers = api_top_movers("sector", "employment", count=3, direction="asc")["data"]
    for row in winners + losers:
        row["sector"] = NAICS_NAMES.get(row["dimension"], row["dimension"])
    return {"winners": winners, "losers": losers}


@app.get("/api/postings-heatmap")
def postings_heatmap():
    with get_con() as con:
        months = [r[0] for r in con.execute("SELECT DISTINCT month FROM postings_by_state ORDER BY month DESC LIMIT 2").fetchall()]
        if not months:
            raise HTTPException(status_code=404, detail="No postings data")
        latest_month = months[0]
        prev_month = months[1] if len(months) > 1 else None
        sql = f"""
        WITH latest AS (
          SELECT state, TRY_CAST(active_postings_sa AS DOUBLE) AS value FROM postings_by_state WHERE month='{latest_month}'
        ), prev AS (
          SELECT state, TRY_CAST(active_postings_sa AS DOUBLE) AS value FROM postings_by_state WHERE month='{prev_month}'
        )
        SELECT l.state, l.value AS active_postings, CASE WHEN p.value IS NULL OR p.value=0 THEN NULL ELSE (l.value-p.value)/p.value*100 END AS pct_change
        FROM latest l LEFT JOIN prev p USING(state)
        ORDER BY pct_change DESC NULLS LAST;
        """
        rows = con.execute(sql).fetchall()
        cols = [c[0] for c in con.description]
        data = [dict(zip(cols, r)) for r in rows]
        return {"month": latest_month, "prev_month": prev_month, "data": data}


@app.get("/api/layoffs-heatmap")
def layoffs_heatmap():
    with get_con() as con:
        latest_month = con.execute("SELECT MAX(month) FROM layoffs_by_state").fetchone()[0]
        if latest_month is None:
            raise HTTPException(status_code=404, detail="No layoffs data")
        rows = con.execute(
            f"SELECT state, TRY_CAST(num_employees_laidoff AS DOUBLE) AS num_employees_laidoff FROM layoffs_by_state WHERE month='{latest_month}' ORDER BY num_employees_laidoff DESC"
        ).fetchall()
        data = [{"state": r[0], "num_employees_laidoff": r[1]} for r in rows]
        return {"month": latest_month, "data": data}


class GeminiRequest(BaseModel):
    prompt: str
    context: str


@app.post("/api/ask-gemini")
async def ask_gemini(request: GeminiRequest):
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY not configured")

    trimmed_context = (request.context or "")[:5000]
    trimmed_prompt = (request.prompt or "")[:1000]
    composed_prompt = (
        "Use only the provided context. Keep answers concise (<=3 sentences). "
        "Cite numeric values with units when present.\n\n"
        f"Context:\n{trimmed_context}\n\n"
        f"Question:\n{trimmed_prompt}"
    )

    try:
        resp = requests.post(
            f"{GEMINI_ENDPOINT}?key={GEMINI_API_KEY}",
            json={"contents": [{"parts": [{"text": composed_prompt}]}]},
            timeout=20,
        )
        resp.raise_for_status()
        payload = resp.json()
        candidates = payload.get("candidates", [])
        if not candidates:
            raise HTTPException(status_code=502, detail="No response from Gemini")

        text = candidates[0].get("content", {}).get("parts", [{}])[0].get("text", "")
        return {"response": text}
    except requests.HTTPError as http_err:
        raise HTTPException(status_code=502, detail=f"Gemini error: {http_err}") from http_err
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.getenv("PORT", 8000)))
