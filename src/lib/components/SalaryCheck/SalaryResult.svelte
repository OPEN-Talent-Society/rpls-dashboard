<script lang="ts">
	export let salary: number;
	export let occupationName: string;
	export let stateName: string;
	export let nationalAvg: number;
	
	// Formatting
	const formatCurrency = (val: number) => 
		new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 }).format(val);

	// Calculate width percentage relative to a max (e.g., 1.5x the larger value)
	$: maxValue = Math.max(salary, nationalAvg) * 1.2;
	$: salaryWidth = (salary / maxValue) * 100;
	$: nationalWidth = (nationalAvg / maxValue) * 100;
	$: diff = salary - nationalAvg;
	$: diffPercent = (diff / nationalAvg) * 100;
</script>

<div class="mt-8 p-8 bg-cream border border-stone-200 rounded-xl relative overflow-hidden">
	<!-- Background Texture -->
	<div class="absolute inset-0 opacity-[0.03] pointer-events-none bg-[url('https://www.transparenttextures.com/patterns/cubes.png')]"></div>

	<div class="relative z-10">
		<div class="flex flex-col md:flex-row justify-between items-end mb-8 gap-4">
			<div>
				<h3 class="text-stone-500 text-xs font-bold uppercase tracking-widest mb-2">Estimated Market Salary</h3>
				<div class="text-5xl font-bold text-brand-900 font-display tracking-tight">
					{formatCurrency(salary)}
				</div>
				<p class="text-sm text-stone-600 mt-2 font-medium">
					for <span class="text-brand-800 border-b border-brand-200 pb-0.5">{occupationName}</span> in {stateName}
				</p>
			</div>
			<div class="text-right bg-white px-4 py-2 rounded-lg border border-stone-100 shadow-sm">
				<div class="text-xs font-bold text-stone-400 uppercase mb-1">vs National Avg</div>
				<div class={`text-xl font-bold font-mono ${diff >= 0 ? 'text-growth' : 'text-decline'}`}>
					{diff >= 0 ? '+' : ''}{diffPercent.toFixed(1)}%
				</div>
			</div>
		</div>

		<!-- Visualization -->
		<div class="space-y-6">
			<!-- User/State Salary -->
			<div class="relative">
				<div class="flex justify-between text-sm font-bold text-brand-900 mb-2">
					<span>{stateName}</span>
				</div>
				<div class="h-6 bg-stone-100 rounded-full overflow-hidden border border-stone-200">
					<div 
						class="h-full bg-brand-800 relative transition-all duration-1000 ease-out" 
						style="width: {salaryWidth}%"
					></div>
				</div>
			</div>

			<!-- National Avg -->
			<div class="relative opacity-75">
				<div class="flex justify-between text-sm font-medium text-stone-500 mb-2">
					<span>National Average</span>
					<span class="font-mono">{formatCurrency(nationalAvg)}</span>
				</div>
				<div class="h-4 bg-stone-100 rounded-full overflow-hidden border border-stone-200">
					<div 
						class="h-full bg-stone-400 relative transition-all duration-1000 ease-out" 
						style="width: {nationalWidth}%"
					></div>
				</div>
			</div>
		</div>

		<!-- Analyst Insight -->
		<div class="mt-8 p-5 bg-brand-50 rounded-lg border border-brand-100 flex items-start gap-4">
			<div class="mt-1 flex-shrink-0 text-brand-600">
				<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
					<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />
				</svg>
			</div>
			<div>
				<div class="text-xs font-bold text-brand-800 uppercase tracking-widest mb-1">Analyst Insight</div>
				<p class="text-sm text-brand-900 font-serif leading-relaxed">
					Salaries in <span class="font-bold">{stateName}</span> are currently trading 
					<span class={diff >= 0 ? 'text-growth font-bold' : 'text-decline font-bold'}>{diff >= 0 ? 'at a premium' : 'at a discount'}</span> 
					relative to the national baseline. This gap suggests {diff >= 0 ? 'strong local demand or higher cost of living adjustments' : 'lower regional cost of labor or saturation in this specific role'}.
				</p>
			</div>
		</div>
	</div>
</div>
