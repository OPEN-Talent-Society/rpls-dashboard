import { injectAnalytics } from '@vercel/analytics/sveltekit';
import { injectSpeedInsights } from '@vercel/speed-insights/sveltekit';
import type { Handle } from '@sveltejs/kit';

injectAnalytics();
injectSpeedInsights();

export const handle: Handle = async ({ event, resolve }) => {
	return resolve(event);
};
