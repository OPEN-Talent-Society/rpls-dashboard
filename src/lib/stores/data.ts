import { writable, derived } from 'svelte/store';
import { supabase } from '$lib/supabase';
import type {
	Summary,
	OccupationSalary,
	HiringAttritionData,
	Layoff,
	LayoffsBySector,
	SectorSpotlightResult,
	TopMover
} from '$lib/types';

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

function pctChange(curr: number | null, prev: number | null): number | null {
	if (curr === null || prev === null || prev === 0) return null;
	return ((curr - prev) / prev) * 100;
}

async function getLatestTwo(table: string, filters: Record<string, string>) {
	let query = supabase.from(table).select().order('date', { ascending: false }).limit(2);
	for (const [k, v] of Object.entries(filters)) {
		query = query.eq(k, v);
	}
	const { data, error: err } = await query;
	if (err) throw err;
	return data ?? [];
}

// Data loading function (Supabase)
export async function loadAllData() {
	isLoading.set(true);
	error.set(null);

	try {
		// Summary pieces
		const [empRows, hireRows, layRows] = await Promise.all([
			getLatestTwo('fact_employment', { granularity: 'national' }),
			getLatestTwo('fact_hiring_attrition', { granularity: 'total' }),
			getLatestTwo('fact_layoffs', { granularity: 'total' })
		]);

		const latestEmp = empRows[0];
		const prevEmp = empRows[1];
		const latestHire = hireRows[0];
		const latestLay = layRows[0];
		const prevLay = layRows[1];

		const dataMonthVal = latestEmp?.date?.slice(0, 7) ?? latestHire?.date?.slice(0, 7) ?? '';

		summary.set({
			updated_at: Date.now(),
			data_month: dataMonthVal,
			health_index: 50,
			health_trend: 'stable',
			headline_metrics: {
				total_employment: latestEmp?.employment_sa ?? null,
				employment_change: latestEmp && prevEmp ? (latestEmp.employment_sa ?? 0) - (prevEmp.employment_sa ?? 0) : 0,
				hiring_rate: latestHire?.hiring_rate_sa ?? null,
				attrition_rate: latestHire?.attrition_rate_sa ?? null,
				latest_layoffs: latestLay?.employees_laidoff ?? null
			}
		});

		// Spotlight (top/bottom movers by employment sector)
		const { data: latestSector } = await supabase
			.from('fact_employment')
			.select('date, sector_id, employment_sa')
			.eq('granularity', 'sector')
			.order('date', { ascending: false })
			.limit(1000);
		const latestMonth = latestSector?.[0]?.date;
		const prevMonth = latestSector?.find((r) => r.date !== latestMonth)?.date;
		const latestMap = new Map<string, number | null>();
		const prevMap = new Map<string, number | null>();
		(latestSector ?? []).forEach((r) => {
			if (r.date === latestMonth) latestMap.set(r.sector_id, r.employment_sa);
			else if (r.date === prevMonth) prevMap.set(r.sector_id, r.employment_sa);
		});
		const movers: TopMover[] = [];
		for (const [id, val] of latestMap.entries()) {
			const prevVal = prevMap.get(id) ?? null;
			movers.push({
				dimension: id,
				value: val,
				prev_value: prevVal,
				pct_change: pctChange(val, prevVal),
				month: latestMonth,
				prev_month: prevMonth
			});
		}
		movers.sort((a, b) => (b.pct_change ?? 0) - (a.pct_change ?? 0));
		const winners = movers.slice(0, 3);
		const losers = movers.slice(-3);
		spotlight.set({ winners, losers });

		// Salaries
		const { data: salOcc } = await supabase
			.from('fact_salaries')
			.select('date, occupation_id, salary_sa')
			.eq('granularity', 'occupation')
			.order('date', { ascending: false });
		const salLatest = salOcc?.[0]?.date;
		const salPrev = salOcc?.find((r) => r.date !== salLatest)?.date;
		const occMap = new Map<string, { curr: number | null; prev: number | null }>();
		(salOcc ?? []).forEach((r) => {
			const entry = occMap.get(r.occupation_id) ?? { curr: null, prev: null };
			if (r.date === salLatest) entry.curr = r.salary_sa;
			else if (r.date === salPrev) entry.prev = r.salary_sa;
			occMap.set(r.occupation_id, entry);
		});
		const occList: OccupationSalary[] = [];
		for (const [code, vals] of occMap.entries()) {
			occList.push({
				code,
				name: code,
				salary: vals.curr,
				prev_year_salary: vals.prev,
				yoy_change: pctChange(vals.curr, vals.prev) ?? 0
			});
		}
		salariesByOccupation.set(occList);

		const { data: salState } = await supabase
			.from('fact_salaries')
			.select('date, state_id, salary_sa')
			.eq('granularity', 'state')
			.order('date', { ascending: false });
		const stateLatest = salState?.[0]?.date;
		const statePrev = salState?.find((r) => r.date !== stateLatest)?.date;
		const stateMap: Record<string, { salary: number | null; yoy_change: number | null }> = {};
		(salState ?? []).forEach((r) => {
			const curr = r.date === stateLatest;
			if (!stateMap[r.state_id]) {
				stateMap[r.state_id] = { salary: null, yoy_change: null };
			}
			if (curr) stateMap[r.state_id].salary = r.salary_sa;
			else if (r.date === statePrev) stateMap[r.state_id].yoy_change = pctChange(stateMap[r.state_id].salary, r.salary_sa);
		});
		salariesByState.set(stateMap);

		// Hiring quadrant (latest sector)
		const { data: hireSect } = await supabase
			.from('fact_hiring_attrition')
			.select('date, sector_id, hiring_rate_sa, attrition_rate_sa')
			.eq('granularity', 'sector')
			.order('date', { ascending: false });
		const hLatest = hireSect?.[0]?.date;
		const sectors = (hireSect ?? []).filter((r) => r.date === hLatest).map((r) => ({
			code: r.sector_id,
			name: r.sector_id,
			hiring_rate: r.hiring_rate_sa ?? 0,
			attrition_rate: r.attrition_rate_sa ?? 0,
			quadrant: 'stagnant' as const
		}));
		hiringAttrition.set({ month: hLatest ?? '', sectors });

		// Layoffs series + sectors
		const { data: laySeries } = await supabase
			.from('fact_layoffs')
			.select('date, employees_laidoff')
			.eq('granularity', 'total')
			.order('date', { ascending: true });
		const { data: laySect } = await supabase
			.from('fact_layoffs')
			.select('date, sector_id, employees_laidoff')
			.eq('granularity', 'sector')
			.order('date', { ascending: false });
		const layMonth = laySect?.[0]?.date;
		const laySectors = (laySect ?? [])
			.filter((r) => r.date === layMonth)
			.map((r) => ({ code: r.sector_id, name: r.sector_id, employees_laidoff: r.employees_laidoff ?? 0 }));
		layoffs.set(
			(laySeries ?? []).map((r) => ({
				month: r.date?.slice(0, 7) ?? '',
				employees_notified: null,
				notices_issued: null,
				employees_laidoff: r.employees_laidoff ?? null
			}))
		);
		layoffsBySector.set({ month: layMonth ?? '', sectors: laySectors });
	} catch (err) {
		console.error('Failed to load data:', err);
		error.set('Failed to load dashboard data. Please try again later.');
	} finally {
		isLoading.set(false);
	}
}
