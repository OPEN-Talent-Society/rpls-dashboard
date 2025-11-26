// Formatting utilities for RPLS Dashboard

/**
 * Format a number as currency (USD)
 */
export function formatCurrency(value: number | null | undefined): string {
	if (value === null || value === undefined) return 'N/A';
	return new Intl.NumberFormat('en-US', {
		style: 'currency',
		currency: 'USD',
		minimumFractionDigits: 0,
		maximumFractionDigits: 0
	}).format(value);
}

/**
 * Format a number with thousands separators
 */
export function formatNumber(value: number | null | undefined): string {
	if (value === null || value === undefined) return 'N/A';
	return new Intl.NumberFormat('en-US').format(value);
}

/**
 * Format a number as a compact string (e.g., 1.5M)
 */
export function formatCompact(value: number | null | undefined): string {
	if (value === null || value === undefined) return 'N/A';
	return new Intl.NumberFormat('en-US', {
		notation: 'compact',
		compactDisplay: 'short',
		maximumFractionDigits: 1
	}).format(value);
}

/**
 * Format a decimal as a percentage
 */
export function formatPercent(value: number | null | undefined, decimals: number = 1): string {
	if (value === null || value === undefined) return 'N/A';
	return `${(value * 100).toFixed(decimals)}%`;
}

/**
 * Format a percentage change with + or - sign
 */
export function formatPercentChange(value: number | null | undefined): string {
	if (value === null || value === undefined) return 'N/A';
	const sign = value >= 0 ? '+' : '';
	return `${sign}${value.toFixed(1)}%`;
}

/**
 * Format a date string (YYYY-MM) to readable format
 */
export function formatMonth(dateStr: string): string {
	if (!dateStr) return 'N/A';
	const [year, month] = dateStr.split('-');
	const date = new Date(parseInt(year), parseInt(month) - 1);
	return date.toLocaleDateString('en-US', { month: 'short', year: 'numeric' });
}

/**
 * Get color class based on value (positive = green, negative = red)
 */
export function getChangeColor(value: number | null | undefined): string {
	if (value === null || value === undefined) return 'text-gray-500';
	if (value > 0) return 'text-green-600';
	if (value < 0) return 'text-red-600';
	return 'text-gray-500';
}

/**
 * Get background color class based on health index
 */
export function getHealthColor(index: number): string {
	if (index >= 70) return 'bg-green-500';
	if (index >= 50) return 'bg-yellow-500';
	if (index >= 30) return 'bg-orange-500';
	return 'bg-red-500';
}

/**
 * Get trend icon based on direction
 */
export function getTrendIcon(trend: 'improving' | 'stable' | 'declining'): string {
	switch (trend) {
		case 'improving':
			return '↑';
		case 'declining':
			return '↓';
		default:
			return '→';
	}
}
