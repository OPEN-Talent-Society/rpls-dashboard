"""Build DuckDB from RPLS CSVs.
Run: python etl.py
"""
import os
import time
from pathlib import Path
from typing import List, Tuple

import duckdb

ROOT = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT / "rpls_data"
DB_PATH = Path(__file__).resolve().parent / "rpls.duckdb"

# Tables with (view_name, table, dimension, value_col, needs_money_cleanup)
TOP_MOVER_TARGETS: List[Tuple[str, str, str, str, bool]] = [
    ("top_movers_employment_naics", "employment_naics", "naics2d_code", "employment_sa", False),
    ("top_movers_employment_state", "employment_state", "state", "employment_sa", False),
    ("top_movers_postings_by_state", "postings_by_state", "state", "active_postings_sa", False),
    ("top_movers_postings_by_sector", "postings_by_sector", "naics2d_code", "active_postings_sa", False),
    ("top_movers_salaries_naics", "salaries_naics", "naics2d_code", "salary_sa", True),
    ("top_movers_salaries_state", "salaries_state", "state", "salary_sa", True),
    ("top_movers_salaries_soc", "salaries_soc", "soc2d_code", "salary_sa", True),
    ("top_movers_layoffs_by_state", "layoffs_by_state", "state", "num_employees_laidoff", False),
    ("top_movers_layoffs_by_naics", "layoffs_by_naics", "naics2d", "num_employees_laidoff", False),
]


def build_db():
    if not DATA_DIR.exists():
        raise FileNotFoundError(f"Data dir not found: {DATA_DIR}")

    if not DB_PATH.parent.exists():
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(str(DB_PATH))
    con.execute("PRAGMA threads=4")
    ingested_at = int(time.time())
    csv_files = [p for p in DATA_DIR.glob("*.csv") if p.name != "__MACOSX"]
    table_names = []
    for csv_path in csv_files:
        table = csv_path.stem.lower()
        table_names.append(table)
        print(f"Ingesting {csv_path.name} -> {table}")
        con.execute(
            f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM read_csv_auto(?, header=True, all_varchar=True, sample_size=-1)",
            [str(csv_path)],
        )
    # Build metadata after all tables exist
    metadata_rows = []
    for table, csv_path in zip(table_names, csv_files):
        row_count = con.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
        min_month = max_month = None
        cols = [row[1] for row in con.execute(f"PRAGMA table_info('{table}')").fetchall()]
        if "month" in cols:
            min_month, max_month = con.execute(f"SELECT MIN(month), MAX(month) FROM {table}").fetchone()
        metadata_rows.append((table, csv_path.name, row_count, min_month, max_month, ingested_at))

    values_sql = ",".join(
        [
            f"('{t}', '{src}', {rc}, {'NULL' if min_m is None else repr(min_m)}, {'NULL' if max_m is None else repr(max_m)}, {ingested_at})"
            for (t, src, rc, min_m, max_m, ingested_at) in metadata_rows
        ]
    )
    con.execute(
        "CREATE OR REPLACE TABLE metadata AS SELECT * FROM (VALUES %s) AS t(table_name, source_file, row_count, min_month, max_month, ingested_at)"
        % values_sql
    )

    # Create top-mover views
    for view_name, table, dim, val, needs_money in TOP_MOVER_TARGETS:
        print(f"Creating view {view_name}")
        if needs_money:
            l_expr = f"TRY_CAST(REPLACE(REPLACE(l.{val}, '$',''), ',','') AS DOUBLE)"
            p_expr = f"TRY_CAST(REPLACE(REPLACE(p.{val}, '$',''), ',','') AS DOUBLE)"
        else:
            l_expr = f"TRY_CAST(l.{val} AS DOUBLE)"
            p_expr = f"TRY_CAST(p.{val} AS DOUBLE)"
        sql = f"""
        CREATE OR REPLACE VIEW {view_name} AS
        WITH months AS (SELECT DISTINCT month FROM {table}),
        latest_m AS (SELECT month FROM months ORDER BY month DESC LIMIT 1),
        prev_m AS (SELECT month FROM months ORDER BY month DESC OFFSET 1 LIMIT 1)
        SELECT
          l.{dim} AS dimension,
          {l_expr} AS value,
          CASE WHEN {p_expr} IS NULL OR {p_expr}=0 THEN NULL
               ELSE ({l_expr} - {p_expr})/ {p_expr} * 100 END AS pct_change,
          l.month AS month,
          p.month AS prev_month
        FROM {table} l
        LEFT JOIN {table} p ON l.{dim} = p.{dim} AND p.month = (SELECT month FROM prev_m)
        WHERE l.month = (SELECT month FROM latest_m);
        """
        con.execute(sql)

    con.close()
    print(f"DuckDB built at {DB_PATH}")


if __name__ == "__main__":
    build_db()
