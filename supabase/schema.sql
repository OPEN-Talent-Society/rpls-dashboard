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
