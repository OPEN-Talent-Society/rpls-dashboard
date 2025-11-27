import { writable } from 'svelte/store';

export type FilterState = {
	startMonth?: string;
	endMonth?: string;
	sector?: string;
	occupation?: string;
	state?: string;
};

const defaultFilters: FilterState = {
	startMonth: undefined,
	endMonth: undefined,
	sector: undefined,
	occupation: undefined,
	state: undefined
};

export const filters = writable<FilterState>({ ...defaultFilters });

export function serializeFilters(state: FilterState): string {
	const params = new URLSearchParams();
	if (state.startMonth) params.set('start', state.startMonth);
	if (state.endMonth) params.set('end', state.endMonth);
	if (state.sector) params.set('sector', state.sector);
	if (state.occupation) params.set('occupation', state.occupation);
	if (state.state) params.set('state', state.state);
	const s = params.toString();
	return s ? `?${s}` : '';
}

export function parseFilters(search: string): FilterState {
	const params = new URLSearchParams(search.startsWith('?') ? search.slice(1) : search);
	return {
		startMonth: params.get('start') || undefined,
		endMonth: params.get('end') || undefined,
		sector: params.get('sector') || undefined,
		occupation: params.get('occupation') || undefined,
		state: params.get('state') || undefined
	};
}

export function resetFilters() {
	filters.set({ ...defaultFilters });
}

export function updateFilters(partial: FilterState) {
	filters.update((prev) => ({ ...prev, ...partial }));
}
