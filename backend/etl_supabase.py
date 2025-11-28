"""
Supabase ETL (DuckDB -> Supabase Postgres)
-----------------------------------------
- Loads CSVs from canonical `rpls_data/`
- Normalizes to dimension + fact tables (schema in supabase/schema.sql)
- Upserts to Supabase (Service Role key recommended)

Run:
  export PUBLIC_SUPABASE_URL=...
  export SUPABASE_SERVICE_ROLE_KEY=...
  python backend/etl_supabase.py
"""

from __future__ import annotations

import os
from pathlib import Path
from typing import Sequence

import duckdb
import pandas as pd
import numpy as np
from dotenv import load_dotenv
from supabase import Client, create_client

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = Path(os.environ.get("RPLS_DATA_DIR", ROOT.parent / "rpls_data"))
ENV_PATH = ROOT / ".env"

# Safety guard: refuse to proceed if the largest CSV bundle exceeds ~450MB
BIG_FILES = [
    DATA_DIR / "employment_all_granularities.csv",
    DATA_DIR / "salaries_all_granularities.csv",
    DATA_DIR / "hiring_and_attrition_by_sector_occupation_state.csv",
    DATA_DIR / "postings_by_sector_occupation_state.csv",
]
MAX_BYTES = 450 * 1024 * 1024  # ~450MB cap to stay within Supabase free tier

load_dotenv(ENV_PATH)
SUPABASE_URL = os.getenv("PUBLIC_SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

DRY_RUN = not (SUPABASE_URL and SUPABASE_KEY)
supabase: Client | None = None
if not DRY_RUN:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
else:
    print(f"⚠️  Supabase credentials missing in {ENV_PATH}. Running in DRY RUN (no uploads).")

def check_size_guard():
    total = 0
    missing = []
    for p in BIG_FILES:
        if not p.exists():
            missing.append(p.name)
            continue
        total += p.stat().st_size
    if missing:
        print(f"⚠️ Missing expected files: {', '.join(missing)}")
    print(f"Estimated size of high-volume CSVs: {total/1024/1024:.1f} MB")
    if total > MAX_BYTES and not DRY_RUN:
        raise SystemExit(
            f"Aborting ETL: high-volume CSVs total {total/1024/1024:.1f} MB exceeds guard {MAX_BYTES/1024/1024} MB. "
            "Adjust guard or offload data before retrying."
        )


def money(col: str) -> str:
    return f"TRY_CAST(REPLACE(REPLACE({col}, '$',''), ',','') AS DOUBLE)"


def upsert(table: str, columns: Sequence[str], rows: Sequence[Sequence]) -> None:
    """Chunked upsert to Supabase; DRY_RUN logs only."""
    if DRY_RUN:
        print(f"DRY RUN: {table} rows={len(rows)}")
        return
    assert supabase is not None
    if not rows:
        print(f"Skip {table}: no rows")
        return

    def _sanitize(val):
        if isinstance(val, str) and val.lower() in {"nan", "inf", "-inf", "infinity", "-infinity"}:
            return None
        if isinstance(val, float) and (np.isnan(val) or np.isinf(val)):
            return None
        return val

    payload = []
    for row in rows:
        clean = {}
        for col, val in zip(columns, row):
            sval = _sanitize(val)
            clean[col] = sval
        payload.append(clean)
    chunk = 1000
    for i in range(0, len(payload), chunk):
        batch = payload[i : i + chunk]
        supabase.table(table).upsert(batch).execute()
    print(f"Upserted {len(rows)} rows into {table}")


def run_etl():
    check_size_guard()
    if not DATA_DIR.exists():
        raise FileNotFoundError(f"Data dir not found: {DATA_DIR}")

    con = duckdb.connect(database=":memory:", config={"threads": 4})
    con.execute("SET enable_progress_bar = false;")
    print(f"📂 Loading data from {DATA_DIR}")

    # Dimensions
    sectors = con.execute(
        f"""
        WITH base AS (
          SELECT naics2d_code AS code, naics2d_name AS name FROM read_csv_auto('{DATA_DIR/'employment_naics.csv'}', all_varchar=True)
          UNION ALL
          SELECT naics2d_code, naics2d_name FROM read_csv_auto('{DATA_DIR/'salaries_naics.csv'}', all_varchar=True)
        ),
        codes AS (
          SELECT DISTINCT code FROM base
          UNION
          SELECT DISTINCT naics2d AS code FROM read_csv_auto('{DATA_DIR/'layoffs_by_naics.csv'}', all_varchar=True)
          UNION
          SELECT DISTINCT naics2d_code AS code FROM read_csv_auto('{DATA_DIR/'postings_by_sector.csv'}', all_varchar=True)
        )
        SELECT c.code AS id, COALESCE(MAX(b.name), c.code) AS name
        FROM codes c
        LEFT JOIN base b ON c.code=b.code
        WHERE c.code IS NOT NULL AND c.code!=''
        GROUP BY c.code
        """
    ).fetchall()
    upsert("dim_sectors", ["id", "name"], sectors)

    occupations = con.execute(
        f"""
        WITH base AS (
          SELECT soc2d_code AS code, soc2d_name AS name FROM read_csv_auto('{DATA_DIR/'employment_soc.csv'}', all_varchar=True)
          UNION ALL
          SELECT soc2d_code, soc2d_name FROM read_csv_auto('{DATA_DIR/'salaries_soc.csv'}', all_varchar=True)
        ),
        codes AS (
          SELECT DISTINCT code FROM base
          UNION
          SELECT DISTINCT soc2d_code AS code FROM read_csv_auto('{DATA_DIR/'postings_by_occupation.csv'}', all_varchar=True)
        )
        SELECT c.code AS id, COALESCE(MAX(b.name), c.code) AS name
        FROM codes c
        LEFT JOIN base b ON c.code=b.code
        WHERE c.code IS NOT NULL AND c.code!=''
        GROUP BY c.code
        """
    ).fetchall()
    upsert("dim_occupations", ["id", "name"], occupations)

    states = con.execute(
        f"""
        WITH base AS (
          SELECT state FROM read_csv_auto('{DATA_DIR/'employment_state.csv'}', all_varchar=True)
          UNION ALL SELECT state FROM read_csv_auto('{DATA_DIR/'salaries_state.csv'}', all_varchar=True)
          UNION ALL SELECT state FROM read_csv_auto('{DATA_DIR/'layoffs_by_state.csv'}', all_varchar=True)
          UNION ALL SELECT state FROM read_csv_auto('{DATA_DIR/'postings_by_state.csv'}', all_varchar=True)
        )
        SELECT DISTINCT COALESCE(NULLIF(state,''),'empty') AS id
        FROM base
        WHERE state IS NOT NULL
        """
    ).fetchall()
    upsert("dim_states", ["id"], states)

    # Layoffs
    layoffs = con.execute(
        f"""
        WITH total AS (
          SELECT month||'-01' AS date, NULL AS sector_id, NULL AS state_id,
                 TRY_CAST(num_employees_notified AS INT), TRY_CAST(num_notices_issued AS INT),
                 TRY_CAST(num_employees_laidoff AS INT), 'total' AS granularity
          FROM read_csv_auto('{DATA_DIR/'total_layoffs.csv'}', all_varchar=True)
        ),
        naics AS (
          SELECT month||'-01', naics2d, NULL,
                 TRY_CAST(num_employees_notified AS INT), TRY_CAST(num_notices_issued AS INT),
                 TRY_CAST(num_employees_laidoff AS INT), 'sector'
          FROM read_csv_auto('{DATA_DIR/'layoffs_by_naics.csv'}', all_varchar=True)
        ),
        state AS (
          SELECT month||'-01', NULL, state,
                 TRY_CAST(num_employees_notified AS INT), TRY_CAST(num_notices_issued AS INT),
                 TRY_CAST(num_employees_laidoff AS INT), 'state'
          FROM read_csv_auto('{DATA_DIR/'layoffs_by_state.csv'}', all_varchar=True)
        )
        SELECT * FROM total
        UNION ALL SELECT * FROM naics
        UNION ALL SELECT * FROM state
        """
    ).fetchall()
    upsert(
        "fact_layoffs",
        ["date", "sector_id", "state_id", "employees_notified", "notices_issued", "employees_laidoff", "granularity"],
        layoffs,
    )

    # Salaries
    salaries = con.execute(
        f"""
        WITH naics AS (
          SELECT month||'-01' AS date, naics2d_code AS sector_id, NULL AS occupation_id, NULL AS state_id,
                 TRY_CAST(count AS INT) AS count, {money('salary_nsa')} AS salary_nsa, {money('salary_sa')} AS salary_sa,
                 'sector' AS granularity
          FROM read_csv_auto('{DATA_DIR/'salaries_naics.csv'}', all_varchar=True)
        ),
        soc AS (
          SELECT month||'-01', NULL, soc2d_code, NULL,
                 TRY_CAST(count AS INT), {money('salary_nsa')}, {money('salary_sa')}, 'occupation'
          FROM read_csv_auto('{DATA_DIR/'salaries_soc.csv'}', all_varchar=True)
        ),
        state AS (
          SELECT month||'-01', NULL, NULL, state,
                 TRY_CAST(count AS INT), {money('salary_nsa')}, {money('salary_sa')}, 'state'
          FROM read_csv_auto('{DATA_DIR/'salaries_state.csv'}', all_varchar=True)
        ),
        national AS (
          SELECT month||'-01', NULL, NULL, NULL,
                 TRY_CAST(count AS INT), {money('salary_nsa')}, {money('salary_sa')}, 'national'
          FROM read_csv_auto('{DATA_DIR/'salaries_national.csv'}', all_varchar=True)
        )
        SELECT * FROM naics
        UNION ALL SELECT * FROM soc
        UNION ALL SELECT * FROM state
        UNION ALL SELECT * FROM national
        """
    ).fetchall()
    upsert(
        "fact_salaries",
        ["date", "sector_id", "occupation_id", "state_id", "count", "salary_nsa", "salary_sa", "granularity"],
        salaries,
    )

    # Employment
    employment = con.execute(
        f"""
        WITH national AS (
          SELECT month||'-01' AS date, NULL AS sector_id, NULL AS occupation_id, NULL AS state_id,
                 TRY_CAST(employment_nsa AS DOUBLE), TRY_CAST(employment_sa AS DOUBLE), 'national' AS granularity
          FROM read_csv_auto('{DATA_DIR/'employment_national.csv'}', all_varchar=True)
        ),
        naics AS (
          SELECT month||'-01', naics2d_code, NULL, NULL,
                 TRY_CAST(employment_nsa AS DOUBLE), TRY_CAST(employment_sa AS DOUBLE), 'sector'
          FROM read_csv_auto('{DATA_DIR/'employment_naics.csv'}', all_varchar=True)
        ),
        soc AS (
          SELECT month||'-01', NULL, soc2d_code, NULL,
                 TRY_CAST(employment_nsa AS DOUBLE), TRY_CAST(employment_sa AS DOUBLE), 'occupation'
          FROM read_csv_auto('{DATA_DIR/'employment_soc.csv'}', all_varchar=True)
        ),
        state AS (
          SELECT month||'-01', NULL, NULL, state,
                 TRY_CAST(employment_nsa AS DOUBLE), TRY_CAST(employment_sa AS DOUBLE), 'state'
          FROM read_csv_auto('{DATA_DIR/'employment_state.csv'}', all_varchar=True)
        )
        SELECT * FROM national
        UNION ALL SELECT * FROM naics
        UNION ALL SELECT * FROM soc
        UNION ALL SELECT * FROM state
        """
    ).fetchall()
    upsert(
        "fact_employment",
        ["date", "sector_id", "occupation_id", "state_id", "employment_nsa", "employment_sa", "granularity"],
        employment,
    )

    # Postings
    postings = con.execute(
        f"""
        WITH total AS (
          SELECT month||'-01' AS date, NULL AS sector_id, NULL AS occupation_id, NULL AS state_id,
                 TRY_CAST(active_postings_nsa AS DOUBLE), TRY_CAST(active_postings_sa AS DOUBLE),
                 NULL AS new_postings_nsa, NULL AS new_postings_sa,
                 NULL AS removed_postings_nsa, NULL AS removed_postings_sa,
                 'total' AS granularity
          FROM read_csv_auto('{DATA_DIR/'postings_total_us.csv'}', all_varchar=True)
        ),
        naics AS (
          SELECT month||'-01', naics2d_code, NULL, NULL,
                 TRY_CAST(active_postings_nsa AS DOUBLE), TRY_CAST(active_postings_sa AS DOUBLE),
                 NULL,NULL,NULL,NULL,
                 'sector'
          FROM read_csv_auto('{DATA_DIR/'postings_by_sector.csv'}', all_varchar=True)
        ),
        soc AS (
          SELECT month||'-01', NULL, soc2d_code, NULL,
                 TRY_CAST(active_postings_nsa AS DOUBLE), TRY_CAST(active_postings_sa AS DOUBLE),
                 NULL,NULL,NULL,NULL,
                 'occupation'
          FROM read_csv_auto('{DATA_DIR/'postings_by_occupation.csv'}', all_varchar=True)
        ),
        state AS (
          SELECT month||'-01', NULL, NULL, state,
                 TRY_CAST(active_postings_nsa AS DOUBLE), TRY_CAST(active_postings_sa AS DOUBLE),
                 NULL,NULL,NULL,NULL,
                 'state'
          FROM read_csv_auto('{DATA_DIR/'postings_by_state.csv'}', all_varchar=True)
        )
        SELECT * FROM total
        UNION ALL SELECT * FROM naics
        UNION ALL SELECT * FROM soc
        UNION ALL SELECT * FROM state
        """
    ).fetchall()
    upsert(
        "fact_postings",
        [
            "date",
            "sector_id",
            "occupation_id",
            "state_id",
            "active_postings_nsa",
            "active_postings_sa",
            "new_postings_nsa",
            "new_postings_sa",
            "removed_postings_nsa",
            "removed_postings_sa",
            "granularity",
        ],
        postings,
    )

    # Hiring / Attrition
    hiring = con.execute(
        f"""
        WITH total AS (
          SELECT month||'-01' AS date, NULL AS sector_id, NULL AS occupation_id, NULL AS state_id,
                 TRY_CAST(rl_hiring_rate AS DOUBLE) AS hiring_rate_sa,
                 TRY_CAST(rl_attrition_rate AS DOUBLE) AS attrition_rate_sa,
                 TRY_CAST(rl_hiring_rate_nsa AS DOUBLE) AS hiring_rate_nsa,
                 TRY_CAST(rl_attrition_rate_nsa AS DOUBLE) AS attrition_rate_nsa,
                 'total' AS granularity
          FROM read_csv_auto('{DATA_DIR/'hiring_and_attrition_total_us.csv'}', all_varchar=True)
        ),
        naics AS (
          SELECT month||'-01', naics2d_code, NULL, NULL,
                 TRY_CAST(rl_hiring_rate AS DOUBLE), TRY_CAST(rl_attrition_rate AS DOUBLE),
                 TRY_CAST(rl_hiring_rate_nsa AS DOUBLE), TRY_CAST(rl_attrition_rate_nsa AS DOUBLE),
                 'sector'
          FROM read_csv_auto('{DATA_DIR/'hiring_and_attrition_by_sector.csv'}', all_varchar=True)
        ),
        soc AS (
          SELECT month||'-01', NULL, soc2d_code, NULL,
                 TRY_CAST(rl_hiring_rate AS DOUBLE), TRY_CAST(rl_attrition_rate AS DOUBLE),
                 TRY_CAST(rl_hiring_rate_nsa AS DOUBLE), TRY_CAST(rl_attrition_rate_nsa AS DOUBLE),
                 'occupation'
          FROM read_csv_auto('{DATA_DIR/'hiring_and_attrition_by_occupation.csv'}', all_varchar=True)
        ),
        state AS (
          SELECT month||'-01', NULL, NULL, state,
                 TRY_CAST(rl_hiring_rate AS DOUBLE), TRY_CAST(rl_attrition_rate AS DOUBLE),
                 TRY_CAST(rl_hiring_rate_nsa AS DOUBLE), TRY_CAST(rl_attrition_rate_nsa AS DOUBLE),
                 'state'
          FROM read_csv_auto('{DATA_DIR/'hiring_and_attrition_by_state.csv'}', all_varchar=True)
        )
        SELECT * FROM total
        UNION ALL SELECT * FROM naics
        UNION ALL SELECT * FROM soc
        UNION ALL SELECT * FROM state
        """
    ).fetchall()
    upsert(
        "fact_hiring_attrition",
        [
            "date",
            "sector_id",
            "occupation_id",
            "state_id",
            "hiring_rate_sa",
            "attrition_rate_sa",
            "hiring_rate_nsa",
            "attrition_rate_nsa",
            "granularity",
        ],
        hiring,
    )

    # Multi-dimension facts (sector + occupation + state)
    employment_multi = con.execute(
        f"""
        SELECT month||'-01' AS date,
               naics2d_code AS sector_id,
               soc2d_code AS occupation_id,
               state AS state_id,
               TRY_CAST(count_nsa AS DOUBLE) AS employment_nsa,
               TRY_CAST(count_sa AS DOUBLE) AS employment_sa
        FROM read_csv_auto('{DATA_DIR/'employment_all_granularities.csv'}', all_varchar=True)
        WHERE month IS NOT NULL
        """
    ).fetchall()
    upsert(
        "fact_employment_multi",
        ["date", "sector_id", "occupation_id", "state_id", "employment_nsa", "employment_sa"],
        employment_multi,
    )

    postings_multi = con.execute(
        f"""
        SELECT month||'-01' AS date,
               naics2d_code AS sector_id,
               soc2d_code AS occupation_id,
               state AS state_id,
               TRY_CAST(active_postings_nsa AS DOUBLE) AS active_postings_nsa,
               TRY_CAST(active_postings_sa AS DOUBLE) AS active_postings_sa,
               NULL AS new_postings_nsa,
               NULL AS new_postings_sa,
               NULL AS removed_postings_nsa,
               NULL AS removed_postings_sa
        FROM read_csv_auto('{DATA_DIR/'postings_by_sector_occupation_state.csv'}', all_varchar=True)
        WHERE month IS NOT NULL
        """
    ).fetchall()
    upsert(
        "fact_postings_multi",
        [
            "date",
            "sector_id",
            "occupation_id",
            "state_id",
            "active_postings_nsa",
            "active_postings_sa",
            "new_postings_nsa",
            "new_postings_sa",
            "removed_postings_nsa",
            "removed_postings_sa",
        ],
        postings_multi,
    )

    hiring_multi = con.execute(
        f"""
        SELECT month||'-01' AS date,
               naics2d_code AS sector_id,
               soc2d_code AS occupation_id,
               state AS state_id,
               TRY_CAST(rl_hiring_rate_nsa AS DOUBLE) AS hiring_rate_nsa,
               TRY_CAST(rl_attrition_rate_nsa AS DOUBLE) AS attrition_rate_nsa,
               TRY_CAST(rl_hiring_rate AS DOUBLE) AS hiring_rate_sa,
               TRY_CAST(rl_attrition_rate AS DOUBLE) AS attrition_rate_sa
        FROM read_csv_auto('{DATA_DIR/'hiring_and_attrition_by_sector_occupation_state.csv'}', all_varchar=True)
        WHERE month IS NOT NULL
        """
    ).fetchall()
    upsert(
        "fact_hiring_attrition_multi",
        [
            "date",
            "sector_id",
            "occupation_id",
            "state_id",
            "hiring_rate_nsa",
            "attrition_rate_nsa",
            "hiring_rate_sa",
            "attrition_rate_sa",
        ],
        hiring_multi,
    )

    salaries_multi = con.execute(
        f"""
        SELECT month||'-01' AS date,
               naics2d_code AS sector_id,
               soc2d_code AS occupation_id,
               state AS state_id,
               TRY_CAST(count AS INT) AS count,
               TRY_CAST(salary_nsa AS DOUBLE) AS salary_nsa,
               TRY_CAST(salary_sa AS DOUBLE) AS salary_sa,
               TRY_CAST(weight AS DOUBLE) AS weight
        FROM read_csv_auto('{DATA_DIR/'salaries_all_granularities.csv'}', all_varchar=True)
        WHERE month IS NOT NULL
        """
    ).fetchall()
    upsert(
        "fact_salaries_multi",
        ["date", "sector_id", "occupation_id", "state_id", "count", "salary_nsa", "salary_sa", "weight"],
        salaries_multi,
    )

    # Summary / overview tables
    sector_name_to_id = {name: code for code, name in sectors}
    occ_name_to_id = {name: code for code, name in occupations}
    state_name_to_id = {sid: sid for (sid,) in states}

    def _num(val):
        try:
            return float(val)
        except Exception:
            return None

    def load_summary(path, key_col, mapper, cols):
        df = pd.read_csv(path)
        rows = []
        for _, r in df.iterrows():
            key_val = mapper.get(str(r[key_col]), None)
            if not key_val:
                continue
            rows.append([key_val] + [_num(r.get(c)) for c in cols])
        return rows

    sector_summary_rows = load_summary(
        DATA_DIR / "sector_summary.csv",
        "Sector",
        sector_name_to_id,
        ["August 2025", "September 2025", "October 2025", "YoY change (Oct 24–Oct 25)", "MoM change (Sep 25–Oct 25)"],
    )
    upsert("summary_sector", ["sector_id", "aug_2025", "sep_2025", "oct_2025", "yoy", "mom"], sector_summary_rows)

    occupation_summary_rows = load_summary(
        DATA_DIR / "occupation_summary.csv",
        "Occupation",
        occ_name_to_id,
        ["August 2025", "September 2025", "October 2025", "YoY change (Oct 24–Oct 25)", "MoM change (Sep 25–Oct 25)"],
    )
    upsert("summary_occupation", ["occupation_id", "aug_2025", "sep_2025", "oct_2025", "yoy", "mom"], occupation_summary_rows)

    state_summary_rows = load_summary(
        DATA_DIR / "state_summary.csv",
        "State",
        state_name_to_id,
        ["August 2025", "September 2025", "October 2025", "YoY change (Oct 24–Oct 25)", "MoM change (Sep 25–Oct 25)"],
    )
    upsert("summary_state", ["state_id", "aug_2025", "sep_2025", "oct_2025", "yoy", "mom"], state_summary_rows)

    sal_naics = con.execute(
        f"""
        SELECT naics2d_code AS sector_id,
               TRY_CAST("Oct 2024" AS DOUBLE),
               TRY_CAST("Aug 2025" AS DOUBLE),
               TRY_CAST("Sep 2025" AS DOUBLE),
               TRY_CAST("Oct 2025" AS DOUBLE),
               TRY_CAST("Pct change YoY (Oct 2024 - Oct 2025)" AS DOUBLE),
               TRY_CAST("Pct change (Sep 2025 - Oct 2025)" AS DOUBLE)
        FROM read_csv_auto('{DATA_DIR/'salary_overview_naics.csv'}', all_varchar=True)
        """
    ).fetchall()
    upsert(
        "salary_overview_naics",
        ["sector_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "pct_change_yoy", "pct_change_mom"],
        sal_naics,
    )

    sal_soc = con.execute(
        f"""
        SELECT soc2d_code AS occupation_id,
               TRY_CAST("Oct 2024" AS DOUBLE),
               TRY_CAST("Aug 2025" AS DOUBLE),
               TRY_CAST("Sep 2025" AS DOUBLE),
               TRY_CAST("Oct 2025" AS DOUBLE),
               TRY_CAST("Pct change YoY (Oct 2024 - Oct 2025)" AS DOUBLE),
               TRY_CAST("Pct change (Sep 2025 - Oct 2025)" AS DOUBLE)
        FROM read_csv_auto('{DATA_DIR/'salary_overview_soc.csv'}', all_varchar=True)
        """
    ).fetchall()
    upsert(
        "salary_overview_soc",
        ["occupation_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "pct_change_yoy", "pct_change_mom"],
        sal_soc,
    )

    sal_state = con.execute(
        f"""
        SELECT state AS state_id,
               TRY_CAST("Oct 2024" AS DOUBLE),
               TRY_CAST("Aug 2025" AS DOUBLE),
               TRY_CAST("Sep 2025" AS DOUBLE),
               TRY_CAST("Oct 2025" AS DOUBLE),
               TRY_CAST("Pct change YoY (Oct 2024 - Oct 2025)" AS DOUBLE),
               TRY_CAST("Pct change (Sep 2025 - Oct 2025)" AS DOUBLE)
        FROM read_csv_auto('{DATA_DIR/'salary_overview_state.csv'}', all_varchar=True)
        """
    ).fetchall()
    upsert(
        "salary_overview_state",
        ["state_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "pct_change_yoy", "pct_change_mom"],
        sal_state,
    )

    sal_total = con.execute(
        f"""
        SELECT '_total' AS id,
               TRY_CAST("Oct 2024" AS DOUBLE),
               TRY_CAST("Aug 2025" AS DOUBLE),
               TRY_CAST("Sep 2025" AS DOUBLE),
               TRY_CAST("Oct 2025" AS DOUBLE),
               TRY_CAST("Pct change YoY (Oct 2024 - Oct 2025)" AS DOUBLE),
               TRY_CAST("Pct change (Sep 2025 - Oct 2025)" AS DOUBLE)
        FROM read_csv_auto('{DATA_DIR/'salary_overview_total.csv'}', all_varchar=True)
        """
    ).fetchall()
    upsert(
        "salary_overview_total",
        ["id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "pct_change_yoy", "pct_change_mom"],
        sal_total,
    )

    table_b_naics = load_summary(
        DATA_DIR / "table_b_naics.csv",
        "Sector",
        sector_name_to_id,
        ["Oct 2024", "Aug 2025", "Sep 2025", "Oct 2025", "Oct 2025 - Oct 2024", "Oct 2025 - Sep 2025"],
    )
    upsert(
        "table_b_naics",
        ["sector_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "diff_yoy", "diff_mom"],
        table_b_naics,
    )

    table_b_soc = load_summary(
        DATA_DIR / "table_b_soc.csv",
        "SOC Category",
        occ_name_to_id,
        ["Oct 2024", "Aug 2025", "Sep 2025", "Oct 2025", "Oct 2025 - Oct 2024", "Oct 2025 - Sep 2025"],
    )
    upsert(
        "table_b_soc",
        ["occupation_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "diff_yoy", "diff_mom"],
        table_b_soc,
    )

    table_b_state = load_summary(
        DATA_DIR / "table_b_state.csv",
        "State",
        state_name_to_id,
        ["Oct 2024", "Aug 2025", "Sep 2025", "Oct 2025", "Oct 2025 - Oct 2024", "Oct 2025 - Sep 2025"],
    )
    upsert(
        "table_b_state",
        ["state_id", "oct_2024", "aug_2025", "sep_2025", "oct_2025", "diff_yoy", "diff_mom"],
        table_b_state,
    )

    hiring_sector_summary = load_summary(
        DATA_DIR / "hiring_sector_summary.csv",
        "Sector",
        sector_name_to_id,
        ["August 2025", "September 2025", "October 2025", "YoY change (pp) (Oct 24–Oct 25)", "MoM change (pp) (Sep 25–Oct 25)"],
    )
    upsert(
        "hiring_sector_summary",
        ["sector_id", "aug_2025", "sep_2025", "oct_2025", "yoy_pp", "mom_pp"],
        hiring_sector_summary,
    )

    attrition_sector_summary = load_summary(
        DATA_DIR / "attrition_sector_summary.csv",
        "Sector",
        sector_name_to_id,
        ["August 2025", "September 2025", "October 2025", "YoY change (pp) (Oct 24–Oct 25)", "MoM change (pp) (Sep 25–Oct 25)"],
    )
    upsert(
        "attrition_sector_summary",
        ["sector_id", "aug_2025", "sep_2025", "oct_2025", "yoy_pp", "mom_pp"],
        attrition_sector_summary,
    )

    print("✅ Supabase ETL complete.")


def upload_to_supabase(table_name, columns, query_result):
    """Backward compatibility shim; kept for older imports."""
    upsert(table_name, columns, query_result)


if __name__ == "__main__":
    run_etl()
