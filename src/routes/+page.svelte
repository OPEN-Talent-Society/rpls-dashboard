<script lang="ts">
	import { onMount } from 'svelte';
	import { loadAllData, isLoading, error, summary } from '$lib/stores/data';
	import { formatNumber, formatPercent, formatMonth } from '$lib/utils/format';
	import HealthIndex from '$lib/components/HealthIndex.svelte';
	import SalaryCheck from '$lib/components/SalaryCheck.svelte';
	import SectorSpotlight from '$lib/components/SectorSpotlight.svelte';
	import LayoffTicker from '$lib/components/LayoffTicker.svelte';
	import HiringQuadrant from '$lib/components/HiringQuadrant.svelte';

	onMount(() => {
		loadAllData();
	});
</script>

<svelte:head>
	<title>RPLS Dashboard - Labor Market Intelligence</title>
	<meta name="description" content="Real-time labor market intelligence powered by Revelio Labs data. Track employment, salaries, hiring trends, and layoffs across the US economy." />
</svelte:head>

{#if $isLoading}
	<div class="flex items-center justify-center min-h-96">
		<div class="text-center">
			<div class="w-12 h-12 border-4 border-primary-200 border-t-primary-600 rounded-full animate-spin mx-auto mb-4"></div>
			<p class="text-gray-600">Loading labor market data...</p>
		</div>
	</div>
{:else if $error}
	<div class="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
		<svg class="w-12 h-12 text-red-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
			<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
		</svg>
		<h3 class="text-lg font-medium text-red-800 mb-2">Unable to Load Data</h3>
		<p class="text-red-600">{$error}</p>
		<button on:click={() => loadAllData()} class="btn btn-primary mt-4">
			Try Again
		</button>
	</div>
{:else}
	<!-- Page Header -->
	<div class="mb-8">
		<h1 class="text-3xl font-bold text-gray-900">Labor Market Pulse</h1>
		<p class="text-gray-600 mt-1">
			Real-time insights into US labor market conditions
			{#if $summary?.data_month}
				<span class="text-gray-400">| Data as of {formatMonth($summary.data_month)}</span>
			{/if}
		</p>
	</div>

	<!-- Quick Stats Bar -->
	{#if $summary?.headline_metrics}
		<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
			<div class="bg-white rounded-lg p-4 shadow-sm border border-gray-100">
				<div class="metric-label">Total Employment</div>
				<div class="text-2xl font-bold text-gray-900">
					{formatNumber($summary.headline_metrics.total_employment)}
				</div>
			</div>
			<div class="bg-white rounded-lg p-4 shadow-sm border border-gray-100">
				<div class="metric-label">Hiring Rate</div>
				<div class="text-2xl font-bold text-green-600">
					{formatPercent($summary.headline_metrics.hiring_rate)}
				</div>
			</div>
			<div class="bg-white rounded-lg p-4 shadow-sm border border-gray-100">
				<div class="metric-label">Attrition Rate</div>
				<div class="text-2xl font-bold text-amber-600">
					{formatPercent($summary.headline_metrics.attrition_rate)}
				</div>
			</div>
			<div class="bg-white rounded-lg p-4 shadow-sm border border-gray-100">
				<div class="metric-label">Recent Layoffs</div>
				<div class="text-2xl font-bold text-red-600">
					{formatNumber($summary.headline_metrics.latest_layoffs)}
				</div>
			</div>
		</div>
	{/if}

	<!-- Main Dashboard Grid -->
	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
		<!-- Health Index -->
		<HealthIndex />

		<!-- Layoff Alert -->
		<LayoffTicker />
	</div>

	<div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-6">
		<!-- Sector Spotlight -->
		<SectorSpotlight />

		<!-- Hiring vs Attrition Quadrant -->
		<HiringQuadrant />
	</div>

	<!-- Full Width Salary Check -->
	<div class="mb-6">
		<SalaryCheck />
	</div>

	<!-- Data Source Attribution -->
	<div class="bg-blue-50 border border-blue-100 rounded-lg p-4 text-center">
		<p class="text-sm text-blue-700">
			<strong>Open Source Labor Market Data</strong> - This dashboard uses
			<a href="https://www.reveliolabs.com/product/rpls/" target="_blank" rel="noopener" class="underline">
				Revelio Labs Public Labor Statistics
			</a>
			covering 100M+ US workforce profiles. Data is updated monthly.
		</p>
	</div>
{/if}
