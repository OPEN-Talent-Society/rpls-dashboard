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
from dotenv import load_dotenv
from supabase import Client, create_client

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = Path(os.environ.get("RPLS_DATA_DIR", ROOT.parent / "rpls_data"))
ENV_PATH = ROOT / ".env"

load_dotenv(ENV_PATH)
SUPABASE_URL = os.getenv("PUBLIC_SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

DRY_RUN = not (SUPABASE_URL and SUPABASE_KEY)
supabase: Client | None = None
if not DRY_RUN:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
else:
    print(f"⚠️  Supabase credentials missing in {ENV_PATH}. Running in DRY RUN (no uploads).")


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
    df = pd.DataFrame(rows, columns=columns)
    payload = df.to_dict(orient="records")
    chunk = 1000
    for i in range(0, len(payload), chunk):
        batch = payload[i : i + chunk]
        supabase.table(table).upsert(batch).execute()
    print(f"Upserted {len(rows)} rows into {table}")


def run_etl():
    if not DATA_DIR.exists():
        raise FileNotFoundError(f"Data dir not found: {DATA_DIR}")

    con = duckdb.connect(database=":memory:", config={"threads": 4})
    con.execute("SET enable_progress_bar = false;")
    print(f"📂 Loading data from {DATA_DIR}")

    # Dimensions
    sectors = con.execute(
        f"""
        SELECT DISTINCT naics2d_code AS id, naics2d_name AS name
        FROM read_csv_auto('{DATA_DIR/'employment_naics.csv'}', all_varchar=True)
        WHERE naics2d_code!='00'
        """
    ).fetchall()
    upsert("dim_sectors", ["id", "name"], sectors)

    occupations = con.execute(
        f"""
        SELECT DISTINCT soc2d_code AS id, soc2d_name AS name
        FROM read_csv_auto('{DATA_DIR/'employment_soc.csv'}', all_varchar=True)
        WHERE soc2d_code!='0'
        """
    ).fetchall()
    upsert("dim_occupations", ["id", "name"], occupations)

    states = con.execute(
        f"""
        SELECT DISTINCT state AS id, state AS name
        FROM read_csv_auto('{DATA_DIR/'employment_state.csv'}', all_varchar=True)
        WHERE state IS NOT NULL AND state!=''
        """
    ).fetchall()
    upsert("dim_states", ["id", "name"], states)

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

    print("✅ Supabase ETL complete.")


def upload_to_supabase(table_name, columns, query_result):
    """Backward compatibility shim; kept for older imports."""
    upsert(table_name, columns, query_result)


if __name__ == "__main__":
    run_etl()
