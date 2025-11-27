import 'dotenv/config';
import '@testing-library/jest-dom/vitest';

// Ensure DOM globals exist for client-side Svelte tests
if (typeof window === 'undefined') {
	// @ts-ignore
	global.window = {
		document: {},
	} as any;
}
if (typeof document === 'undefined') {
	// @ts-ignore
	global.document = {
		createElement: () => ({}),
	} as any;
}

// Basic canvas stub so Chart.js doesn't blow up in jsdom
if (!HTMLCanvasElement.prototype.getContext) {
	HTMLCanvasElement.prototype.getContext = () => ({
		fillRect: () => {},
		clearRect: () => {},
		getImageData: () => ({ data: [] }),
		putImageData: () => {},
		createImageData: () => [],
		setTransform: () => {},
		drawImage: () => {},
		save: () => {},
		fillText: () => {},
		restore: () => {},
		beginPath: () => {},
		moveTo: () => {},
		lineTo: () => {},
		closePath: () => {},
		stroke: () => {},
		translate: () => {},
		scale: () => {},
		rotate: () => {},
		arc: () => {},
		rect: () => {},
		fill: () => {},
		strokeRect: () => {},
		measureText: () => ({ width: 0 }),
		transform: () => {},
		setLineDash: () => {},
		getLineDash: () => []
	});
}
