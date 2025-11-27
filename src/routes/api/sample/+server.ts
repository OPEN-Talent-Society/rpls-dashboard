import { json } from '@sveltejs/kit';
import { supabase, hasSupabaseEnv } from '$lib/supabase';

export async function GET() {
	if (!hasSupabaseEnv) {
		return json({ ok: false, error: 'Supabase env missing' }, { status: 500 });
	}

	try {
		const [
			{ data: layoffsTotal, error: layErr },
			{ data: layoffsSector, error: laySectErr },
			{ data: salariesOcc, error: salOccErr }
		] = await Promise.all([
			supabase
				.from('fact_layoffs')
				.select('date, employees_laidoff')
				.eq('granularity', 'total')
				.order('date', { ascending: false })
				.limit(15),
			supabase
				.from('fact_layoffs')
				.select('date, sector_id, employees_laidoff')
				.eq('granularity', 'sector')
				.order('date', { ascending: false })
				.limit(250),
			supabase
				.from('fact_salaries')
				.select('date, occupation_id, salary_sa')
				.eq('granularity', 'occupation')
				.order('date', { ascending: false })
				.limit(5)
		]);

		const [{ data: dimSectors }, { data: dimOcc }] = await Promise.all([
			supabase.from('dim_sectors').select('id, name'),
			supabase.from('dim_occupations').select('id, name')
		]);
		const sectorName = Object.fromEntries((dimSectors ?? []).map((s) => [s.id, s.name ?? s.id]));
		const occName = Object.fromEntries((dimOcc ?? []).map((o) => [o.id, o.name ?? o.id]));

		const uniqueTotals: { date: string | null; employees_laidoff: number | null }[] = [];
		const seenDates = new Set<string>();
		for (const row of layoffsTotal ?? []) {
			if (!row?.date) continue;
			if (seenDates.has(row.date)) continue;
			seenDates.add(row.date);
			uniqueTotals.push(row);
		}

		const latestSectorDate = layoffsSector?.[0]?.date;
		const sectorRows = (layoffsSector ?? []).filter((row) => row.date === latestSectorDate);
		const aggregatedSectors = sectorRows.reduce<Map<string, { date: string | null; sector_id: string; employees_laidoff: number }>>(
			(map, row) => {
				const id = row.sector_id;
				if (!id) return map;
				const existing = map.get(id) ?? { date: row.date ?? null, sector_id: id, employees_laidoff: 0 };
				existing.employees_laidoff += row.employees_laidoff ?? 0;
				map.set(id, existing);
				return map;
			},
			new Map()
		);

		return json({
			ok: true,
			errors: [layErr, laySectErr, salOccErr].filter(Boolean),
			layoffs_total: uniqueTotals.slice(0, 5),
			layoffs_sector: Array.from(aggregatedSectors?.values() ?? [])
				.sort((a, b) => (b.employees_laidoff ?? 0) - (a.employees_laidoff ?? 0))
				.slice(0, 5)
				.map((r) => ({
					...r,
					sector_name: sectorName[r.sector_id] ?? r.sector_id
				})),
			salaries_occ: salariesOcc?.map((r) => ({ ...r, occupation_name: occName[r.occupation_id] }))
		});
	} catch (err: any) {
		return json({ ok: false, error: err?.message ?? String(err) }, { status: 500 });
	}
}
