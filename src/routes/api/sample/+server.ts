import { json } from '@sveltejs/kit';
import { supabase, hasSupabaseEnv } from '$lib/supabase';

export async function GET() {
	if (!hasSupabaseEnv) {
		return json({ ok: false, error: 'Supabase env missing' }, { status: 500 });
	}

	try {
		const [{ data: layoffsTotal, error: layErr }, { data: layoffsSector, error: laySectErr }, { data: salariesOcc, error: salOccErr }] =
			await Promise.all([
				supabase
					.from('fact_layoffs')
					.select('date, employees_laidoff')
					.eq('granularity', 'total')
					.order('date', { ascending: false })
					.limit(5),
				supabase
					.from('fact_layoffs')
					.select('date, sector_id, employees_laidoff')
					.eq('granularity', 'sector')
					.order('date', { ascending: false })
					.limit(5),
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

		return json({
			ok: true,
			errors: [layErr, laySectErr, salOccErr].filter(Boolean),
			layoffs_total: layoffsTotal,
			layoffs_sector: layoffsSector?.map((r) => ({ ...r, sector_name: sectorName[r.sector_id] })),
			salaries_occ: salariesOcc?.map((r) => ({ ...r, occupation_name: occName[r.occupation_id] }))
		});
	} catch (err: any) {
		return json({ ok: false, error: err?.message ?? String(err) }, { status: 500 });
	}
}
