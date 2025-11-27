import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import path from 'path';
import { fileURLToPath } from 'url';

const configDir = path.dirname(fileURLToPath(import.meta.url));

export default defineConfig({
	plugins: [sveltekit()],
	resolve: {
		conditions: ['svelte', 'browser']
	},
	test: {
		globals: true,
		environment: 'jsdom',
		setupFiles: [path.resolve(configDir, 'tests/setup.ts')],
		resolve: {
			conditions: ['svelte', 'browser']
		}
	}
});
