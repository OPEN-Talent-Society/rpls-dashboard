import { writable, derived } from 'svelte/store';
import { supabase, hasSupabaseEnv } from '$lib/supabase';
import type { FilterState } from './filters';
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

export const latestLayoffs = derived(layoffs, ($layoffs) => {
	return [...$layoffs].sort((a, b) => b.month.localeCompare(a.month)).slice(0, 3);
});

export const occupationOptions = derived(salariesByOccupation, ($salaries) =>
	$salaries.map((s) => ({ value: s.code, label: s.name, salary: s.salary }))
);

function pctChange(curr: number | null, prev: number | null): number | null {
	if (curr === null || prev === null || prev === 0) return null;
	return ((curr - prev) / prev) * 100;
}

async function getLatestTwo(
	table: string,
	filters: Record<string, string>,
	dateRange?: { start?: string; end?: string }
) {
	let query = supabase.from(table).select().order('date', { ascending: false }).limit(2);
	for (const [k, v] of Object.entries(filters)) {
		query = query.eq(k, v);
	}
	if (dateRange?.start) query = query.gte('date', `${dateRange.start}-01`);
	if (dateRange?.end) query = query.lte('date', `${dateRange.end}-31`);
	const { data, error: err } = await query;
	if (err) throw err;
	return data ?? [];
}

function dedupeBy<T extends Record<string, any>>(rows: T[], key: keyof T) {
	const seen = new Set<string>();
	return rows.filter((r) => {
		const val = r[key];
		if (seen.has(String(val))) return false;
		seen.add(String(val));
		return true;
	});
}

// Data loading function (Supabase)
export async function loadAllData(filterState: FilterState = {}) {
	isLoading.set(true);
	error.set(null);

	try {
		if (!hasSupabaseEnv) {
			throw new Error('Supabase is not configured. Please set PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY.');
		}

		// dimension lookups
		const [{ data: sectorDim }, { data: occDim }, { data: stateDim }] = await Promise.all([
			supabase.from('dim_sectors').select('id, name'),
			supabase.from('dim_occupations').select('id, name'),
			supabase.from('dim_states').select('id, name')
		]);
		const sectorName = new Map<string, string>();
		const occName = new Map<string, string>();
		const stateName = new Map<string, string>();
		(sectorDim ?? []).forEach((s) => sectorName.set(s.id, s.name ?? s.id));
		(occDim ?? []).forEach((o) => occName.set(o.id, o.name ?? o.id));
		(stateDim ?? []).forEach((s) => stateName.set(s.id, s.name ?? s.id));

		const dateFilter = (query: any, field = 'date') => {
			if (filterState.startMonth) {
				query = query.gte(field, `${filterState.startMonth}-01`);
			}
			if (filterState.endMonth) {
				query = query.lte(field, `${filterState.endMonth}-31`);
			}
			return query;
		};

		// Summary pieces
		const dateRange = { start: filterState.startMonth, end: filterState.endMonth };
		const [empRows, hireRows, layRows] = await Promise.all([
			getLatestTwo('fact_employment', { granularity: 'national' }, dateRange),
			getLatestTwo('fact_hiring_attrition', { granularity: 'total' }, dateRange),
			getLatestTwo('fact_layoffs', { granularity: 'total' }, dateRange)
		]);

		const latestEmp = empRows[0];
		const prevEmp = empRows[1];
		const latestHire = hireRows[0];
		const latestLay = layRows[0];
		const prevLay = layRows[1];

		const dataMonthVal = latestEmp?.date?.slice(0, 7) ?? latestHire?.date?.slice(0, 7) ?? '';
		const hiringRate = latestHire?.hiring_rate_sa ?? 0;
		const attritionRate = latestHire?.attrition_rate_sa ?? 0;
		const layoffsVal = latestLay?.employees_laidoff ?? 0;
		const empDelta = latestEmp && prevEmp ? (latestEmp.employment_sa ?? 0) - (prevEmp.employment_sa ?? 0) : 0;

		const healthScore = Math.max(
			0,
			Math.min(
				100,
				50 + (hiringRate - attritionRate) * 200 - Math.min(layoffsVal / 50000, 20) + Math.min(empDelta, 1_000_000) / 1_000_000 * 10
			)
		);

		summary.set({
			updated_at: Date.now(),
			data_month: dataMonthVal,
			health_index: Math.round(healthScore),
			health_trend: healthScore > 55 ? 'improving' : healthScore < 45 ? 'declining' : 'stable',
			headline_metrics: {
				total_employment: latestEmp?.employment_sa ?? null,
				employment_change: empDelta,
				hiring_rate: hiringRate || null,
				attrition_rate: attritionRate || null,
				latest_layoffs: latestLay?.employees_laidoff ?? null
			}
		});

		// Spotlight (top/bottom movers by employment sector)
		let spotlightQuery = supabase
			.from('fact_employment')
			.select('date, sector_id, employment_sa')
			.eq('granularity', 'sector')
			.order('date', { ascending: false })
			.limit(1000);
		if (filterState.sector) {
			spotlightQuery = spotlightQuery.eq('sector_id', filterState.sector);
		}
		spotlightQuery = dateFilter(spotlightQuery);
		const { data: latestSector } = await spotlightQuery;
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
				sector: sectorName.get(id) ?? id,
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
		let salOccQuery = supabase
			.from('fact_salaries')
			.select('date, occupation_id, salary_sa')
			.eq('granularity', 'occupation')
			.order('date', { ascending: false });
		if (filterState.occupation) {
			salOccQuery = salOccQuery.eq('occupation_id', filterState.occupation);
		}
		salOccQuery = dateFilter(salOccQuery);
		const { data: salOcc } = await salOccQuery;
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
				name: occName.get(code) ?? code,
				salary: vals.curr,
				prev_year_salary: vals.prev,
				yoy_change: pctChange(vals.curr, vals.prev) ?? 0
			});
		}
		salariesByOccupation.set(occList);

		let salStateQuery = supabase
			.from('fact_salaries')
			.select('date, state_id, salary_sa')
			.eq('granularity', 'state')
			.order('date', { ascending: false });
		if (filterState.state) {
			salStateQuery = salStateQuery.eq('state_id', filterState.state);
		}
		salStateQuery = dateFilter(salStateQuery);
		const { data: salState } = await salStateQuery;
		const stateLatest = salState?.[0]?.date;
		const statePrev = salState?.find((r) => r.date !== stateLatest)?.date;
		const stateMap: Record<string, { salary: number | null; yoy_change: number | null }> = {};
		(salState ?? []).forEach((r) => {
			const curr = r.date === stateLatest;
			const key = stateName.get(r.state_id) ?? r.state_id;
			if (!stateMap[key]) {
				stateMap[key] = { salary: null, yoy_change: null };
			}
			if (curr) stateMap[key].salary = r.salary_sa;
			else if (r.date === statePrev) stateMap[key].yoy_change = pctChange(stateMap[key].salary, r.salary_sa);
		});
		salariesByState.set(stateMap);

		// Hiring quadrant (latest sector)
		let hireSectQuery = supabase
			.from('fact_hiring_attrition')
			.select('date, sector_id, hiring_rate_sa, attrition_rate_sa')
			.eq('granularity', 'sector')
			.order('date', { ascending: false });
		if (filterState.sector) hireSectQuery = hireSectQuery.eq('sector_id', filterState.sector);
		hireSectQuery = dateFilter(hireSectQuery);
		const { data: hireSect } = await hireSectQuery;
		const hLatest = hireSect?.[0]?.date;
		const classifyQuadrant = (h: number, a: number) => {
			if (h >= 0.3 && a <= 0.25) return 'growth' as const;
			if (h >= 0.3 && a > 0.25) return 'churn_burn' as const;
			if (h < 0.3 && a <= 0.25) return 'stagnant' as const;
			return 'decline' as const;
		};

		const sectors = (hireSect ?? [])
			.filter((r) => r.date === hLatest)
			.map((r) => {
				const h = r.hiring_rate_sa ?? 0;
				const a = r.attrition_rate_sa ?? 0;
				return {
					code: r.sector_id,
					name: sectorName.get(r.sector_id) ?? r.sector_id,
					hiring_rate: h,
					attrition_rate: a,
					quadrant: classifyQuadrant(h, a)
				};
			});
		hiringAttrition.set({ month: hLatest ?? '', sectors });

		// Layoffs series + sectors
		let laySeriesQuery = supabase
			.from('fact_layoffs')
			.select('date, employees_laidoff')
			.eq('granularity', 'total')
			.order('date', { ascending: true });
		laySeriesQuery = dateFilter(laySeriesQuery);

		let laySectQuery = supabase
			.from('fact_layoffs')
			.select('date, sector_id, employees_laidoff')
			.eq('granularity', 'sector')
			.order('date', { ascending: false });
		if (filterState.sector) laySectQuery = laySectQuery.eq('sector_id', filterState.sector);
		laySectQuery = dateFilter(laySectQuery);

		const { data: laySeries } = await laySeriesQuery;
		const { data: laySect } = await laySectQuery;
		const layMonth = laySect?.[0]?.date;
		const laySectors = (laySect ?? [])
			.filter((r) => r.date === layMonth)
			.reduce<Map<string, { code: string; name: string; employees_laidoff: number }>>((map, r) => {
				const key = r.sector_id;
				const existing = map.get(key) ?? {
					code: r.sector_id,
					name: sectorName.get(r.sector_id) ?? r.sector_id,
					employees_laidoff: 0
				};
				existing.employees_laidoff += r.employees_laidoff ?? 0;
				map.set(key, existing);
				return map;
			}, new Map())
			.values();
		const laySectorsList = Array.from(laySectors).sort(
			(a, b) => (b.employees_laidoff ?? 0) - (a.employees_laidoff ?? 0)
		);
		const laySeriesSorted = (laySeries ?? [])
			.sort((a, b) => (b.date ?? '').localeCompare(a.date ?? ''))
			.filter((r, idx, arr) => arr.findIndex((x) => x.date === r.date) === idx);
		layoffs.set(
			laySeriesSorted.map((r) => ({
				month: r.date?.slice(0, 7) ?? '',
				employees_notified: null,
				notices_issued: null,
				employees_laidoff: r.employees_laidoff ?? null
			}))
		);
		layoffsBySector.set({ month: layMonth ?? '', sectors: laySectorsList });
	} catch (err) {
		console.error('Failed to load data:', err);
		error.set('Failed to load dashboard data. Please try again later.');
	} finally {
		isLoading.set(false);
	}
}
