import { render, screen, fireEvent } from '@testing-library/svelte';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { layoffs, salariesByOccupation, salariesByState } from '$lib/stores/data';
import LayoffChart from '$lib/components/LayoffChart.svelte';
import SalaryCheck from '$lib/components/SalaryCheck.svelte';
import { tick } from 'svelte';

// Avoid real Chart.js/canvas work in tests
vi.mock('chart.js/auto', () => {
	return {
		default: class {
			constructor() {}
			update() {}
			destroy() {}
		}
	};
});

describe('Dashboard components (mocked Supabase data)', () => {
	beforeEach(() => {
		layoffs.set([
			{ month: '2024-03', employees_laidoff: 120, employees_notified: null, notices_issued: null },
			{ month: '2024-02', employees_laidoff: 80, employees_notified: null, notices_issued: null }
		]);

		salariesByOccupation.set([
			{ code: '11-0000', name: 'Management', salary: 120000, prev_year_salary: 110000, yoy_change: 9 },
			{ code: '15-0000', name: 'Computer & Math', salary: 105000, prev_year_salary: 100000, yoy_change: 5 }
		]);

		salariesByState.set({
			California: { salary: 130000, yoy_change: 4 },
			Texas: { salary: 95000, yoy_change: 3 }
		});
	});

	it('renders layoff chart summary with provided data', async () => {
		render(LayoffChart, { props: { data: [
			{ month: '2024-01', employees_laidoff: 50, employees_notified: null, notices_issued: null },
			{ month: '2024-02', employees_laidoff: 80, employees_notified: null, notices_issued: null },
			{ month: '2024-03', employees_laidoff: 120, employees_notified: null, notices_issued: null }
		] } });

		expect(screen.getByText(/Layoff Trend/i)).toBeInTheDocument();
		expect(screen.getByText(/Latest Month/i)).toBeInTheDocument();
		expect(screen.getAllByText(/2024-03/).length).toBeGreaterThan(0);
		expect(screen.getByText(/Total workers affected/i)).toBeInTheDocument();
	});

	it('renders salary check and responds to selections', async () => {
		render(SalaryCheck);
		await tick();

		const occupationSelect = screen.getByLabelText('Occupation');
		await fireEvent.change(occupationSelect, { target: { value: '11-0000' } });

		const stateSelect = screen.getByLabelText('State (Optional)');
		await fireEvent.change(stateSelect, { target: { value: 'California' } });

		expect(screen.getAllByText('Management')[0]).toBeInTheDocument();
		expect(screen.getAllByText(/National Average/i).length).toBeGreaterThan(0);
		expect(screen.getByText(/vs National/i)).toBeInTheDocument();
	});
});
