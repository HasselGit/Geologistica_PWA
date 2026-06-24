# 🧵 STITCH System Guide & AI Context

Este documento representa el **Estado Actual Definitivo** del proyecto GeoLogística PWA a fecha de cierre de la **Fase 4 (Bloques A, B y C)**. Está diseñado específicamente para dar contexto a cualquier Agente de IA que retome el proyecto.

## 1. Estado del Proyecto (Fase 4 Completada)
La refactorización corporativa de la aplicación bajo el **Sistema de Diseño STITCH** se completó con éxito.
- **Producción Vercel:** `https://geologistica-pwa.vercel.app`
- **Despliegue SPA:** Se resolvió el "Error 404" histórico compilando `flutter build web --release` y ordenando a Vercel desplegar exclusivamente la carpeta `build/web/` donde se ubica el archivo `vercel.json` con las reglas de redirección al `index.html`.

### Bloques Terminados y Auditados:
- **Bloque A:** Core Operativo (Homepage, Login, Planificador de Rutas, Vehículos, etc.).
- **Bloque B:** Catálogos y Finanzas (Apicultores, Gastos y Comprobantes).
- **Bloque C:** Cierre Administrativo (Cargas y Detalles, Inteligencia de Negocios, Trazabilidad, Configuración, Perfil).

## 2. Pautas de Interfaz: Desktop-First (Bento Layout)
Toda nueva pantalla web debe seguir el patrón de **Diseño Bento** usando `LayoutBuilder` para diferenciar pantallas:

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth >= 900) {
      // 💻 ESCRITORIO: Retornar vista web (Sin AppBar móvil)
      // Usar Row con Left Panel y Right Content.
    } else {
      // 📱 MÓVIL: Retornar vista móvil tradicional (Con AppBar)
    }
  }
)
```

## 3. Sistema de Tokens (STITCH)
Cualquier archivo de FlutterFlow ha sido deprecado. Todo el diseño DEBE utilizar los tokens centralizados en `lib/backend/design_tokens.dart`:
- `DesignTokens.primary` (Verde Bosque `#08201A`)
- `DesignTokens.secondary` (Dorado Miel `#FDBE49`)
- `DesignTokens.background` (Gris Pizarra `#F5F3F3`)
- `DesignTokens.headlineStyle()`, `DesignTokens.bodyStyle()`

## 4. Supabase & Hive
- **Supabase:** Es la única fuente de verdad (Single Source of Truth). Todas las escrituras deben utilizar `SupabaseService` (e.g. `SupabaseService().crearViaje()`).
- **Estado Asíncrono:** Todas las llamadas a la DB deben envolverse en bloques `try-catch` y utilizar banderas `_saving` o `_loading` para deshabilitar botones y prevenir inyecciones duplicadas.
- **Hive:** Funciona como caché local en Web para catálogos pesados (Apicultores). Si se hace una búsqueda con _debounce_, primero se consulta en Hive y luego se impacta en Supabase si no hay coincidencias locales.

## 5. Prevención de CPU Spikes en Gráficos
Cualquier renderizado complejo (como gráficos SVG o Canvas customizado de métricas en `reportes_page.dart`) DEBE estar envuelto en un widget `RepaintBoundary`. Esto aísla el contexto gráfico para que los teclados y animaciones de la UI no provoquen repintados de Canvas que saturan la web.

---
> [!IMPORTANT]
> **REGLA DE ORO DE DESARROLLO**
> Al desarrollar o extender este proyecto, no alteres las reglas de autenticación y roles de negocio establecidas en `ARQUITECTURA_GEOLOGISTICA.md`. El sistema operativo de choferes es inmutable y no debe ser sobreescrito sin autorización de la Gerencia.
