<script lang="ts">
	import { salariesByOccupation, salariesByState } from '$lib/stores/data';
	import { formatCurrency, formatPercentChange, getChangeColor } from '$lib/utils/format';
	import { US_STATES } from '$lib/types';

	let selectedOccupation = '';
	let selectedState = '';

	$: occupation = $salariesByOccupation.find((o) => o.code === selectedOccupation);
	$: stateData = selectedState ? $salariesByState[selectedState] : null;

	$: nationalSalary = occupation?.salary ?? null;
	$: stateSalary = stateData?.salary ?? null;

	$: comparison = nationalSalary && stateSalary
		? ((stateSalary - nationalSalary) / nationalSalary) * 100
		: null;
</script>

<div class="card">
	<h2 class="card-header">Salary Reality Check</h2>
	<p class="text-sm text-gray-600 mb-4">
		Compare salaries by occupation and location using real labor market data.
	</p>

	<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
		<!-- Occupation Select -->
		<div>
			<label for="occupation" class="block text-sm font-medium text-gray-700 mb-1">
				Occupation
			</label>
			<select
				id="occupation"
				bind:value={selectedOccupation}
				class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
			>
				<option value="">Select occupation...</option>
				{#each $salariesByOccupation as occ}
					<option value={occ.code}>{occ.name}</option>
				{/each}
			</select>
		</div>

		<!-- State Select -->
		<div>
			<label for="state" class="block text-sm font-medium text-gray-700 mb-1">
				State (Optional)
			</label>
			<select
				id="state"
				bind:value={selectedState}
				class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-primary-500 focus:border-primary-500"
			>
				<option value="">National average...</option>
				{#each US_STATES as state}
					<option value={state}>{state}</option>
				{/each}
			</select>
		</div>
	</div>

	<!-- Results -->
	{#if occupation}
		<div class="bg-gray-50 rounded-lg p-4">
			<h3 class="font-medium text-gray-800 mb-3">{occupation.name}</h3>

			<div class="grid grid-cols-1 md:grid-cols-3 gap-4">
				<!-- National Salary -->
				<div>
					<div class="metric-label">National Average</div>
					<div class="metric-value text-primary-600">
						{formatCurrency(nationalSalary)}
					</div>
					{#if occupation.yoy_change}
						<div class="text-sm {getChangeColor(occupation.yoy_change)}">
							{formatPercentChange(occupation.yoy_change * 100)} YoY
						</div>
					{/if}
				</div>

				<!-- State Salary -->
				{#if selectedState && stateData}
					<div>
						<div class="metric-label">{selectedState}</div>
						<div class="metric-value">
							{formatCurrency(stateSalary)}
						</div>
						{#if stateData.yoy_change}
							<div class="text-sm {getChangeColor(stateData.yoy_change)}">
								{formatPercentChange(stateData.yoy_change * 100)} YoY
							</div>
						{/if}
					</div>
				{/if}

				<!-- Comparison -->
				{#if comparison !== null}
					<div>
						<div class="metric-label">vs National</div>
						<div class="metric-value {getChangeColor(comparison)}">
							{formatPercentChange(comparison)}
						</div>
						<div class="text-sm text-gray-500">
							{comparison > 0 ? 'Above' : 'Below'} average
						</div>
					</div>
				{/if}
			</div>

			<!-- Insights -->
			<div class="mt-4 pt-4 border-t border-gray-200">
				<p class="text-sm text-gray-600">
					{#if comparison !== null && comparison > 10}
						<span class="font-medium text-green-600">High-paying region</span> for this role.
						Consider cost of living when evaluating opportunities.
					{:else if comparison !== null && comparison < -10}
						<span class="font-medium text-red-600">Below-average region</span> for this role.
						Remote work options may offer better compensation.
					{:else if comparison !== null}
						<span class="font-medium">Near-average compensation</span> for this region.
					{:else}
						Select a state to compare regional salary differences.
					{/if}
				</p>
			</div>
		</div>
	{:else}
		<div class="bg-gray-50 rounded-lg p-8 text-center text-gray-500">
			Select an occupation to see salary data
		</div>
	{/if}
</div>
