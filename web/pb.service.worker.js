// REDLINE cache worker. Replaces Godot's stock PWA worker so the engine files are cached on the FIRST visit
// (the stock worker only caches wasm and pck from the second visit on) and so every deploy gets its own cache.
// CI replaces __BUILD_ID__ with the commit hash when it copies this file next to index.html.
const BUILD = '__BUILD_ID__';
const CACHE = 'redline-' + BUILD;
const CRITICAL = ['index.html', 'index.js', 'index.wasm', 'index.pck'];
const OPTIONAL = ['index.audio.worklet.js', 'index.audio.position.worklet.js', 'index.icon.png', 'index.apple-touch-icon.png', 'index.manifest.json', 'brand.json', 'brand/logo.png', 'brand/Bangers.ttf'];

// The page registers this worker after the game has loaded, so the files are already in the HTTP cache:
// 'no-cache' revalidates them (a 304, no body) and guarantees the stored copy matches this deploy.
async function store(cache, url) {
	const response = await fetch(new Request(url, { cache: 'no-cache' }));
	if (!response.ok) throw new Error(url + ' ' + response.status);
	await cache.put(url, response);
}

self.addEventListener('install', (event) => {
	event.waitUntil((async () => {
		const cache = await caches.open(CACHE);
		await Promise.all(CRITICAL.map((url) => store(cache, url)));
		await Promise.allSettled(OPTIONAL.map((url) => store(cache, url)));
		await self.skipWaiting();
	})());
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		for (const key of await caches.keys()) {
			if (key.startsWith('redline-') && key !== CACHE) await caches.delete(key);
		}
		await self.clients.claim();
	})());
});

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET') return;
	const url = new URL(request.url);
	if (url.origin !== self.location.origin) return;
	const name = url.pathname.endsWith('brand/logo.png') ? 'brand/logo.png' : url.pathname.endsWith('brand/Bangers.ttf') ? 'brand/Bangers.ttf' : (url.pathname.slice(url.pathname.lastIndexOf('/') + 1) || 'index.html');
	if (!CRITICAL.includes(name) && !OPTIONAL.includes(name)) return;
	event.respondWith((async () => {
		const cached = await (await caches.open(CACHE)).match(name);
		return cached || fetch(request);
	})());
});
