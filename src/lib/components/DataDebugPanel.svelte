<script lang="ts">
	import { onMount } from 'svelte';
	import { supabase, hasSupabaseEnv } from '$lib/supabase';
	import { writable } from 'svelte/store';

	type Status = {
		ok: boolean;
		error?: string | null;
		dim_counts?: Record<string, number>;
		facts?: { employment_latest?: string | null; layoffs_latest?: string | null };
	};

	const status = writable<Status>({ ok: false, error: 'Loading...' });

	onMount(async () => {
		if (!hasSupabaseEnv) {
			status.set({ ok: false, error: 'Supabase env missing' });
			return;
		}
		try {
			const res = await fetch('/api/status');
			const data = await res.json();
			status.set(data);
		} catch (err: any) {
			status.set({ ok: false, error: err?.message ?? String(err) });
		}
	});
</script>

<div class="text-xs text-gray-600 space-y-1 bg-yellow-50 border border-yellow-200 rounded p-3">
	<div class="font-semibold text-yellow-800">Data Status (anon)</div>
	{#if $status.ok}
		<div>Dims: sectors {$status.dim_counts?.sectors}, occ {$status.dim_counts?.occupations}, states {$status.dim_counts?.states}</div>
		<div>Employment latest: {$status.facts?.employment_latest}</div>
		<div>Layoffs latest: {$status.facts?.layoffs_latest}</div>
	{:else}
		<div class="text-red-700">{$status.error}</div>
	{/if}
</div>
