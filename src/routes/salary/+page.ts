import { redirect } from '@sveltejs/kit';

export const prerender = true;

export function load() {
	// Legacy/placeholder route: redirect to home until dedicated page exists
	throw redirect(307, '/');
}
