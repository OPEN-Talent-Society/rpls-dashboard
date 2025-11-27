<script lang="ts">
import { topSectors } from '$lib/stores/data';
import { formatNumber, formatPercentChange, getChangeColor } from '$lib/utils/format';

function getStatusBadge(momChange: number | null | undefined) {
	if (momChange === null || momChange === undefined) return { class: 'badge-stagnant', text: 'Stable' };
	if (momChange > 5) return { class: 'badge-growth', text: 'Growing' };
	if (momChange < -10) return { class: 'badge-decline', text: 'Declining' };
	if (momChange < -5) return { class: 'badge-churn', text: 'Slowing' };
	return { class: 'badge-stagnant', text: 'Stable' };
}
</script>

<div class="card">
	<h2 class="card-header">Sector Spotlight</h2>
	<p class="text-sm text-gray-600 mb-4">
		Job posting trends by industry sector
	</p>

	<div class="space-y-3">
		{#each $topSectors as sector}
			{@const badge = getStatusBadge(sector.mom_change)}
			<div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
				<div class="flex-1 min-w-0">
					<div class="flex items-center gap-2">
						<span class="font-medium text-gray-800 truncate">{sector.name}</span>
						<span class="badge {badge.class}">{badge.text}</span>
					</div>
					<div class="text-sm text-gray-500">
						{formatNumber(sector.current_postings)} active postings
					</div>
				</div>

				<div class="text-right ml-4">
					<div class="text-sm {getChangeColor(sector.mom_change)}">
						{formatPercentChange(sector.mom_change)} MoM
					</div>
					{#if sector.yoy_change !== null && sector.yoy_change !== undefined}
						<div class="text-xs text-gray-400">
							YoY: {formatPercentChange(sector.yoy_change)}
						</div>
					{/if}
				</div>
			</div>
		{/each}
	</div>

	<div class="mt-4 pt-4 border-t border-gray-100 text-center">
		<button class="text-sm text-primary-600 hover:text-primary-700 font-medium">
			View all sectors →
		</button>
	</div>
</div>
