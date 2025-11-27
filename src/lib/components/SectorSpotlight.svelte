<script lang="ts">
import { topSectors } from '$lib/stores/data';
import { formatNumber, formatPercentChange, getChangeColor } from '$lib/utils/format';

function getStatusBadge(change: number | null | undefined) {
	if (change === null || change === undefined) return { class: 'badge-stagnant', text: 'Stable' };
	if (change > 5) return { class: 'badge-growth', text: 'Growing' };
	if (change < -10) return { class: 'badge-decline', text: 'Declining' };
	if (change < -5) return { class: 'badge-churn', text: 'Slowing' };
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
			{@const change = sector.yoy_change ?? sector.mom_change}
			{@const badge = getStatusBadge(change)}
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
					<div class="text-sm {getChangeColor(change)}">
						{change === null || change === undefined
							? 'Stable (MoM)'
							: `${formatPercentChange(change)} vs prior period`}
					</div>
					<div class="text-xs text-gray-400">
						{sector.yoy_change === null || sector.yoy_change === undefined
							? `MoM: ${formatPercentChange(sector.mom_change)}`
							: `YoY: ${formatPercentChange(sector.yoy_change)}`}
					</div>
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
