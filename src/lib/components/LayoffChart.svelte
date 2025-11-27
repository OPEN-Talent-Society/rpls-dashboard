<script lang="ts">
	import { onMount, onDestroy } from 'svelte';
	import {
		Chart,
		LineController,
		LineElement,
		PointElement,
		LinearScale,
		CategoryScale,
		Tooltip,
		Legend
	} from 'chart.js';
	import { formatCompact } from '$lib/utils/format';
	import type { Layoff } from '$lib/types';

	Chart.register(LineController, LineElement, PointElement, LinearScale, CategoryScale, Tooltip, Legend);

	export let data: Layoff[] = [];
	export let loading = false;

	let canvas: HTMLCanvasElement | null = null;
	let chart: Chart<'line'> | null = null;

	// Keep chart chronological while stores keep latest-first ordering
	$: chronological = [...data].sort((a, b) => a.month.localeCompare(b.month));
	const labels = () => chronological.map((d) => d.month);
	const values = () => chronological.map((d) => d.employees_laidoff ?? 0);

	function updateChart() {
		if (!chart) return;
		chart.data.labels = labels();
		chart.data.datasets[0].data = values();
		chart.update();
	}

	onMount(() => {
		if (!canvas || typeof window === 'undefined') return;
		const ctx = canvas.getContext('2d');
		if (!ctx) return;

		chart = new Chart(ctx, {
			type: 'line',
			data: {
				labels: labels(),
				datasets: [
					{
						label: 'Employees laid off',
						data: values(),
						borderColor: '#ef4444',
						backgroundColor: 'rgba(239, 68, 68, 0.15)',
						tension: 0.25,
						fill: true,
						pointRadius: 4
					}
				]
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				plugins: {
					legend: { display: false },
					tooltip: {
						callbacks: {
							label: (ctx) => `${ctx.label}: ${formatCompact(Number(ctx.raw))} workers`
						}
					}
				},
				scales: {
					x: {
						title: { display: true, text: 'Month' }
					},
					y: {
						title: { display: true, text: 'Laid off' },
						beginAtZero: true
					}
				}
			}
		});
	});

	onDestroy(() => chart?.destroy());

	$: if (chart && data.length) {
		updateChart();
	}

	$: latest = data[0];
	$: sixMonthTotal = data.slice(0, 6).reduce((sum, l) => sum + (l.employees_laidoff ?? 0), 0);
</script>

<div class="card">
	<div class="flex items-center justify-between mb-4">
		<h2 class="card-header mb-0">Layoff Trend</h2>
		{#if latest}
			<span class="text-sm text-gray-500">Latest Month: {latest.month}</span>
		{/if}
	</div>

	{#if loading}
		<div class="h-64 flex items-center justify-center text-gray-400">Loading layoffs…</div>
	{:else if data.length === 0}
		<div class="h-64 flex items-center justify-center text-gray-400">No layoff data available</div>
	{:else}
		<div class="h-64">
			<canvas bind:this={canvas}></canvas>
		</div>

		<div class="mt-4 pt-4 border-t border-gray-100 grid grid-cols-1 md:grid-cols-2 gap-4">
			<div>
				<div class="text-xs uppercase text-gray-500">Latest Reading</div>
				<div class="text-2xl font-bold text-red-600">{formatCompact(latest?.employees_laidoff ?? 0)}</div>
				<div class="text-sm text-gray-500">workers affected in {latest?.month}</div>
			</div>
			<div>
				<div class="text-xs uppercase text-gray-500">6-Month Total</div>
				<div class="text-2xl font-bold text-red-600">{formatCompact(sixMonthTotal)}</div>
				<div class="text-sm text-gray-500">Total workers affected</div>
			</div>
		</div>
	{/if}
</div>
