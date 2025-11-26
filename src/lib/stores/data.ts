import { writable, derived } from 'svelte/store';
import type {
	Summary,
	Sector,
	OccupationSalary,
	HiringAttritionData,
	Layoff,
	LayoffsBySector,
	EmploymentTrend,
	HiringTrend
} from '$lib/types';

// Loading state
export const isLoading = writable(true);
export const error = writable<string | null>(null);

// Raw data stores
export const summary = writable<Summary | null>(null);
export const sectors = writable<Sector[]>([]);
export const salariesByOccupation = writable<OccupationSalary[]>([]);
export const salariesByState = writable<Record<string, { salary: number | null; yoy_change: number }>>({});
export const hiringAttrition = writable<HiringAttritionData | null>(null);
export const layoffs = writable<Layoff[]>([]);
export const layoffsBySector = writable<LayoffsBySector | null>(null);
export const employmentTrends = writable<EmploymentTrend[]>([]);
export const hiringTrends = writable<HiringTrend[]>([]);

// Derived stores
export const healthIndex = derived(summary, ($summary) => $summary?.health_index ?? 50);
export const healthTrend = derived(summary, ($summary) => $summary?.health_trend ?? 'stable');
export const dataMonth = derived(summary, ($summary) => $summary?.data_month ?? '');

export const topSectors = derived(sectors, ($sectors) =>
	$sectors.slice(0, 6)
);

export const latestLayoffs = derived(layoffs, ($layoffs) =>
	$layoffs.slice(0, 3)
);

export const occupationOptions = derived(salariesByOccupation, ($salaries) =>
	$salaries.map((s) => ({ value: s.code, label: s.name, salary: s.salary }))
);

// Data loading function
export async function loadAllData() {
	isLoading.set(true);
	error.set(null);

	try {
		const base = '/data';

		const [
			summaryRes,
			sectorsRes,
			salariesSocRes,
			salariesStateRes,
			hiringAttritionRes,
			layoffsRes,
			layoffsSectorRes,
			empTrendsRes,
			hiringTrendsRes
		] = await Promise.all([
			fetch(`${base}/summary.json`),
			fetch(`${base}/sectors.json`),
			fetch(`${base}/salaries_by_occupation.json`),
			fetch(`${base}/salaries_by_state.json`),
			fetch(`${base}/hiring_attrition.json`),
			fetch(`${base}/layoffs.json`),
			fetch(`${base}/layoffs_by_sector.json`),
			fetch(`${base}/employment_trends.json`),
			fetch(`${base}/hiring_trends.json`)
		]);

		// Parse all responses
		summary.set(await summaryRes.json());
		sectors.set(await sectorsRes.json());
		salariesByOccupation.set(await salariesSocRes.json());
		salariesByState.set(await salariesStateRes.json());
		hiringAttrition.set(await hiringAttritionRes.json());
		layoffs.set(await layoffsRes.json());
		layoffsBySector.set(await layoffsSectorRes.json());
		employmentTrends.set(await empTrendsRes.json());
		hiringTrends.set(await hiringTrendsRes.json());

	} catch (err) {
		console.error('Failed to load data:', err);
		error.set('Failed to load dashboard data. Please try again later.');
	} finally {
		isLoading.set(false);
	}
}
