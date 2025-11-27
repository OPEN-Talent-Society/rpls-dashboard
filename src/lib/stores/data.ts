import { writable, derived } from 'svelte/store';
import type {
	Summary,
	OccupationSalary,
	HiringAttritionData,
	Layoff,
	LayoffsBySector,
	LayoffsSummary,
	SectorSpotlightResult,
	TopMover
} from '$lib/types';

const API_BASE = import.meta.env.VITE_API_BASE || (typeof window !== 'undefined' ? window.location.origin : '');

// Loading state
export const isLoading = writable(true);
export const error = writable<string | null>(null);

// Raw data stores
export const summary = writable<Summary | null>(null);
export const spotlight = writable<SectorSpotlightResult | null>(null);
export const salariesByOccupation = writable<OccupationSalary[]>([]);
export const salariesByState = writable<Record<string, { salary: number | null; yoy_change: number | null }>>({});
export const hiringAttrition = writable<HiringAttritionData | null>(null);
export const layoffs = writable<Layoff[]>([]);
export const layoffsBySector = writable<LayoffsBySector | null>(null);

// Derived stores
export const healthIndex = derived(summary, ($summary) => $summary?.health_index ?? 50);
export const healthTrend = derived(summary, ($summary) => $summary?.health_trend ?? 'stable');
export const dataMonth = derived(summary, ($summary) => $summary?.data_month ?? '');

export const topSectors = derived(spotlight, ($spotlight) => {
	if (!$spotlight) return [];
	const items: TopMover[] = [...$spotlight.winners, ...$spotlight.losers];
	return items.map((item) => ({
		name: item.sector ?? item.dimension,
		current_postings: item.value ?? 0,
		prev_month_postings: item.prev_value ?? 0,
		yoy_change: item.pct_change ?? 0,
		mom_change: item.pct_change ?? 0
	}));
});

export const latestLayoffs = derived(layoffs, ($layoffs) => $layoffs.slice(0, 3));

export const occupationOptions = derived(salariesByOccupation, ($salaries) =>
	$salaries.map((s) => ({ value: s.code, label: s.name, salary: s.salary }))
);

async function getJSON<T>(path: string, init?: RequestInit): Promise<T> {
	const res = await fetch(`${API_BASE}${path}`, init);
	if (!res.ok) {
		throw new Error(`${path} failed with ${res.status}`);
	}
	return res.json();
}

// Data loading function
export async function loadAllData() {
	isLoading.set(true);
	error.set(null);

	try {
		const [summaryRes, spotlightRes, salariesOccRes, salariesStateRes, hiringQuadRes, layoffsSummary] =
			await Promise.all([
				getJSON<Summary>('/api/summary'),
				getJSON<SectorSpotlightResult>('/api/sector-spotlight'),
				getJSON<{ month: string; prev_month: string; data: any[] }>('/api/salaries/occupation'),
				getJSON<{ month: string; prev_month: string; data: any[] }>('/api/salaries/state'),
				getJSON<HiringAttritionData>('/api/hiring-quadrant'),
				getJSON<LayoffsSummary>('/api/layoffs-summary')
			]);

		summary.set(summaryRes);
		spotlight.set(spotlightRes);
		salariesByOccupation.set(
			salariesOccRes.data.map((row) => ({
				code: row.code,
				name: row.name,
				salary: row.salary,
				prev_year_salary: row.prev_salary,
				yoy_change: row.yoy_change ?? 0
			}))
		);
		const stateMap: Record<string, { salary: number | null; yoy_change: number | null }> = {};
		for (const row of salariesStateRes.data) {
			stateMap[row.state] = { salary: row.salary, yoy_change: row.yoy_change ?? null };
		}
		salariesByState.set(stateMap);
		hiringAttrition.set(hiringQuadRes);

		// Layoffs series for ticker
		const layoffSeries = [...(layoffsSummary.series || [])].reverse().map((row) => ({
			month: row.month,
			employees_notified: null,
			notices_issued: null,
			employees_laidoff: row.employees_laidoff
		}));
		layoffs.set(layoffSeries);
		layoffsBySector.set({
			month: layoffsSummary.month,
			sectors: layoffsSummary.sectors
		});
	} catch (err) {
		console.error('Failed to load data:', err);
		error.set('Failed to load dashboard data. Please try again later.');
	} finally {
		isLoading.set(false);
	}
}
