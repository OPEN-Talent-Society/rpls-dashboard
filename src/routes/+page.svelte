<script lang="ts">
	import { formatNumber, formatPercent, formatMonth } from '$lib/utils/format';
	import HealthIndex from '$lib/components/HealthIndex.svelte';
	import LayoffTicker from '$lib/components/LayoffTicker.svelte';
	import SectorSpotlight from '$lib/components/SectorSpotlight.svelte';
	import HiringQuadrant from '$lib/components/HiringQuadrant.svelte';
	import SalaryCheck from '$lib/components/SalaryCheck.svelte';

    export let data;
    
    // Reactive declarations to extract data safely
    $: layoffs = data.layoffs || [];
    $: sectors = data.sectors || [];
    $: latestLayoff = layoffs[0] || {};
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
						<span class="text-stone-900 font-semibold text-sm">Live (Supabase)</span>
					</div>
				</div>
			</div>

            <!-- Headlines -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm">
                    <div class="text-xs uppercase text-stone-500 font-semibold">Latest Layoffs</div>
                    <div class="text-2xl font-bold text-red-700 mt-1">{formatNumber(latestLayoff.employees_laidoff)}</div>
                    <div class="text-xs text-stone-400 mt-1">{latestLayoff.date}</div>
                </div>
                <!-- Placeholders for other metrics until fully wired -->
                <div class="bg-white border border-stone-200 rounded-xl p-4 shadow-sm opacity-50">
                    <div class="text-xs uppercase text-stone-500 font-semibold">Hiring Rate</div>
                    <div class="text-2xl font-bold text-green-700 mt-1">--</div>
                </div>
            </div>
		</section>

		<!-- Core visuals -->
		<section class="grid grid-cols-1 lg:grid-cols-2 gap-6" id="sectors">
            <!-- Passing data to components would happen here. 
                 For now, we are just ensuring the page loads without errors using the new data prop. -->
			<LayoffTicker data={layoffs} />
		</section>

        <section class="bg-blue-50 border border-blue-100 rounded-xl p-6">
            <h3 class="font-bold text-blue-900">AI Insights (Coming Soon)</h3>
            <p class="text-blue-700 text-sm mt-2">
                Gemini analysis will appear here. Currently tracking {sectors.length} sector data points.
            </p>
        </section>

		<section id="about" class="bg-stone-100 rounded-xl p-4 text-center text-sm text-stone-500">
			Data provided by Revelio Labs. Powered by Open Talent Society.
		</section>
	</div>
</div>