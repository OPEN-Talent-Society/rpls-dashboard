
import os
from dotenv import load_dotenv
from supabase import create_client

# Load env from rpls-dashboard/.env
load_dotenv("rpls-dashboard/.env")

url = os.getenv("PUBLIC_SUPABASE_URL")
key = os.getenv("SUPABASE_SERVICE_ROLE_KEY")

if not url or not key:
    print("No credentials found")
    exit(1)

supabase = create_client(url, key)

print("--- Fact Hiring Attrition Multi (Sample) ---")
res = supabase.table("fact_hiring_attrition_multi").select("hiring_rate_sa").limit(5).execute()
print(res.data)

print("\n--- Hiring Sector Summary (Sample) ---")
res = supabase.table("hiring_sector_summary").select("*").limit(5).execute()
print(res.data)
