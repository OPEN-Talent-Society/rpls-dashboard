<svelte:head>
	<meta http-equiv="refresh" content="0;url=/" />
</svelte:head>

<script lang="ts">
	import { onMount } from 'svelte';
	onMount(() => {
		window.location.replace('/');
	});
</script>

<p class="sr-only">Redirecting...</p>
