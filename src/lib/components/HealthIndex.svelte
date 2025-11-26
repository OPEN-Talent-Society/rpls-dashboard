<script lang="ts">
	import { healthIndex, healthTrend, dataMonth } from '$lib/stores/data';
	import { formatMonth, getTrendIcon } from '$lib/utils/format';

	$: trendIcon = getTrendIcon($healthTrend);
	$: trendText = $healthTrend === 'improving' ? 'Improving' : $healthTrend === 'declining' ? 'Declining' : 'Stable';
</script>

<div class="card">
	<div class="flex items-center justify-between mb-4">
		<h2 class="card-header mb-0">Labor Market Health Index</h2>
		<span class="text-sm text-gray-500">{formatMonth($dataMonth)}</span>
	</div>

	<div class="flex items-center gap-8">
		<!-- Gauge Display -->
		<div class="relative w-32 h-32">
			<svg viewBox="0 0 100 100" class="w-full h-full">
				<!-- Background arc -->
				<path
					d="M 10 50 A 40 40 0 1 1 90 50"
					fill="none"
					stroke="#e5e7eb"
					stroke-width="8"
					stroke-linecap="round"
				/>
				<!-- Colored arc based on health index -->
				<path
					d="M 10 50 A 40 40 0 1 1 90 50"
					fill="none"
					stroke="url(#healthGradient)"
					stroke-width="8"
					stroke-linecap="round"
					stroke-dasharray="{$healthIndex * 1.26} 126"
				/>
				<defs>
					<linearGradient id="healthGradient" x1="0%" y1="0%" x2="100%" y2="0%">
						<stop offset="0%" stop-color="#ef4444" />
						<stop offset="50%" stop-color="#eab308" />
						<stop offset="100%" stop-color="#22c55e" />
					</linearGradient>
				</defs>
			</svg>
			<div class="absolute inset-0 flex items-center justify-center">
				<span class="text-4xl font-bold">{$healthIndex}</span>
			</div>
		</div>

		<!-- Stats -->
		<div class="flex-1">
			<div class="flex items-center gap-2 mb-2">
				<span class="text-2xl">{trendIcon}</span>
				<span class="text-lg font-medium {$healthTrend === 'improving' ? 'text-green-600' : $healthTrend === 'declining' ? 'text-red-600' : 'text-gray-600'}">
					{trendText}
				</span>
			</div>
			<p class="text-sm text-gray-600">
				{#if $healthIndex >= 70}
					Strong labor market conditions with healthy hiring activity.
				{:else if $healthIndex >= 50}
					Moderate labor market conditions with balanced dynamics.
				{:else if $healthIndex >= 30}
					Weakening labor market with elevated concerns.
				{:else}
					Challenging labor market conditions requiring attention.
				{/if}
			</p>
		</div>
	</div>

	<!-- Legend -->
	<div class="mt-4 pt-4 border-t border-gray-100">
		<div class="health-gradient h-2 rounded-full mb-2"></div>
		<div class="flex justify-between text-xs text-gray-500">
			<span>0 - Critical</span>
			<span>50 - Moderate</span>
			<span>100 - Strong</span>
		</div>
	</div>
</div>
