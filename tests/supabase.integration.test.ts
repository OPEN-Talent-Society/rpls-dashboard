import { createClient } from '@supabase/supabase-js';
import { describe, it, expect } from 'vitest';

const SUPABASE_URL = process.env.PUBLIC_SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.PUBLIC_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SUPABASE_KEY) {
	describe.skip('supabase live data', () => {
		it('skipped because env vars are missing', () => {
			expect(true).toBe(true);
		});
	});
} else {
	const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

	describe('supabase live data', () => {
		it(
			'should have dimension rows',
			async () => {
				const [sectors, occupations, states] = await Promise.all([
					supabase.from('dim_sectors').select('id', { count: 'exact', head: true }),
					supabase.from('dim_occupations').select('id', { count: 'exact', head: true }),
					supabase.from('dim_states').select('id', { count: 'exact', head: true })
				]);
				expect(sectors.error).toBeNull();
				expect((sectors.count ?? 0) > 0).toBe(true);
				expect(occupations.error).toBeNull();
				expect((occupations.count ?? 0) > 0).toBe(true);
				expect(states.error).toBeNull();
				expect((states.count ?? 0) > 0).toBe(true);
			},
			15_000
		);

		it(
			'should have fact rows and latest month',
			async () => {
				const { data, error } = await supabase
					.from('fact_employment')
					.select('date', { count: 'exact' })
					.order('date', { ascending: false })
					.limit(1);
				expect(error).toBeNull();
				expect((data?.length ?? 0) > 0).toBe(true);
				expect(data?.[0]?.date).toBeTruthy();
			},
			15_000
		);

		it(
			'should have layoffs totals',
			async () => {
				const { data, error } = await supabase
					.from('fact_layoffs')
					.select('employees_laidoff')
					.eq('granularity', 'total')
					.order('date', { ascending: false })
					.limit(1);
				expect(error).toBeNull();
				expect((data?.length ?? 0) > 0).toBe(true);
			},
			15_000
		);
	});
}
