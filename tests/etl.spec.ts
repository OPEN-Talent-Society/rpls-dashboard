import fs from 'fs';
import path from 'path';
import { parse } from 'csv-parse/sync';
import { describe, it, expect } from 'vitest';

const candidates = [
	path.resolve(__dirname, '..', 'rpls_data'),
	path.resolve(__dirname, '..', '..', 'rpls_data')
];

const DATA_DIR = candidates.find((p) => fs.existsSync(p)) ?? candidates[0];
const hasData = fs.existsSync(DATA_DIR);

const toNumber = (value: string | number | null | undefined) => {
	if (value === null || value === undefined) return null;
	const cleaned = String(value).replace(/[$,]/g, '').trim();
	if (cleaned === '') return null;
	const num = Number(cleaned);
	return Number.isFinite(num) ? num : null;
};

describe.skipIf(!hasData)('ETL CSV parsing (filesystem only)', () => {
	it('parses salary CSV rows into numeric values', () => {
		const csv = fs.readFileSync(path.join(DATA_DIR, 'salaries_soc.csv'), 'utf8');
		const rows = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
		expect(rows.length).toBeGreaterThan(0);

		const sample = rows.slice(0, 200);
		for (const row of sample) {
			expect(row.soc2d_code || row.occupation_id || row.soc).toBeTruthy();
			expect(row.month).toMatch(/^\d{4}-\d{2}/);
			const count = toNumber(row.count);
			const salary = toNumber(row.salary_sa);
			expect(count).not.toBeNull();
			expect(salary).not.toBeNull();
		}
	});

	it('finds min/max months in employment file', () => {
		const csv = fs.readFileSync(path.join(DATA_DIR, 'employment_national.csv'), 'utf8');
		const rows = parse(csv, { columns: true, skip_empty_lines: true }) as Record<string, string>[];
		expect(rows.length).toBeGreaterThan(0);

		const months = rows.map((r) => r.month).filter(Boolean);
		expect(months.length).toBeGreaterThan(0);

		const sorted = [...months].sort();
		expect(sorted[0]).toMatch(/^\d{4}-\d{2}/);
		expect(sorted[sorted.length - 1]).toMatch(/^\d{4}-\d{2}/);
	});
});
