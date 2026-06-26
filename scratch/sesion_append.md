
# Sesión Actual - 24 y 25 de Junio, 2026

## 🌐 Hito de Infraestructura: Escalado del Sistema STITCH y Resolución Arquitectónica PWA Offline

En estas sesiones llevamos el rediseño del sistema STITCH al 100% de la plataforma (Login, Home Ejecutiva, Recolecciones, Distribuciones, Vehículos, Choferes, Apicultores y Formularios) y resolvimos uno de los bloqueos técnicos más complejos en la historia del proyecto: el arranque en frío (Cold Boot) en Modo Avión para la PWA compilada bajo Flutter 3.22+.

### 1. Despliegue Total del Diseño STITCH
- **Estandarización UI**: Se aplicó la guía de diseño STITCH (LayoutBuilders, Sidebars en Desktop, Drawer en Mobile) a todas las pantallas restantes del sistema. 
- **Lógica de Tarjetas (Bento Box)**: Las pantallas de gestión (`vehiculos_page.dart`, `choferes_page.dart`, `apicultores_page.dart`, `productos_page.dart`) ahora utilizan el patrón Bento UI, con fondos blancos `Colors.white`, radios de 12px y bordes sutiles `#E2E8F0`, manteniendo el fondo general en Off-White `#FBF9F8`.
- **Refactorización de Formularios**: Los modales de registro (ej: _showAddApicultorDialog, _showAddChoferDialog) fueron estructurados con Padding y `SafeArea` responsivo para que en escritorio aparezcan como modales premium centrados sin desbordar el alto de la pantalla, resolviendo edge cases en monitores 1080p.

### 2. Saneamiento de Interceptor PWA en Vercel
- **El Problema**: Vercel capturaba todas las llamadas a archivos estáticos del Service Worker (incluyendo `flutter_service_worker.js`) y servía el `index.html` bajo el enrutamiento SPA (catch-all), lo que corrompía la ejecución del caché en frío.
- **La Solución**: Modificamos agresivamente el `vercel.json` implementando una lista de exclusión (rewrites) prioritaria por encima del catch-all.
```json
{
  "cleanUrls": true,
  "rewrites": [
    { "source": "/flutter_service_worker.js", "destination": "/flutter_service_worker.js" },
    { "source": "/flutter_bootstrap.js", "destination": "/flutter_bootstrap.js" },
    { "source": "/manifest.json", "destination": "/manifest.json" },
    { "source": "/assets/(.*)", "destination": "/assets/$1" },
    { "source": "/(.*)", "destination": "/index.html" }
  ]
}
```

### 3. Resolución del Bloqueo CanvasKit CDN (Flutter 3.41+)
- **El Problema**: En versiones modernas de Flutter Web, el compilador por defecto descarga dependencias del motor CanvasKit desde CDNs externos, generando crashes instantáneos en Modo Avión ya que los binarios `.wasm` jamás estaban offline.
- **La Solución**: Se instruyó al motor para incrustar todas las librerías internamente usando `--no-web-resources-cdn`:
`flutter build web --release --no-web-resources-cdn`

### 4. Reescritura Nativa del Service Worker y Cache-Lock Break
- **El Problema (Dummy SW)**: Flutter depreció la autogeneración de Service Workers, generando scripts falsos (`self.registration.unregister()`), vaciando el precaché y delegando al navegador el renderizado de la pantalla nativa de "No tienes conexión".
- **La Solución**: Escribimos un generador de Service Worker manual (`generate_sw.py`) en Python que inyecta un `flutter_service_worker.js` real previo al despliegue.
- **Cache-First y Rompimiento de Bloqueo**: Se añadió lógica para registrar explícitamente los 45 archivos compilados y forzar una actualización silenciosa que mate cualquier Service Worker corrupto de sesiones anteriores (Secuestro de Versión) mediante los comandos incondicionales:
`self.skipWaiting();` en el evento `install`
`self.clients.claim();` en el evento `activate`
- **Fallback a Red**: Se implementó una lógica de `caches.match` para Assets con caída a red (`fetch`). En caso de corte de red, el catch `throw error` previene que el Service Worker inyecte HTML espurio de desconexión, permitiendo a Supabase atrapar la excepción internamente.

### 5. Determinación Arquitectónica: Límite Offline-First
A pesar de la optimización del Service Worker al nivel más extremo, concluimos mediante análisis técnico profundo que Flutter Web (WASM) carece de resiliencia genuina para operar como una PWA `Offline-First` en terrenos aislados:
- **Evicción Silenciosa**: iOS/Android purgan cachés pesados (archivos .wasm de >2MB) de forma arbitraria, causando fallas catastróficas de booteo en el campo.
- **Veredicto Definitivo**: El uso en terreno por los choferes deberá transicionar obligatoriamente a un **Compilado Nativo de Android (APK)** en fases futuras. Esto esquiva la latencia web, anula las dependencias de Service Workers y habilita una carga instantánea 100% aislada de CDNs para zonas agrícolas sin cobertura celular.
