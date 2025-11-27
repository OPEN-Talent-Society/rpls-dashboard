import { describe, it, expect } from 'vitest';
import { filters, parseFilters, serializeFilters, resetFilters, updateFilters } from '$lib/stores/filters';

describe('Filter store', () => {
	it('serializes and parses filters round-trip', () => {
		const state = {
			startMonth: '2023-01',
			endMonth: '2023-06',
			sector: 'tech',
			occupation: '11-0000',
			state: 'California'
		};
		const search = serializeFilters(state);
		expect(search).toContain('start=2023-01');
		expect(search).toContain('sector=tech');
		const parsed = parseFilters(search);
		expect(parsed).toEqual(state);
	});

	it('updates and resets filters', async () => {
		updateFilters({ sector: 'finance' });
		let value;
		filters.subscribe((v) => (value = v))();
		expect(value.sector).toBe('finance');
		resetFilters();
		filters.subscribe((v) => (value = v))();
		expect(value.sector).toBeUndefined();
	});

	it('ignores empty search params', () => {
		const parsed = parseFilters('');
		expect(parsed).toEqual({
			startMonth: undefined,
			endMonth: undefined,
			sector: undefined,
			occupation: undefined,
			state: undefined
		});
	});
});
