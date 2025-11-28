# RPLS Data Catalog (from Revelio Labs Public Labor Statistics)

Source landing: https://www.reveliolabs.com/public-labor-statistics/

## Core CSVs (currently loaded to Supabase)
- Employment: `employment_national.csv`, `employment_naics.csv`, `employment_soc.csv`, `employment_state.csv`
- Layoffs: `total_layoffs.csv`, `layoffs_by_naics.csv`, `layoffs_by_state.csv`
- Hiring & Attrition: `hiring_and_attrition_total_us.csv`, `hiring_and_attrition_by_sector.csv`, `hiring_and_attrition_by_occupation.csv`, `hiring_and_attrition_by_state.csv`
- Salaries: `salaries_national.csv`, `salaries_naics.csv`, `salaries_soc.csv`, `salaries_state.csv`
- Postings: `postings_total_us.csv`, `postings_by_sector.csv`, `postings_by_occupation.csv`, `postings_by_state.csv`
- Dimensions: `dim_sectors`, `dim_occupations`, `dim_states` (NAICS names normalized)

## High-volume CSVs (not yet loaded)
- Employment: `employment_all_granularities.csv`
- Salaries: `salaries_all_granularities.csv`
- Hiring/Attrition: `hiring_and_attrition_by_sector_occupation_state.csv`
- Postings: `postings_by_sector_occupation_state.csv`

## Summary/overview CSVs (not yet loaded)
- Hiring/Attrition summaries: `hiring_*_summary.csv`, `attrition_*_summary.csv`
- Salary overviews: `salary_overview_*`
- Sector/occupation/state summaries: `sector_summary.csv`, `occupation_summary.csv`, `state_summary.csv`
- Table B: `table_b_naics.csv`, `table_b_soc.csv`, `table_b_state.csv`
- BLS revisions: `bls_revisions.csv`
- Combined: `employment_all_granularities.csv`, `salaries_all_granularities.csv`

## Supabase table mapping (current vs planned)
- Loaded: `fact_employment`, `fact_layoffs`, `fact_hiring_attrition`, `fact_salaries`, `fact_postings` (+ dims)
- Planned additions:
  - `fact_employment_all` (from employment_all_granularities.csv)
  - `fact_salaries_all`
  - `fact_hiring_attrition_multi`
  - `fact_postings_multi`
  - Summary tables (`summary_hiring`, `summary_attrition`, `summary_salary`, `summary_sector`, `summary_state`, `summary_occupation`, `table_b_*`)

## Notes on coverage
- YoY gaps appear where year-ago rows are absent in source CSVs (e.g., certain sectors). MoM is complete for latest months.
- Health index inputs are derived from latest available hiring/attrition (total), employment (national), and layoffs (total).
