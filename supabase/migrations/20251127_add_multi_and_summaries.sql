-- Ensure UUID support
create extension if not exists "pgcrypto";

-- Multi-dimension fact tables
create table if not exists fact_employment_multi (
    id uuid primary key default gen_random_uuid(),
    date date not null,
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    employment_nsa numeric,
    employment_sa numeric,
    unique(date, sector_id, occupation_id, state_id)
);
create index if not exists idx_employment_multi_date on fact_employment_multi(date);

create table if not exists fact_postings_multi (
    id uuid primary key default gen_random_uuid(),
    date date not null,
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    active_postings_nsa numeric,
    active_postings_sa numeric,
    new_postings_nsa numeric,
    new_postings_sa numeric,
    removed_postings_nsa numeric,
    removed_postings_sa numeric,
    unique(date, sector_id, occupation_id, state_id)
);
create index if not exists idx_postings_multi_date on fact_postings_multi(date);

create table if not exists fact_hiring_attrition_multi (
    id uuid primary key default gen_random_uuid(),
    date date not null,
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    hiring_rate_nsa numeric,
    attrition_rate_nsa numeric,
    hiring_rate_sa numeric,
    attrition_rate_sa numeric,
    unique(date, sector_id, occupation_id, state_id)
);
create index if not exists idx_hiring_attrition_multi_date on fact_hiring_attrition_multi(date);

create table if not exists fact_salaries_multi (
    id uuid primary key default gen_random_uuid(),
    date date not null,
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    count int,
    salary_nsa numeric,
    salary_sa numeric,
    weight numeric,
    unique(date, sector_id, occupation_id, state_id)
);
create index if not exists idx_salaries_multi_date on fact_salaries_multi(date);

-- Summary / overview tables
create table if not exists summary_sector (
    sector_id text primary key references dim_sectors(id),
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    yoy numeric,
    mom numeric
);

create table if not exists summary_occupation (
    occupation_id text primary key references dim_occupations(id),
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    yoy numeric,
    mom numeric
);

create table if not exists summary_state (
    state_id text primary key references dim_states(id),
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    yoy numeric,
    mom numeric
);

create table if not exists salary_overview_naics (
    sector_id text primary key references dim_sectors(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    pct_change_yoy numeric,
    pct_change_mom numeric
);

create table if not exists salary_overview_soc (
    occupation_id text primary key references dim_occupations(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    pct_change_yoy numeric,
    pct_change_mom numeric
);

create table if not exists salary_overview_state (
    state_id text primary key references dim_states(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    pct_change_yoy numeric,
    pct_change_mom numeric
);

create table if not exists salary_overview_total (
    id text primary key default 'total',
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    pct_change_yoy numeric,
    pct_change_mom numeric
);

create table if not exists table_b_naics (
    sector_id text primary key references dim_sectors(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    diff_yoy numeric,
    diff_mom numeric
);

create table if not exists table_b_soc (
    occupation_id text primary key references dim_occupations(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    diff_yoy numeric,
    diff_mom numeric
);

create table if not exists table_b_state (
    state_id text primary key references dim_states(id),
    oct_2024 numeric,
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    diff_yoy numeric,
    diff_mom numeric
);

create table if not exists hiring_sector_summary (
    sector_id text primary key references dim_sectors(id),
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    yoy_pp numeric,
    mom_pp numeric
);

create table if not exists attrition_sector_summary (
    sector_id text primary key references dim_sectors(id),
    aug_2025 numeric,
    sep_2025 numeric,
    oct_2025 numeric,
    yoy_pp numeric,
    mom_pp numeric
);
