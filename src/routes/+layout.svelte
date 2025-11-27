<script lang="ts">
	import '../app.css';
</script>

<div class="min-h-screen bg-gray-50">
	<!-- Header -->
	<header class="bg-white border-b border-gray-200">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
			<div class="flex items-center justify-between h-16">
				<div class="flex items-center gap-3">
					<div class="w-8 h-8 bg-primary-600 rounded-lg flex items-center justify-center">
						<svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
							<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
						</svg>
					</div>
					<div>
						<h1 class="text-lg font-semibold text-gray-900">RPLS Dashboard</h1>
						<p class="text-xs text-gray-500">Open Talent Society</p>
					</div>
				</div>

				<nav class="hidden md:flex items-center gap-6">
					<a href="/#dashboard" class="text-sm font-medium text-primary-600">Dashboard</a>
					<a href="/#salary" class="text-sm font-medium text-gray-600 hover:text-gray-900">Salary Check</a>
					<a href="/#sectors" class="text-sm font-medium text-gray-600 hover:text-gray-900">Sectors</a>
					<a href="/#about" class="text-sm font-medium text-gray-600 hover:text-gray-900">About</a>
				</nav>

				<div class="flex items-center gap-3">
					<a
						href="https://opentalentsociety.org"
						target="_blank"
						rel="noopener noreferrer"
						class="btn btn-secondary text-sm"
					>
						OTS Website
					</a>
				</div>
			</div>
		</div>
	</header>

	<!-- Main Content -->
	<main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
		<slot />
	</main>

	<!-- Footer -->
	<footer class="bg-white border-t border-gray-200 mt-auto">
		<div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
			<div class="flex flex-col md:flex-row items-center justify-between gap-4">
				<div class="text-sm text-gray-500">
					Data sourced from <a href="https://www.reveliolabs.com" target="_blank" rel="noopener" class="text-primary-600 hover:underline">Revelio Labs</a> Public Labor Statistics
				</div>
				<div class="flex items-center gap-6 text-sm text-gray-500">
					<span>Updated monthly</span>
					<a href="https://github.com/opentalentsociety" target="_blank" rel="noopener" class="hover:text-gray-700">
						GitHub
					</a>
					<span>&copy; {new Date().getFullYear()} Open Talent Society</span>
				</div>
			</div>
		</div>
	</footer>
</div>
