<script lang="ts">
	import { onMount } from 'svelte';
	import { hiringAttrition } from '$lib/stores/data';
	import { formatPercent, formatMonth } from '$lib/utils/format';
import { QUADRANT_COLORS, QUADRANT_LABELS, type QuadrantType } from '$lib/types';
import Chart from 'chart.js/auto';

let canvas: HTMLCanvasElement;
let chart: Chart | null = null;

const QUADRANT_ENTRIES = Object.entries(QUADRANT_LABELS) as [QuadrantType, string][];

	// Thresholds for quadrant lines
	const HIRING_THRESHOLD = 0.28;
	const ATTRITION_THRESHOLD = 0.26;

	$: sectors = $hiringAttrition?.sectors ?? [];

	$: if (chart && sectors.length > 0) {
		updateChart();
	}

	function updateChart() {
		if (!chart) return;

		chart.data.datasets[0].data = sectors.map((s) => ({
			x: s.hiring_rate * 100,
			y: s.attrition_rate * 100,
			label: s.name,
			quadrant: s.quadrant
		}));

		chart.update();
	}

	onMount(() => {
		if (!canvas) return;

		chart = new Chart(canvas, {
			type: 'scatter',
			data: {
				datasets: [
					{
						label: 'Sectors',
						data: sectors.map((s) => ({
							x: s.hiring_rate * 100,
							y: s.attrition_rate * 100,
							label: s.name,
							quadrant: s.quadrant
						})),
						backgroundColor: (ctx) => {
							const point = ctx.raw as { quadrant: QuadrantType };
							return QUADRANT_COLORS[point?.quadrant] ?? '#6b7280';
						},
						pointRadius: 8,
						pointHoverRadius: 12
					}
				]
			},
			options: {
				responsive: true,
				maintainAspectRatio: false,
				scales: {
					x: {
						title: {
							display: true,
							text: 'Hiring Rate (%)',
							font: { weight: 'bold' }
						},
						min: 10,
						max: 50,
						grid: {
							color: (ctx) => ctx.tick.value === HIRING_THRESHOLD * 100 ? '#94a3b8' : '#e5e7eb'
						}
					},
					y: {
						title: {
							display: true,
							text: 'Attrition Rate (%)',
							font: { weight: 'bold' }
						},
						min: 10,
						max: 50,
						grid: {
							color: (ctx) => ctx.tick.value === ATTRITION_THRESHOLD * 100 ? '#94a3b8' : '#e5e7eb'
						}
					}
				},
				plugins: {
					tooltip: {
						callbacks: {
							label: (ctx) => {
								const point = ctx.raw as { label: string; x: number; y: number; quadrant: QuadrantType };
								return [
									point.label,
									`Hiring: ${point.x.toFixed(1)}%`,
									`Attrition: ${point.y.toFixed(1)}%`,
									`Status: ${QUADRANT_LABELS[point.quadrant]}`
								];
							}
						}
					},
					legend: {
						display: false
					}
				}
			},
			plugins: [
				{
					id: 'quadrantLines',
					beforeDraw: (chart) => {
						const ctx = chart.ctx;
						const xAxis = chart.scales.x;
						const yAxis = chart.scales.y;

						// Vertical line at hiring threshold
						const xPos = xAxis.getPixelForValue(HIRING_THRESHOLD * 100);
						ctx.save();
						ctx.strokeStyle = '#94a3b8';
						ctx.lineWidth = 2;
						ctx.setLineDash([5, 5]);
						ctx.beginPath();
						ctx.moveTo(xPos, yAxis.top);
						ctx.lineTo(xPos, yAxis.bottom);
						ctx.stroke();

						// Horizontal line at attrition threshold
						const yPos = yAxis.getPixelForValue(ATTRITION_THRESHOLD * 100);
						ctx.beginPath();
						ctx.moveTo(xAxis.left, yPos);
						ctx.lineTo(xAxis.right, yPos);
						ctx.stroke();
						ctx.restore();

						// Quadrant labels
						ctx.font = '11px sans-serif';
						ctx.fillStyle = '#9ca3af';
						ctx.textAlign = 'center';

						// Top-left: Decline
						ctx.fillText('DECLINE', xAxis.left + 40, yAxis.top + 20);
						// Top-right: Churn & Burn
						ctx.fillText('CHURN & BURN', xAxis.right - 50, yAxis.top + 20);
						// Bottom-left: Stagnant
						ctx.fillText('STAGNANT', xAxis.left + 40, yAxis.bottom - 10);
						// Bottom-right: Growth
						ctx.fillText('GROWTH', xAxis.right - 40, yAxis.bottom - 10);
					}
				}
			]
		});

		return () => {
			chart?.destroy();
		};
	});
</script>

<div class="card">
	<div class="flex items-center justify-between mb-4">
		<h2 class="card-header mb-0">Hiring vs Attrition</h2>
		{#if $hiringAttrition?.month}
			<span class="text-sm text-gray-500">{formatMonth($hiringAttrition.month)}</span>
		{/if}
	</div>

	<div class="h-80">
		<canvas bind:this={canvas}></canvas>
	</div>

	<!-- Legend -->
	<div class="mt-4 pt-4 border-t border-gray-100">
		<div class="flex flex-wrap gap-4 justify-center">
			{#each QUADRANT_ENTRIES as [key, label]}
				<div class="flex items-center gap-2">
					<span
						class="w-3 h-3 rounded-full"
						style={`background-color: ${QUADRANT_COLORS[key]}`}
					></span>
					<span class="text-sm text-gray-600">{label}</span>
				</div>
			{/each}
		</div>
	</div>
</div>
