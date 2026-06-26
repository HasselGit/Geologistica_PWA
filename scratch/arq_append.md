
## 24. Rediseño Total STITCH y Arquitectura PWA Offline (24-25 de Junio de 2026)
### A. Refactorización Responsiva Masiva
- **Adopción Universal LayoutBuilder**: Las pantallas de entidades del sistema (`vehiculos_page.dart`, `choferes_page.dart`, `apicultores_page.dart`, `productos_page.dart`) fueron completamente reescritas para abandonar los ListViews rígidos y adoptar el patrón responsivo Desktop-First del sistema STITCH, con paneles laterales estáticos o collapsables.
- **Bento Box Estética**: Todas las tarjetas de visualización adoptaron radios de borde generosos (12px), sombras nulas y bordes finos `#E2E8F0` sobre un fondo blanco `#FFFFFF`, en contraste con el lienzo principal `#FBF9F8`.

### B. Arquitectura de Despliegue PWA - Vercel Rewrite
- **El Bloqueo SPA**: La política SPA estándar de Vercel interceptaba el registro de `flutter_service_worker.js`, bloqueando la disponibilidad offline del manifest y del worker, lo cual ocasionaba un pantallazo verde (#08201A) infinito en Modo Avión.
- **Rewrites de Prioridad Máxima**: En `vercel.json` se configuraron reglas estrictas de rewrite que sirven los binarios sin interceptar antes que el catch-all `(.*)`.
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

### C. Offline-Locking del Compilador Flutter
- **Dependencia de CDN Google**: Por defecto, los Web builds de Flutter 3.41+ intentan descargar CanvasKit desde CDNs externos, rompiendo toda posibilidad offline verdadera.
- **Compilación Autosustentable**: Se impuso el flag `--no-web-resources-cdn` en los comandos de producción web para incrustar el WASM en el bundle y asegurar que la caché local lo administre autónomamente.

### D. Manipulación de Service Worker y Limpieza de Caché
- **Secuestro de Versión Safari/Chrome**: Dado que los navegadores son renuentes a purgar antiguos Service Workers instalados, se escribió un script en Python (`generate_sw.py`) que inyecta manualmente un archivo `flutter_service_worker.js` en `build/web/` justo antes de compilar en Vercel.
- **Adquisición Incondicional de Clientes**: Este worker personalizado fuerza `self.skipWaiting()` en su evento `install` y `self.clients.claim()` en su evento `activate` para destronar a cualquier worker obsoleto remanente y forzar la re-caché.
- **Manejo de Errores Fetch**: Se eliminó el comportamiento fallback que enviaba HTML espurio ante una caída de red para `main.dart.js`, permitiendo que el interceptor emita el catch real de desconexión y deje bootear la UI offline.

## 25. Limitaciones Inherentes y Transición Offline
- **Vulnerabilidad PWA Web (Evicción de Caché)**: A pesar del Service Worker perfecto, los navegadores en iOS/Android deciden purgar proactivamente el caché WASM pesado tras unas semanas, destruyendo la garantía del Arranque en Frío de los choferes cuando viajan a campos aislados sin cobertura.
- **Directriz Futura**: Flutter Web PWA se mantendrá de forma permanente para los roles de oficina (Gerencia, CEO, Administración, Compras). Para los roles de terreno (Chofer, Apicultor Remoto), el desarrollo debe transicionar forzosamente hacia la compilación de una **Aplicación Nativa (Android APK)** a futuro. Esta es la única forma comprobada de aislar completamente el arranque en frío y depender únicamente del estado de caché de Supabase o Hive en el dispositivo, esquivando las arbitrariedades de Safari y Chrome.
