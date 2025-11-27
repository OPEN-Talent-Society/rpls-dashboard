"""
Lightweight validation for the DuckDB build and core API responses.
Run: python validate.py
"""
from __future__ import annotations

import json
from pathlib import Path

import duckdb
from fastapi.testclient import TestClient

import main

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "rpls.duckdb"


def validate_tables(con: duckdb.DuckDBPyConnection):
    manifest = []
    tables = [
        r[0]
        for r in con.execute(
            "SELECT table_name FROM information_schema.tables WHERE table_schema='main'"
        ).fetchall()
    ]
    for t in tables:
        cols = [c[1] for c in con.execute(f"PRAGMA table_info('{t}')").fetchall()]
        rowcount = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        min_month = max_month = None
        if "month" in cols:
            min_month, max_month = con.execute(
                f"SELECT MIN(month), MAX(month) FROM {t}"
            ).fetchone()
        manifest.append(
            {
                "table": t,
                "rows": rowcount,
                "min_month": min_month,
                "max_month": max_month,
            }
        )
    return manifest


def validate_api(client: TestClient):
    checks = {}
    summary = client.get("/api/summary").json()
    checks["summary"] = {
        "has_headlines": bool(summary.get("headline_metrics")),
        "data_month": summary.get("data_month"),
    }

    salaries_occ = client.get("/api/salaries/occupation").json()
    salaries_state = client.get("/api/salaries/state").json()
    checks["salaries"] = {
        "occupation_count": len(salaries_occ.get("data", [])),
        "state_count": len(salaries_state.get("data", [])),
        "sample_occ_salary": salaries_occ.get("data", [{}])[0].get("salary"),
        "sample_state_salary": salaries_state.get("data", [{}])[0].get("salary"),
    }

    quad = client.get("/api/hiring-quadrant").json()
    checks["hiring_quadrant"] = {
        "sectors": len(quad.get("sectors", [])),
        "month": quad.get("month"),
    }

    top = client.get("/api/sector-spotlight").json()
    checks["spotlight"] = {
        "winners": len(top.get("winners", [])),
        "losers": len(top.get("losers", [])),
    }
    return checks


def main_validate():
    if not DB_PATH.exists():
        raise SystemExit(f"Missing DB at {DB_PATH}")

    con = duckdb.connect(str(DB_PATH), read_only=True)
    manifest = validate_tables(con)
    client = TestClient(main.app)
    api_checks = validate_api(client)

    report = {
        "db_path": str(DB_PATH),
        "tables": manifest,
        "api": api_checks,
    }
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main_validate()
