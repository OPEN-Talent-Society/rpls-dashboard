/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts}'],
	theme: {
		extend: {
			colors: {
				// Brand Colors
				brand: {
					50: '#f2f7f5',
					100: '#e1efe9',
					200: '#c3ded3',
					300: '#96c2b1',
					400: '#64a189',
					500: '#42836a',
					600: '#2f6652',
					700: '#265242',
					800: '#1b4d3e', // The User's Brand Color
					900: '#164035',
					950: '#0b241e'
				},
				
				// Neutrals / Backgrounds
				cream: '#fcfbf9',
				stone: {
					50: '#fafaf9',
					100: '#f5f5f4',
					200: '#e7e5e4',
					800: '#292524',
					900: '#1c1917'
				},

				// Accents
				accent: '#d97706', // Bronze/Gold
				
				// Data Semantic
				growth: '#15803d', // Green-700
				decline: '#b91c1c', // Red-700
				churn: '#b45309', // Amber-700
				stagnant: '#4b5563', // Gray-600
			},
			fontFamily: {
				sans: ['Inter', 'system-ui', 'sans-serif'],
				serif: ['Merriweather', 'Georgia', 'serif'],
				mono: ['JetBrains Mono', 'Menlo', 'monospace'],
				display: ['Merriweather', 'serif']
			}
		}
	},
	plugins: []
};
