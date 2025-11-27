import { json } from '@sveltejs/kit';
import { supabase, hasSupabaseEnv } from '$lib/supabase';

export async function GET() {
	if (!hasSupabaseEnv) {
		return json({ ok: false, error: 'Supabase env missing' }, { status: 500 });
	}

	try {
		const [dimSectors, dimOcc, dimStates, empLatest, layLatest] = await Promise.all([
			supabase.from('dim_sectors').select('id', { count: 'exact', head: true }),
			supabase.from('dim_occupations').select('id', { count: 'exact', head: true }),
			supabase.from('dim_states').select('id', { count: 'exact', head: true }),
			supabase.from('fact_employment').select('date', { count: 'exact' }).order('date', { ascending: false }).limit(1),
			supabase.from('fact_layoffs').select('date', { count: 'exact' }).order('date', { ascending: false }).limit(1).eq('granularity', 'total')
		]);

		return json({
			ok: true,
			dim_counts: {
				sectors: dimSectors.count ?? 0,
				occupations: dimOcc.count ?? 0,
				states: dimStates.count ?? 0
			},
			facts: {
				employment_latest: empLatest.data?.[0]?.date ?? null,
				employment_rows: empLatest.count ?? null,
				layoffs_latest: layLatest.data?.[0]?.date ?? null,
				layoffs_rows: layLatest.count ?? null
			},
			errors: [dimSectors.error, dimOcc.error, dimStates.error, empLatest.error, layLatest.error].filter(Boolean)
		});
	} catch (err: any) {
		return json({ ok: false, error: err?.message ?? String(err) }, { status: 500 });
	}
}
