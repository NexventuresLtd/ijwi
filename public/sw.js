// Ijwi Service Worker — handles push notifications and offline caching
const CACHE = 'ijwi-v1'
const OFFLINE_URL = '/feed'

// Install — cache key pages
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(cache =>
      cache.addAll(['/', '/feed', '/explore', '/shorts'])
    )
  )
  self.skipWaiting()
})

// Activate — clean old caches
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  )
  self.clients.claim()
})

// Fetch — network-first with offline fallback
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return
  if (!event.request.url.startsWith(self.location.origin)) return

  event.respondWith(
    fetch(event.request)
      .then(res => {
        if (res.ok) {
          const clone = res.clone()
          caches.open(CACHE).then(c => c.put(event.request, clone))
        }
        return res
      })
      .catch(() => caches.match(event.request).then(r => r ?? caches.match(OFFLINE_URL)))
  )
})

// Push notification
self.addEventListener('push', event => {
  const data = event.data?.json() ?? {}
  const title = data.title ?? 'Ijwi'
  const options = {
    body: data.body ?? 'You have a new notification.',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    data: { url: data.url ?? '/feed' },
    tag: data.tag ?? 'ijwi-notif',
    renotify: true,
  }
  event.waitUntil(self.registration.showNotification(title, options))
})

// Notification click — open the linked URL
self.addEventListener('notificationclick', event => {
  event.notification.close()
  const url = event.notification.data?.url ?? '/feed'
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(all => {
      const existing = all.find(c => c.url.includes(self.location.origin))
      if (existing) return existing.focus().then(c => c.navigate(url))
      return clients.openWindow(url)
    })
  )
})
