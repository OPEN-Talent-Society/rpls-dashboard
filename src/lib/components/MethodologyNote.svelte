<script lang="ts">
	import type { HeadlineMetrics } from '$lib/types';
	import { formatPercent, formatNumber } from '$lib/utils/format';

	export let healthIndex: number = 50;
	export let metrics: HeadlineMetrics | null = null;
</script>

<div class="card bg-white border border-stone-200">
	<h2 class="card-header">Methodology & Transparency</h2>
	<div class="text-sm text-stone-700 space-y-2">
		<p>
			Health Index is a composite on a 0–100 scale. Higher = stronger labor market. It combines:
		</p>
		<ul class="list-disc ml-5 space-y-1">
			<li>
				<strong>Hiring vs Attrition spread</strong>: (hiring - attrition), capped at ±10 pts, weighted ±40.
			</li>
			<li>
				<strong>Employment momentum</strong>: MoM % change in employment, weighted up to ±20.
			</li>
			<li>
				<strong>Layoff penalty</strong>: scaled by WARN layoffs (softer divisor 75k), max −20.
			</li>
		</ul>
		<p class="text-xs text-stone-500">
			Formula: 50 + spread*400 + momentum*400 (clamped ±20) − min(layoffs/75k * 20, 20), clamped 0–100.
		</p>
		<div class="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs text-stone-600">
			<div class="p-2 bg-stone-50 rounded">
				<div class="font-semibold text-stone-900">Health Index</div>
				<div class="text-lg font-bold">{healthIndex}</div>
			</div>
			<div class="p-2 bg-stone-50 rounded">
				<div class="font-semibold text-stone-900">Hiring vs Attrition</div>
				<div>{formatPercent(metrics?.hiring_rate)} vs {formatPercent(metrics?.attrition_rate)}</div>
			</div>
			<div class="p-2 bg-stone-50 rounded">
				<div class="font-semibold text-stone-900">Latest Layoffs</div>
				<div>{formatNumber(metrics?.latest_layoffs)}</div>
			</div>
		</div>
		<p class="text-xs text-stone-500">
			Data source: Supabase facts (Revelio Labs Public Labor Statistics). Values update monthly; MoM/YoY depend on available history.
		</p>
	</div>
</div>
