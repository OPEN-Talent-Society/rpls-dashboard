"""
RPLS Dashboard - ETL Pipeline (DuckDB -> Supabase)
--------------------------------------------------
This script:
1. Loads raw CSV data into an in-memory DuckDB instance.
2. Cleans, transforms, and normalizes the data using SQL.
3. Pushes the structured data to Supabase (Postgres).

Usage:
    export SUPABASE_URL=...
    export SUPABASE_KEY=...
    python etl_supabase.py
"""

import os
import glob
import duckdb
from supabase import create_client, Client
from pathlib import Path
from dotenv import load_dotenv
import pandas as pd
import numpy as np

# Load environment variables
env_path = Path(__file__).resolve().parent.parent / '.env'
load_dotenv(dotenv_path=env_path)

SUPABASE_URL = os.getenv("PUBLIC_SUPABASE_URL") # Changed to match .env keys
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY") # Use Service Role for ETL
DATA_DIR = Path(__file__).resolve().parents[2] / "rpls_data_extracted"

if not SUPABASE_URL or not SUPABASE_KEY:
    print(f"⚠️  WARNING: Credentials not found in {env_path}. Running in Dry-Run mode.")
    DRY_RUN = True
else:
    # supabase-py requires the URL and Key
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
    DRY_RUN = False

def get_csv_path(pattern: str) -> str:
    """Finds a CSV file matching the pattern in the data directory."""
    files = glob.glob(str(DATA_DIR / pattern))
    if not files:
        raise FileNotFoundError(f"No file matches pattern: {pattern} in {DATA_DIR}")
    return files[0]

def clean_currency_sql(col_name):
    return f"TRY_CAST(REPLACE(REPLACE({col_name}, '$', ''), ',', '') AS DECIMAL)"

def clean_percent_sql(col_name):
    return f"TRY_CAST(REPLACE(REPLACE({col_name}, '%', ''), '+', '') AS DECIMAL) / 100.0"

def run_etl():
    con = duckdb.connect(database=':memory:')
    
    print(f"📂 Loading data from: {DATA_DIR}")

    # ==========================================
    # 1. Dimensions
    # ==========================================
    print("Processing Dimensions...")
    
    # DIM_SECTORS (from salaries_naics.csv)
    path = get_csv_path("salaries_naics.csv")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE raw_sectors AS SELECT * FROM read_csv_auto('{path}', all_varchar=True);
        SELECT DISTINCT 
            naics2d_code as id, 
            naics2d_name as name 
        FROM raw_sectors 
        WHERE naics2d_code != '00'
    """)
    sectors = con.fetchall()
    upload_to_supabase("dim_sectors", ["id", "name"], sectors)

    # DIM_OCCUPATIONS (from salaries_soc.csv)
    path = get_csv_path("salaries_soc.csv")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE raw_soc AS SELECT * FROM read_csv_auto('{path}', all_varchar=True);
        SELECT DISTINCT 
            soc2d_code as id, 
            soc2d_name as name 
        FROM raw_soc 
        WHERE soc2d_code != '0'
    """)
    occupations = con.fetchall()
    upload_to_supabase("dim_occupations", ["id", "name"], occupations)

    # DIM_STATES (from salaries_state.csv)
    path = get_csv_path("salaries_state.csv")
    con.execute(f"""
        CREATE OR REPLACE TEMP TABLE raw_states AS SELECT * FROM read_csv_auto('{path}', all_varchar=True);
        SELECT DISTINCT state as id, state as name FROM raw_states
    """)
    states = con.fetchall()
    upload_to_supabase("dim_states", ["id", "name"], states)


    # ==========================================
    # 2. Fact Tables
    # ==========================================
    
    # FACT_LAYOFFS (Total, NAICS, State)
    print("Processing Layoffs...")
    # We load all 3 files and union them
    f_total = get_csv_path("total_layoffs.csv")
    f_naics = get_csv_path("layoffs_by_naics.csv")
    f_state = get_csv_path("layoffs_by_state.csv")
    
    query = f"""
        SELECT 
            month || '-01' as date,
            NULL as sector_id,
            NULL as state_id,
            TRY_CAST(num_employees_notified AS INT) as employees_notified,
            TRY_CAST(num_notices_issued AS INT) as notices_issued,
            TRY_CAST(num_employees_laidoff AS INT) as employees_laidoff,
            'total' as granularity
        FROM read_csv_auto('{f_total}', all_varchar=True)
        
        UNION ALL
        
        SELECT 
            month || '-01' as date,
            naics2d as sector_id,
            NULL as state_id,
            TRY_CAST(num_employees_notified AS INT),
            TRY_CAST(num_notices_issued AS INT),
            TRY_CAST(num_employees_laidoff AS INT),
            'sector' as granularity
        FROM read_csv_auto('{f_naics}', all_varchar=True)
        
        UNION ALL
        
        SELECT 
            month || '-01' as date,
            NULL as sector_id,
            state as state_id,
            TRY_CAST(num_employees_notified AS INT),
            TRY_CAST(num_notices_issued AS INT),
            TRY_CAST(num_employees_laidoff AS INT),
            'state' as granularity
        FROM read_csv_auto('{f_state}', all_varchar=True)
    """
    con.execute(query)
    layoffs = con.fetchall()
    # Columns: date, sector_id, state_id, employees_notified, notices_issued, employees_laidoff, granularity
    cols = ["date", "sector_id", "state_id", "employees_notified", "notices_issued", "employees_laidoff", "granularity"]
    upload_to_supabase("fact_layoffs", cols, layoffs)

    # FACT_SALARIES
    print("Processing Salaries...")
    # Example for NAICS, SOC, State, National
    f_sal_naics = get_csv_path("salaries_naics.csv")
    f_sal_soc = get_csv_path("salaries_soc.csv")
    
    query = f"""
        SELECT 
            month || '-01' as date,
            naics2d_code as sector_id,
            NULL as occupation_id,
            NULL as state_id,
            TRY_CAST(count as INT) as count,
            {clean_currency_sql('salary_nsa')} as salary_nsa,
            {clean_currency_sql('salary_sa')} as salary_sa,
            'sector' as granularity
        FROM read_csv_auto('{f_sal_naics}', all_varchar=True)
        
        UNION ALL
        
        SELECT 
            month || '-01' as date,
            NULL as sector_id,
            soc2d_code as occupation_id,
            NULL as state_id,
            TRY_CAST(count as INT) as count,
            {clean_currency_sql('salary_nsa')} as salary_nsa,
            {clean_currency_sql('salary_sa')} as salary_sa,
            'occupation' as granularity
        FROM read_csv_auto('{f_sal_soc}', all_varchar=True)
    """
    con.execute(query)
    salaries = con.fetchall()
    cols = ["date", "sector_id", "occupation_id", "state_id", "count", "salary_nsa", "salary_sa", "granularity"]
    upload_to_supabase("fact_salaries", cols, salaries)

    # Add other fact tables similarly (Postings, Hiring, etc.)
    # For brevity in this artifact, I am implementing the core ones. 
    # You can extend this pattern easily.

    print("✅ ETL Complete.")

import pandas as pd
import numpy as np

def upload_to_supabase(table_name, columns, query_result):
    """
    Uploads data to Supabase using Pandas for robust type conversion.
    query_result: Result from DuckDB (can be a list of tuples or a DF if we change the caller)
    But here we assume the caller passed 'data_rows' which is a list of tuples.
    Actually, let's change the caller to pass the connection and query, or just handle the list.
    """
    if not query_result:
        print(f"  ⚠️ No data for {table_name}")
        return
        
    # Convert list of tuples to DataFrame
    df = pd.DataFrame(query_result, columns=columns)
    
    # 1. Convert Decimals to Floats
    # Select object columns that might be Decimals and convert
    for col in df.select_dtypes(include=['object']).columns:
        try:
            df[col] = df[col].astype(float)
        except (ValueError, TypeError):
            pass # Keep as string if it fails (e.g. IDs)

    # 2. Handle NaNs (Supabase expects null)
    df = df.replace({np.nan: None})
    
    records = df.to_dict(orient='records')
    
    if DRY_RUN:
        print(f"  [DRY RUN] Would insert {len(records)} rows into {table_name}")
        return

    # Batch insert
    batch_size = 1000
    for i in range(0, len(records), batch_size):
        batch = records[i:i+batch_size]
        try:
            supabase.table(table_name).upsert(batch).execute()
            print(f"  Inserted {len(batch)} rows into {table_name}")
        except Exception as e:
            msg = str(e)
            if "Could not find the table" in msg or "PGRST205" in msg:
                 print(f"  ❌ ERROR: Table '{table_name}' does not exist in Supabase.")
                 print(f"     ACTION REQUIRED: Run 'rpls-dashboard/supabase/schema.sql' in your Supabase SQL Editor.")
                 return # Stop trying for this table
            else:
                print(f"  ❌ Error inserting into {table_name}: {e}")

if __name__ == "__main__":
    run_etl()
