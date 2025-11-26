<script lang="ts">
	import { layoffs, layoffsBySector } from '$lib/stores/data';
	import { formatNumber, formatMonth, formatCompact } from '$lib/utils/format';

	$: latestLayoff = $layoffs[0];
	$: previousLayoff = $layoffs[1];

	$: change = latestLayoff && previousLayoff && previousLayoff.employees_laidoff
		? ((latestLayoff.employees_laidoff ?? 0) - previousLayoff.employees_laidoff) / previousLayoff.employees_laidoff * 100
		: null;

	$: topSectors = ($layoffsBySector?.sectors ?? []).slice(0, 5);

	// Calculate trend over last 6 months
	$: sixMonthTrend = $layoffs.slice(0, 6).reduce((sum, l) => sum + (l.employees_laidoff ?? 0), 0);
</script>

<div class="card bg-gradient-to-br from-red-50 to-white border-red-100">
	<div class="flex items-center justify-between mb-4">
		<h2 class="card-header mb-0 text-red-800">Layoff Alert</h2>
		<span class="badge badge-decline">
			<svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
				<path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
			</svg>
			WARN Data
		</span>
	</div>

	<!-- Latest Stats -->
	{#if latestLayoff}
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
			<div>
				<div class="metric-label">Month</div>
				<div class="font-semibold text-gray-800">{formatMonth(latestLayoff.month)}</div>
			</div>
			<div>
				<div class="metric-label">Layoffs</div>
				<div class="metric-value text-red-600 text-2xl">
					{formatCompact(latestLayoff.employees_laidoff)}
				</div>
			</div>
			<div>
				<div class="metric-label">Notices</div>
				<div class="font-semibold text-gray-800">
					{formatNumber(latestLayoff.notices_issued)}
				</div>
			</div>
			<div>
				<div class="metric-label">MoM Change</div>
				<div class="font-semibold {change && change > 0 ? 'text-red-600' : 'text-green-600'}">
					{change !== null ? `${change > 0 ? '+' : ''}${change.toFixed(1)}%` : 'N/A'}
				</div>
			</div>
		</div>
	{/if}

	<!-- Ticker Animation -->
	<div class="overflow-hidden bg-red-100 rounded-lg p-2 mb-4">
		<div class="ticker-animation whitespace-nowrap text-sm text-red-700">
			{#each $layoffs.slice(0, 6) as layoff}
				<span class="inline-block mx-4">
					{formatMonth(layoff.month)}: {formatCompact(layoff.employees_laidoff)} workers
				</span>
			{/each}
		</div>
	</div>

	<!-- Top Affected Sectors -->
	{#if topSectors.length > 0}
		<div class="border-t border-red-100 pt-4">
			<h3 class="text-sm font-medium text-red-800 mb-2">Most Affected Sectors</h3>
			<div class="space-y-2">
				{#each topSectors as sector}
					<div class="flex items-center justify-between text-sm">
						<span class="text-gray-700 truncate">{sector.name}</span>
						<span class="font-medium text-red-600">{formatCompact(sector.employees_laidoff)}</span>
					</div>
				{/each}
			</div>
		</div>
	{/if}

	<!-- 6-Month Summary -->
	<div class="mt-4 pt-4 border-t border-red-100">
		<div class="text-center">
			<div class="text-xs text-gray-500 uppercase">6-Month Total</div>
			<div class="text-2xl font-bold text-red-600">{formatCompact(sixMonthTrend)}</div>
			<div class="text-xs text-gray-500">workers affected</div>
		</div>
	</div>
</div>
