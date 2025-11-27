<script lang="ts">
	import { onMount } from 'svelte';
	import { browser } from '$app/environment';
	import { page } from '$app/stores';
	import { formatNumber } from '$lib/utils/format';
	import HealthIndex from '$lib/components/HealthIndex.svelte';
	import LayoffTicker from '$lib/components/LayoffTicker.svelte';
	import SectorSpotlight from '$lib/components/SectorSpotlight.svelte';
	import HiringQuadrant from '$lib/components/HiringQuadrant.svelte';
	import SalaryCheck from '$lib/components/SalaryCheck.svelte';
	import LayoffChart from '$lib/components/LayoffChart.svelte';
	import {
		loadAllData,
		isLoading,
		error,
		summary,
		layoffs,
		hiringAttrition,
		spotlight
	} from '$lib/stores/data';
	import { filters, serializeFilters, parseFilters, updateFilters } from '$lib/stores/filters';
	import DataDebugPanel from '$lib/components/DataDebugPanel.svelte';

	let initialized = false;

	onMount(() => {
		if (browser) {
			const parsed = parseFilters(window.location.search);
			updateFilters(parsed);
		}
		initialized = true;
	});

	$: if (initialized) {
		loadAllData($filters);
		if (browser) {
			const search = serializeFilters($filters);
			const url = new URL(window.location.href);
			url.search = search.replace(/^\?/, '');
			window.history.replaceState({}, '', url.toString());
		}
	}

	$: headline = $summary?.headline_metrics;
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
					</p>
				</div>
				<div class="text-right">
					<div class="text-xs font-bold text-stone-400 uppercase tracking-widest mb-1">System Status</div>
					<div class="flex items-center justify-end gap-2">
						<span class="w-2 h-2 rounded-full bg-green-500"></span>
						<span class="text-stone-900 font-semibold text-sm">
							{$isLoading ? 'Loading data…' : 'Live (Supabase)'}
						</span>
					</div>
				</div>
			</div>

			{#if $error}
				<div class="bg-red-50 border border-red-200 text-red-800 rounded-lg p-4">
					{$error}
				</div>
			{/if}

			<!-- Headlines -->
			<div class="grid grid-cols-2 md:grid-cols-4 gap-4">
				<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
					<div class="text-xs uppercase text-stone-500 font-semibold">Total Employment</div>
					<div class="text-2xl font-bold text-stone-900 mt-1">
						{formatNumber(headline?.total_employment)}
					</div>
					<div class="text-xs text-stone-400 mt-1">MoM change {formatNumber(headline?.employment_change)}</div>
				</div>
				<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
					<div class="text-xs uppercase text-stone-500 font-semibold">Hiring Rate</div>
					<div class="text-2xl font-bold text-green-700 mt-1">
						{headline?.hiring_rate ? `${(headline.hiring_rate * 100).toFixed(1)}%` : '--'}
					</div>
				</div>
				<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
					<div class="text-xs uppercase text-stone-500 font-semibold">Attrition Rate</div>
					<div class="text-2xl font-bold text-amber-700 mt-1">
						{headline?.attrition_rate ? `${(headline.attrition_rate * 100).toFixed(1)}%` : '--'}
					</div>
				</div>
				<div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
					<div class="text-xs uppercase text-stone-500 font-semibold">Latest Layoffs</div>
					<div class="text-2xl font-bold text-red-700 mt-1">
						{formatNumber(headline?.latest_layoffs)}
					</div>
					<div class="text-xs text-stone-400 mt-1">Recent WARN filings</div>
				</div>
			</div>
		</section>

		<!-- Core visuals -->
		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6" id="sectors">
			<HealthIndex />
			<LayoffTicker />
		</section>

		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6">
			<LayoffChart data={$layoffs} loading={$isLoading} />
			<SectorSpotlight />
		</section>

		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6">
			<HiringQuadrant />
			<SalaryCheck />
		</section>

		<DataDebugPanel />

		<section id="about" class="bg-stone-100 rounded-xl p-4 text-center text-sm text-stone-500">
			Data provided by Revelio Labs. Powered by Open Talent Society.
		</section>
	</div>
</div>
