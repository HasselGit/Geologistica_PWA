import os

build_dir = r"build\web"
urls_to_cache = ['/']

for root, dirs, files in os.walk(build_dir):
    for file in files:
        if file == 'flutter_service_worker.js':
            continue # Don't cache the service worker itself
        # Get relative path
        rel_path = os.path.relpath(os.path.join(root, file), build_dir)
        # Convert to forward slashes and ensure leading slash
        url = '/' + rel_path.replace('\\', '/')
        urls_to_cache.append(url)

sw_content = f"""var CACHE_NAME = 'geologistica-pwa-cache-v3';
var urlsToCache = {urls_to_cache};

self.addEventListener('install', function(event) {{
  // Forzar instalación inmediata
  self.skipWaiting();
  
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(function(cache) {{
        console.log('[Service Worker] Cache.addAll ejecutándose...');
        return cache.addAll(urlsToCache);
      }})
  );
}});

self.addEventListener('activate', function(event) {{
  // SECUESTRO DE VERSIÓN: Reclamar los clientes para que usen el nuevo SW de inmediato
  event.waitUntil(
    self.clients.claim().then(function() {{
      return caches.keys().then(function(cacheNames) {{
        return Promise.all(
          cacheNames.map(function(cacheName) {{
            if (cacheName !== CACHE_NAME) {{
              console.log('[Service Worker] Borrando caché antigua:', cacheName);
              return caches.delete(cacheName);
            }}
          }})
        );
      }});
    }})
  );
}});

self.addEventListener('fetch', function(event) {{
  // Only intercept GET requests
  if (event.request.method !== 'GET') return;
  
  event.respondWith(
    caches.match(event.request, {{ ignoreSearch: true }})
      .then(function(response) {{
        // Cache hit - return response (CACHE-FIRST)
        if (response) {{
          return response;
        }}
        
        // Not in cache, try network
        return fetch(event.request).then(function(networkResponse) {{
          if (!networkResponse || networkResponse.status !== 200 || networkResponse.type !== 'basic') {{
            return networkResponse;
          }}
          return networkResponse;
        }}).catch(function(error) {{
          // NO PINTAR HTML DE ERROR AQUÍ.
          // Lanzar la excepción para que Dart / Supabase lo ataje.
          throw error;
        }});
      }})
  );
}});
"""

with open(os.path.join(build_dir, "flutter_service_worker.js"), "w", encoding="utf-8") as f:
    f.write(sw_content)

print("Service worker generated with " + str(len(urls_to_cache)) + " urls.")
