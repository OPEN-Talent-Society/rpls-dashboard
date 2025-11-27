import { describe, it, expect, vi, beforeEach } from 'vitest';

type Builder = {
	table: string;
	data: any[];
	error: any;
	eqCalls: Array<[string, any]>;
	gteCalls: Array<[string, any]>;
	lteCalls: Array<[string, any]>;
	select: () => Builder;
	order: () => Builder;
	limit: () => Builder;
	eq: (col: string, val: any) => Builder;
	gte: (col: string, val: any) => Builder;
	lte: (col: string, val: any) => Builder;
};

const builders: Record<string, Builder[]> = {};

function makeBuilder(table: string): Builder {
	const builder: any = {
		table,
		data: [],
		error: null,
		eqCalls: [] as Array<[string, any]>,
		gteCalls: [] as Array<[string, any]>,
		lteCalls: [] as Array<[string, any]>,
		select() {
			return this;
		},
		order() {
			return this;
		},
		limit() {
			return this;
		},
		eq(col: string, val: any) {
			this.eqCalls.push([col, val]);
			return this;
		},
		gte(col: string, val: any) {
			this.gteCalls.push([col, val]);
			return this;
		},
		lte(col: string, val: any) {
			this.lteCalls.push([col, val]);
			return this;
		}
	};
	if (!builders[table]) builders[table] = [];
	builders[table].push(builder);
	return builder;
}

vi.mock('$lib/supabase', () => ({
	hasSupabaseEnv: true,
	supabase: {
		from: (table: string) => makeBuilder(table)
	}
}));

import { loadAllData } from '$lib/stores/data';

describe('loadAllData filtering', () => {
	beforeEach(() => {
		for (const key of Object.keys(builders)) {
			delete builders[key];
		}
	});

	it('applies sector filter to sector queries', async () => {
		await loadAllData({ sector: 'tech' });
		const hireBuilders = builders['fact_hiring_attrition'] || [];
		expect(hireBuilders.some((b) => b.eqCalls.some(([c, v]) => c === 'sector_id' && v === 'tech'))).toBe(true);
		const layBuilders = builders['fact_layoffs'] || [];
		expect(layBuilders.some((b) => b.eqCalls.some(([c, v]) => c === 'sector_id' && v === 'tech'))).toBe(true);
	});

	it('applies date range to queries', async () => {
		await loadAllData({ startMonth: '2023-01', endMonth: '2023-02' });
		const empBuilders = builders['fact_employment'] || [];
		expect(empBuilders.some((b) => b.gteCalls.some(([c]) => c === 'date'))).toBe(true);
		expect(empBuilders.some((b) => b.lteCalls.some(([c]) => c === 'date'))).toBe(true);
	});
});
