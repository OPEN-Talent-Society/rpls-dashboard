<script lang="ts">
	import { onMount } from 'svelte';
	import {
		loadAllData,
		isLoading,
		error,
		summary,
		healthIndex,
		healthTrend,
		dataMonth
	} from '$lib/stores/data';
	import { formatNumber, formatPercent, formatMonth } from '$lib/utils/format';
	import HealthIndex from '$lib/components/HealthIndex.svelte';
	import LayoffTicker from '$lib/components/LayoffTicker.svelte';
	import SectorSpotlight from '$lib/components/SectorSpotlight.svelte';
	import HiringQuadrant from '$lib/components/HiringQuadrant.svelte';
	import SalaryCheck from '$lib/components/SalaryCheck.svelte';

	onMount(() => {
		loadAllData();
	});
</script>

<svelte:head>
	<title>RPLS Dashboard - Labor Market Pulse</title>
	<meta name="description" content="Real-time labor market intelligence powered by Revelio Labs Public Labor Statistics." />
</svelte:head>

<div class="min-h-screen bg-stone-50">
	<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-10 space-y-12">
		<!-- Hero -->
		<section id="dashboard" class="space-y-4">
			<div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
				<div>
					<p class="text-xs font-semibold text-stone-500 uppercase tracking-widest">Labor Market Pulse</p>
					<h1 class="text-4xl md:text-5xl font-extrabold text-stone-900 leading-tight">US Jobs Dashboard</h1>
					<p class="text-stone-600 mt-2">
						Signals from employment, postings, hiring, attrition, salaries, and WARN layoffs.
						{#if $dataMonth}
							<span class="text-stone-400"> Data as of {formatMonth($dataMonth)}</span>
						{/if}
					</p>
				</div>
				<div class="text-right">
					<div class="text-xs font-bold text-stone-400 uppercase tracking-widest mb-1">System Status</div>
					<div class="flex items-center justify-end gap-2">
						<span class="w-2 h-2 rounded-full bg-green-500"></span>
						<span class="text-stone-900 font-semibold text-sm">Live</span>
					</div>
				</div>
			</div>

			{#if $isLoading}
				<div class="bg-white border border-stone-200 rounded-xl p-6 shadow-sm">
					<p class="text-stone-500">Loading labor market data…</p>
				</div>
			{:else if $error}
				<div class="bg-red-50 border border-red-200 text-red-800 rounded-xl p-6 shadow-sm">
					<p>{$error}</p>
					<button class="mt-4 px-4 py-2 bg-red-600 text-white rounded" on:click={loadAllData}>Retry</button>
				</div>
			{:else}
				<!-- Headline metrics -->
				{#if $summary?.headline_metrics}
					<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
						<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
							<div class="text-xs uppercase text-stone-500 font-semibold">Total Employment</div>
							<div class="text-2xl font-bold text-stone-900 mt-1">{formatNumber($summary.headline_metrics.total_employment)}</div>
						</div>
						<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
							<div class="text-xs uppercase text-stone-500 font-semibold">Hiring Rate</div>
							<div class="text-2xl font-bold text-green-700 mt-1">{formatPercent($summary.headline_metrics.hiring_rate)}</div>
						</div>
						<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
							<div class="text-xs uppercase text-stone-500 font-semibold">Attrition Rate</div>
							<div class="text-2xl font-bold text-amber-700 mt-1">{formatPercent($summary.headline_metrics.attrition_rate)}</div>
						</div>
						<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
							<div class="text-xs uppercase text-stone-500 font-semibold">Latest Layoffs</div>
							<div class="text-2xl font-bold text-red-700 mt-1">{formatNumber($summary.headline_metrics.latest_layoffs)}</div>
						</div>
					</div>
				{/if}
			{/if}
		</section>

		<!-- Core visuals -->
		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6" id="sectors">
			<HealthIndex />
			<LayoffTicker />
		</section>

		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6">
			<SectorSpotlight />
			<HiringQuadrant />
		</section>

		<!-- Salary Comparison -->
		<section id="salary">
			<SalaryCheck />
		</section>

		<section id="about" class="bg-blue-50 border border-blue-100 rounded-xl p-4 text-center text-sm text-blue-800">
			Data from Revelio Labs Public Labor Statistics. Updated monthly. API base: http://127.0.0.1:9055
		</section>
	</div>
</div>
