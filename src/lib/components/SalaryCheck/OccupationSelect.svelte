<script lang="ts">
	export let options: { code: string; name: string }[] = [];
	export let value: string = '';
</script>

<div class="w-full">
	<label for="occupation" class="block text-xs font-bold text-brand-700 mb-2 uppercase tracking-wider">
		Select Role
	</label>
	<div class="relative">
		<select
			id="occupation"
			bind:value
			class="appearance-none w-full bg-white border border-stone-300 text-stone-900 py-3 px-4 pr-8 rounded shadow-sm leading-tight focus:outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500 font-sans text-sm transition-colors"
		>
			<option value="" disabled selected>Choose an occupation...</option>
			{#each options as option}
				<option value={option.code}>{option.name}</option>
			{/each}
		</select>
		<div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-stone-500">
			<svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
				<path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z" />
			</svg>
		</div>
	</div>
</div>
