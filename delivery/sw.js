// GoPedido — service worker: recebe os avisos (push) e permite instalar como aplicativo.
// Guarda só as telas do CAIXA e do GARÇOM (e o que elas usam) para abrirem mesmo sem internet.
// Sempre tenta a versão nova primeiro; a cópia guardada só é usada quando a internet cai.
const CACHE = 'gp-offline-v1';
const OFFLINE = ['caixa.html', 'garcom.html', 'app.js', 'app.css', 'config.js', 'pdv-ui.js', 'img/icone.svg', 'manifest-painel.json'];
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil((async () => {
  for (const k of await caches.keys()) if (k.startsWith('gp-offline-') && k !== CACHE) await caches.delete(k);
  await self.clients.claim();
})()));
const guardavel = (url) => {
  if (url.origin === self.location.origin) return OFFLINE.some(f => url.pathname.endsWith('/' + f));
  return url.hostname === 'cdn.jsdelivr.net' && url.pathname.includes('supabase-js');
};
self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  let url; try { url = new URL(req.url); } catch (_) { return; }
  if (!guardavel(url)) return;
  e.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      const r = await fetch(req);
      if (r && r.ok) cache.put(url.origin + url.pathname, r.clone()).catch(() => {});
      return r;
    } catch (err) {
      const c = await cache.match(url.origin + url.pathname);
      if (c) return c;
      throw err;
    }
  })());
});

self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch (_) { d = { corpo: e.data ? e.data.text() : '' }; }
  const titulo = d.titulo || 'GoPedido';
  e.waitUntil(self.registration.showNotification(titulo, {
    body: d.corpo || '',
    icon: 'img/app-192.png',
    badge: 'img/badge-96.png',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    requireInteraction: !!(d.tag && d.tag !== 'teste'),
    vibrate: [300, 120, 300, 120, 300],
    data: { url: d.url || './painel.html' }
  }));
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const alvo = new URL((e.notification.data && e.notification.data.url) || './painel.html', self.location.href);
  e.waitUntil((async () => {
    const abas = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // já tem o painel aberto? só traz para a frente
    for (const c of abas) {
      const u = new URL(c.url);
      if (u.pathname === alvo.pathname && 'focus' in c) { try { await c.focus(); c.postMessage({ tipo: 'push-click', url: alvo.href }); } catch (_) {} return; }
    }
    if (self.clients.openWindow) await self.clients.openWindow(alvo.href);
  })());
});
