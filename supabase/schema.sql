-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Dimension Tables (Shared Reference Data)

-- NAICS Sectors
create table if not exists dim_sectors (
    id text primary key, -- naics2d_code (e.g., '11', '23')
    name text not null,
    description text
);

-- SOC Occupations
create table if not exists dim_occupations (
    id text primary key, -- soc2d_code (e.g., '15', '11-1021')
    name text not null,
    description text
);

-- States
create table if not exists dim_states (
    id text primary key, -- State Name (e.g., 'Alabama') or Abbreviation if available
    name text,
    abbreviation text
);

-- 2. Fact Tables (Time-Series Data)

-- Layoffs
create table if not exists fact_layoffs (
    id uuid primary key default uuid_generate_v4(),
    date date not null,
    
    -- Dimensions (Nullable because some data is Total US)
    sector_id text references dim_sectors(id),
    state_id text references dim_states(id),
    
    -- Metrics
    employees_notified int,
    notices_issued int,
    employees_laidoff int,
    
    -- Granularity tracking
    granularity text not null check (granularity in ('total', 'sector', 'state')),
    
    unique(date, sector_id, state_id, granularity)
);

-- Salaries
create table if not exists fact_salaries (
    id uuid primary key default uuid_generate_v4(),
    date date not null,
    
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    
    count int,
    salary_nsa numeric, -- Non-Seasonally Adjusted
    salary_sa numeric,  -- Seasonally Adjusted
    
    granularity text not null check (granularity in ('national', 'sector', 'occupation', 'state', 'total')),
    
    unique(date, sector_id, occupation_id, state_id, granularity)
);

-- Hiring & Attrition
create table if not exists fact_hiring_attrition (
    id uuid primary key default uuid_generate_v4(),
    date date not null,
    
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    
    hiring_rate_nsa numeric,
    attrition_rate_nsa numeric,
    hiring_rate_sa numeric,
    attrition_rate_sa numeric,
    
    granularity text not null check (granularity in ('total', 'sector', 'occupation', 'state')),
    
    unique(date, sector_id, occupation_id, state_id, granularity)
);

-- Job Postings
create table if not exists fact_postings (
    id uuid primary key default uuid_generate_v4(),
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
    
    granularity text not null check (granularity in ('total', 'sector', 'occupation', 'state')),
    
    unique(date, sector_id, occupation_id, state_id, granularity)
);

-- Employment
create table if not exists fact_employment (
    id uuid primary key default uuid_generate_v4(),
    date date not null,
    
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    
    employment_nsa numeric,
    employment_sa numeric,
    
    granularity text not null check (granularity in ('national', 'sector', 'occupation', 'state')),
    
    unique(date, sector_id, occupation_id, state_id, granularity)
);

-- Indexes for Performance
create index idx_layoffs_date on fact_layoffs(date);
create index idx_salaries_date on fact_salaries(date);
create index idx_hiring_date on fact_hiring_attrition(date);
create index idx_postings_date on fact_postings(date);
create index idx_employment_date on fact_employment(date);

-- Multi-dimension Fact Tables (sector + occupation + state)
create table if not exists fact_employment_multi (
    id uuid primary key default uuid_generate_v4(),
    date date not null,
    sector_id text references dim_sectors(id),
    occupation_id text references dim_occupations(id),
    state_id text references dim_states(id),
    employment_nsa numeric,
    employment_sa numeric,
    unique(date, sector_id, occupation_id, state_id)
);
create index idx_employment_multi_date on fact_employment_multi(date);

create table if not exists fact_postings_multi (
    id uuid primary key default uuid_generate_v4(),
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
create index idx_postings_multi_date on fact_postings_multi(date);

create table if not exists fact_hiring_attrition_multi (
    id uuid primary key default uuid_generate_v4(),
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
create index idx_hiring_attrition_multi_date on fact_hiring_attrition_multi(date);

create table if not exists fact_salaries_multi (
    id uuid primary key default uuid_generate_v4(),
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
create index idx_salaries_multi_date on fact_salaries_multi(date);

-- Summary / Overview Tables
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
