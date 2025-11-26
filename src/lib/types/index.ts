// Data Types for RPLS Dashboard

export interface Summary {
	updated_at: string;
	data_month: string;
	health_index: number;
	health_trend: 'improving' | 'stable' | 'declining';
	headline_metrics: HeadlineMetrics;
	top_sectors_by_postings: Sector[];
	recent_layoffs: Layoff[];
}

export interface HeadlineMetrics {
	total_employment: number | null;
	employment_change: number;
	hiring_rate: number | null;
	attrition_rate: number | null;
	latest_layoffs: number | null;
	total_sectors: number;
	total_occupations: number;
}

export interface Sector {
	name: string;
	current_postings: number;
	prev_month_postings: number;
	yoy_change: number | null;
	mom_change: number | null;
}

export interface OccupationSalary {
	code: string;
	name: string;
	salary: number | null;
	prev_year_salary: number | null;
	yoy_change: number;
}

export interface StateSalary {
	salary: number | null;
	yoy_change: number;
}

export interface HiringAttritionData {
	month: string;
	sectors: SectorHiringAttrition[];
}

export interface SectorHiringAttrition {
	code: string;
	name: string;
	hiring_rate: number;
	attrition_rate: number;
	quadrant: 'growth' | 'churn_burn' | 'stagnant' | 'decline';
}

export interface Layoff {
	month: string;
	employees_notified: number | null;
	notices_issued: number | null;
	employees_laidoff: number | null;
}

export interface LayoffsBySector {
	month: string;
	sectors: SectorLayoff[];
}

export interface SectorLayoff {
	code: string;
	name: string;
	employees_laidoff: number;
}

export interface EmploymentTrend {
	month: string;
	employment_nsa: number;
	employment_sa: number;
}

export interface HiringTrend {
	month: string;
	hiring_rate: number;
	attrition_rate: number;
}

// Quadrant classification
export type QuadrantType = 'growth' | 'churn_burn' | 'stagnant' | 'decline';

export const QUADRANT_LABELS: Record<QuadrantType, string> = {
	growth: 'High Growth',
	churn_burn: 'Churn & Burn',
	stagnant: 'Stagnant',
	decline: 'Decline'
};

export const QUADRANT_COLORS: Record<QuadrantType, string> = {
	growth: '#22c55e',
	churn_burn: '#f59e0b',
	stagnant: '#6b7280',
	decline: '#ef4444'
};

// US States for dropdown
export const US_STATES = [
	'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California',
	'Colorado', 'Connecticut', 'Delaware', 'Florida', 'Georgia',
	'Hawaii', 'Idaho', 'Illinois', 'Indiana', 'Iowa',
	'Kansas', 'Kentucky', 'Louisiana', 'Maine', 'Maryland',
	'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi', 'Missouri',
	'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
	'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
	'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
	'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont',
	'Virginia', 'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
	'District of Columbia'
] as const;
