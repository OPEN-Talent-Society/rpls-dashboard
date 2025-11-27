<script lang="ts">
	import { onMount } from 'svelte';
	import OccupationSelect from './OccupationSelect.svelte';
	import StateSelect from './StateSelect.svelte';
	import SalaryResult from './SalaryResult.svelte';

	let occupations: { code: string; name: string; salary: number }[] = [];
	let stateData: Record<string, { salary: number; yoy_change: number }> = {};
	let nationalAvgSalary = 0;

	let selectedOccupationCode = '';
	let selectedStateName = '';

	let loading = true;
	let error = '';

	interface SalaryResultProps {
		salary: number;
		occupationName: string;
		stateName: string;
		nationalAvg: number;
		stateAdj: number;
	}

	onMount(async () => {
		try {
			const [summaryRes, occRes, stateRes] = await Promise.all([
				fetch('/data/summary.json'),
				fetch('/data/salaries_by_occupation.json'),
				fetch('/data/salaries_by_state.json')
			]);

			const summary = await summaryRes.json();
			occupations = await occRes.json();
			stateData = await stateRes.json();
			nationalAvgSalary = summary.headline_metrics.average_salary;
		} catch (e) {
			error = 'Failed to load data.';
			console.error(e);
		} finally {
			loading = false;
		}
	});

	// Computed result
	$: selectedOccupation = occupations.find((o) => o.code === selectedOccupationCode);
	$: stateInfo = stateData[selectedStateName];

	let result: SalaryResultProps | null = null;

	$: if (selectedOccupation && stateInfo && nationalAvgSalary) {
		const occupationNationalSalary = selectedOccupation.salary;
		const stateFactor = stateInfo.salary / nationalAvgSalary;
		const estimatedSalary = occupationNationalSalary * stateFactor;

		result = {
			salary: estimatedSalary,
			occupationName: selectedOccupation.name,
			stateName: selectedStateName,
			nationalAvg: occupationNationalSalary,
			stateAdj: stateFactor
		};
	} else {
		result = null;
	}
</script>

<div class="card max-w-2xl mx-auto relative overflow-hidden group bg-white border border-stone-200 shadow-lg transition-all hover:shadow-xl">
	<div class="card-header pb-4 border-b border-stone-100 mb-6">
		<h2 class="text-2xl font-display font-bold text-brand-900">Salary Reality Check</h2>
		<span class="badge bg-brand-100 text-brand-800 border-brand-200">Live Oct 2025 Data</span>
	</div>

	{#if loading}
		<div class="flex justify-center py-12">
			<div class="animate-spin rounded-full h-8 w-8 border-b-2 border-brand-800"></div>
		</div>
	{:else if error}
		<div class="text-decline text-center py-8 font-sans font-medium">{error}</div>
	{:else}
		<div class="grid md:grid-cols-2 gap-6 mb-8">
			<OccupationSelect 
				options={occupations} 
				bind:value={selectedOccupationCode} 
			/>
			<StateSelect 
				options={Object.keys(stateData).sort()} 
				bind:value={selectedStateName} 
			/>
		</div>

		{#if result}
			<SalaryResult {...result} />
		{:else}
			<div class="mt-4 p-12 bg-stone-50 border border-dashed border-stone-300 rounded-lg text-center">
				<p class="text-stone-500 font-sans text-sm">Select a role and location to generate a market analysis.</p>
			</div>
		{/if}
	{/if}
</div>
