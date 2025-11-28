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
		yoy_change: item.yoy_change ?? null,
		mom_change: item.pct_change ?? null
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

function fallbackSectorLabel(id: string, provided?: string | null) {
	if (provided) return provided;
	const map: Record<string, string> = {
		'00': 'Unclassified',
		'31': 'Manufacturing',
		'32': 'Manufacturing',
		'33': 'Manufacturing',
		'44': 'Retail Trade',
		'45': 'Retail Trade',
		'48': 'Transportation and Warehousing',
		'49': 'Transportation and Warehousing',
		'52': 'Finance and Insurance',
		'53': 'Real Estate and Rental',
		'54': 'Professional & Technical Services',
		'55': 'Management of Companies',
		'56': 'Administrative & Support Services',
		'61': 'Educational Services',
		'62': 'Health Care & Social Assistance',
		'71': 'Arts, Entertainment & Recreation',
		'72': 'Accommodation & Food Services',
		'81': 'Other Services',
		'92': 'Public Administration',
		'99': 'Unclassified'
	};
	return map[id] ?? id;
}

async function getLatestTwo(
	table: string,
	filters: Record<string, string | undefined>,
	dateRange?: { start?: string; end?: string },
	dedupeByDate = false,
	columns = '*'
) {
	let query = supabase.from(table).select(columns).order('date', { ascending: false }).limit(dedupeByDate ? 24 : 2);
	for (const [k, v] of Object.entries(filters)) {
		if (v) query = query.eq(k, v);
	}
	if (dateRange?.start) query = query.gte('date', `${dateRange.start}-01`);
	if (dateRange?.end) query = query.lte('date', `${dateRange.end}-31`);
	const { data, error: err } = await query;
	if (err) throw err;
	const rows = (data ?? []) as any[];
	if (!dedupeByDate) return rows;
	const uniq: any[] = [];
	const seen = new Set<string>();
	for (const row of rows) {
		if (!row?.date) continue;
		if (seen.has(row.date)) continue;
		seen.add(row.date);
		uniq.push(row);
		if (uniq.length >= 2) break;
	}
	return uniq;
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

		// Summary pieces (multi tables to honor filters)
		const dateRange = { start: filterState.startMonth, end: filterState.endMonth };
		const multiFilters = {
			sector_id: filterState.sector,
			occupation_id: filterState.occupation,
			state_id: filterState.state
		};

		const empDates = await getLatestTwo('fact_employment_multi', multiFilters, dateRange, true, 'date');
		const latestEmpDate = empDates[0]?.date;
		const prevEmpDate = empDates[1]?.date;
		const hireDates = await getLatestTwo('fact_hiring_attrition_multi', multiFilters, dateRange, true, 'date');
		const latestHireDate = hireDates[0]?.date;
		const layFilters: Record<string, string | undefined> = {};
		if (filterState.sector) layFilters.sector_id = filterState.sector;
		if (!filterState.sector && filterState.state) layFilters.state_id = filterState.state;
		const layGranularity = layFilters.sector_id ? 'sector' : layFilters.state_id ? 'state' : 'total';
		const layDates = await getLatestTwo('fact_layoffs', { ...layFilters, granularity: layGranularity }, dateRange, true, 'date');
		const latestLayDate = layDates[0]?.date;
		const prevLayDate = layDates[1]?.date;

		// Aggregate employment (sum) latest and prev
		let latestEmp = null;
		let prevEmp = null;
		if (latestEmpDate) {
			let q = supabase.from('fact_employment_multi').select('employment_sa').eq('date', latestEmpDate).range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) q = q.eq(k, v);
			}
			const { data } = await q;
			latestEmp = { employment_sa: (data ?? []).reduce((s, r) => s + (r.employment_sa ?? 0), 0) };
		}
		if (prevEmpDate) {
			let q = supabase.from('fact_employment_multi').select('employment_sa').eq('date', prevEmpDate).range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) q = q.eq(k, v);
			}
			const { data } = await q;
			prevEmp = { employment_sa: (data ?? []).reduce((s, r) => s + (r.employment_sa ?? 0), 0) };
		}

		// Aggregate hiring/attrition (average)
		let latestHire = null;
		if (latestHireDate) {
			let q = supabase
				.from('fact_hiring_attrition_multi')
				.select('hiring_rate_sa, attrition_rate_sa')
				.eq('date', latestHireDate)
				.range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) q = q.eq(k, v);
			}
			const { data } = await q;
			const count = (data ?? []).length || 1;
			const sumHire = (data ?? []).reduce((s, r) => s + (r.hiring_rate_sa ?? 0), 0);
			const sumAttr = (data ?? []).reduce((s, r) => s + (r.attrition_rate_sa ?? 0), 0);
			latestHire = {
				hiring_rate_sa: sumHire / count,
				attrition_rate_sa: sumAttr / count
			};
		}

		let latestLay = null;
		let prevLay = null;
		if (latestLayDate) {
			let q = supabase
				.from('fact_layoffs')
				.select('employees_laidoff')
				.eq('granularity', layGranularity)
				.eq('date', latestLayDate);
			if (layFilters.sector_id) q = q.eq('sector_id', layFilters.sector_id);
			if (layFilters.state_id) q = q.eq('state_id', layFilters.state_id);
			const { data } = await q;
			latestLay = { employees_laidoff: (data ?? []).reduce((s, r) => s + (r.employees_laidoff ?? 0), 0) };
		}
		if (prevLayDate) {
			let q = supabase
				.from('fact_layoffs')
				.select('employees_laidoff')
				.eq('granularity', layGranularity)
				.eq('date', prevLayDate);
			if (layFilters.sector_id) q = q.eq('sector_id', layFilters.sector_id);
			if (layFilters.state_id) q = q.eq('state_id', layFilters.state_id);
			const { data } = await q;
			prevLay = { employees_laidoff: (data ?? []).reduce((s, r) => s + (r.employees_laidoff ?? 0), 0) };
		}

		const dataMonthVal = latestEmpDate?.slice(0, 7) ?? latestHireDate?.slice(0, 7) ?? '';
		const hiringRate = latestHire?.hiring_rate_sa ?? 0;
		const attritionRate = latestHire?.attrition_rate_sa ?? 0;
		const layoffsVal = latestLay?.employees_laidoff ?? 0;
		const empDelta = latestEmp && prevEmp ? (latestEmp.employment_sa ?? 0) - (prevEmp.employment_sa ?? 0) : 0;
		const empPct = pctChange(latestEmp?.employment_sa ?? null, prevEmp?.employment_sa ?? null) ?? 0;

		// Reweighted, less jumpy Health Index:
		// - Spread between hiring and attrition (capped) drives +/- 40 points.
		// - Employment momentum (MoM %) drives up to +/- 20 points.
		// - Layoffs subtract up to 20 points with a softer divisor (75k).
		const spread = Math.max(-0.1, Math.min(0.1, hiringRate - attritionRate));
		const spreadScore = spread * 400; // max ±40
		const momentumScore = Math.max(-20, Math.min(20, empPct * 400)); // pct * 400 ≈ ±20 when ±0.05
		const layPenalty = Math.min(((layoffsVal ?? 0) / 75000) * 20, 20); // softer penalty
		const rawHealth = 50 + spreadScore + momentumScore - layPenalty;
		const healthScore = Math.max(0, Math.min(100, rawHealth));

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
		// Grab distinct recent months to ensure we have latest, previous, and year-ago
		const { data: dateRows } = await supabase
			.from('fact_employment')
			.select('date')
			.eq('granularity', 'sector')
			.order('date', { ascending: false })
			.limit(36);
		const distinctMonths: string[] = [];
		for (const row of dateRows ?? []) {
			const m = row.date;
			if (!m) continue;
			if (distinctMonths.includes(m)) continue;
			distinctMonths.push(m);
		}
		const latestMonth = distinctMonths[0];
		const prevMonth = distinctMonths[1];
		const yearAgoPrefix =
			latestMonth && latestMonth.includes('-')
				? `${String(Number(latestMonth.slice(0, 4)) - 1).padStart(4, '0')}-${latestMonth.slice(5, 7)}`
				: undefined;
		const yearAgoMonth = distinctMonths.find((m) => (yearAgoPrefix ? m.startsWith(yearAgoPrefix) : false));

		let spotlightMonthQuery = supabase
			.from('fact_employment')
			.select('date, sector_id, employment_sa')
			.eq('granularity', 'sector')
			.order('date', { ascending: false });
		if (filterState.sector) {
			spotlightMonthQuery = spotlightMonthQuery.eq('sector_id', filterState.sector);
		}
		const monthFilter = [latestMonth, prevMonth, yearAgoMonth].filter(Boolean) as string[];
		if (monthFilter.length) {
			spotlightMonthQuery = spotlightMonthQuery.in('date', monthFilter);
		}
		const { data: latestSector } = await spotlightMonthQuery.limit(500);
		const latestMap = new Map<string, number | null>();
		const prevMap = new Map<string, number | null>();
		const yearAgoMap = new Map<string, number | null>();
		(latestSector ?? []).forEach((r) => {
			if (r.date === latestMonth) latestMap.set(r.sector_id, r.employment_sa);
			else if (r.date === prevMonth) prevMap.set(r.sector_id, r.employment_sa);
			else if (r.date === yearAgoMonth) yearAgoMap.set(r.sector_id, r.employment_sa);
		});
		const movers: TopMover[] = [];
		for (const [id, val] of latestMap.entries()) {
			const prevVal = prevMap.get(id) ?? null;
			const yearAgoVal = yearAgoMap.get(id) ?? null;
			const momChange = pctChange(val, prevVal);
			const yoyChange = pctChange(val, yearAgoVal);
			movers.push({
				dimension: id,
				sector: fallbackSectorLabel(id, sectorName.get(id)),
				value: val,
				prev_value: prevVal,
				pct_change: momChange,
				yoy_change: yoyChange,
				year_ago_value: yearAgoVal,
				month: latestMonth,
				prev_month: prevMonth
			});
		}
		movers.sort((a, b) => (b.pct_change ?? 0) - (a.pct_change ?? 0));
		const winners = movers.slice(0, 3);
		const losers = movers.slice(-3);
		spotlight.set({ winners, losers });

		// Salaries
		let salOcc: any[] | null = null;
		if (filterState.sector || filterState.state) {
			const salDates = await getLatestTwo('fact_salaries_multi', multiFilters, dateRange, true, 'date');
			const salDate = salDates[0]?.date;
			const salPrevDate = salDates[1]?.date;
			let salMultiQuery = supabase
				.from('fact_salaries_multi')
				.select('date, occupation_id, salary_sa, count')
				.eq('date', salDate)
				.range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) salMultiQuery = salMultiQuery.eq(k, v);
			}
			const { data: salMulti } = await salMultiQuery;
			let salPrevQuery = supabase
				.from('fact_salaries_multi')
				.select('date, occupation_id, salary_sa, count')
				.eq('date', salPrevDate ?? null)
				.range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) salPrevQuery = salPrevQuery.eq(k, v);
			}
			const { data: salPrevData } = salPrevQuery ? await salPrevQuery : { data: [] };
			salOcc = [...(salMulti ?? []), ...(salPrevData ?? [])];
		} else {
			let salOccQuery = supabase
				.from('fact_salaries')
				.select('date, occupation_id, salary_sa')
				.eq('granularity', 'occupation')
				.order('date', { ascending: false });
			if (filterState.occupation) {
				salOccQuery = salOccQuery.eq('occupation_id', filterState.occupation);
			}
			salOccQuery = dateFilter(salOccQuery);
			const { data } = await salOccQuery;
			salOcc = data;
		}
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

		let salState: any[] | null = null;
		if (filterState.sector || filterState.occupation) {
			const salDates = await getLatestTwo('fact_salaries_multi', multiFilters, dateRange, true, 'date');
			const salDate = salDates[0]?.date;
			const salPrevDate = salDates[1]?.date;
			let salStateQuery = supabase
				.from('fact_salaries_multi')
				.select('date, state_id, salary_sa')
				.eq('date', salDate)
				.range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) salStateQuery = salStateQuery.eq(k, v);
			}
			const { data: curr } = await salStateQuery;
			let salPrevQuery = supabase
				.from('fact_salaries_multi')
				.select('date, state_id, salary_sa')
				.eq('date', salPrevDate ?? null)
				.range(0, 200000);
			for (const [k, v] of Object.entries(multiFilters)) {
				if (v) salPrevQuery = salPrevQuery.eq(k, v);
			}
			const { data: prev } = salPrevQuery ? await salPrevQuery : { data: [] };
			salState = [...(curr ?? []), ...(prev ?? [])];
		} else {
			let salStateQuery = supabase
				.from('fact_salaries')
				.select('date, state_id, salary_sa')
				.eq('granularity', 'state')
				.order('date', { ascending: false });
			if (filterState.state) {
				salStateQuery = salStateQuery.eq('state_id', filterState.state);
			}
			salStateQuery = dateFilter(salStateQuery);
			const { data } = await salStateQuery;
			salState = data;
		}
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
					name: fallbackSectorLabel(r.sector_id, sectorName.get(r.sector_id)),
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
