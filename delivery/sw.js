// GoPedido — service worker: recebe os avisos (push) e permite instalar como aplicativo.
// Não guarda páginas em cache, para o site sempre abrir a versão mais nova.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

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
