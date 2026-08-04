---
name: premium_ui
description: >
  Aplica el manifiesto de Diseño Premium a una página de la PWA. Incluye márgenes asimétricos, 
  GeoSidebar, patrón de panales, botón de volver dobles (Atrás y Home), formato de botones principales 
  y el Estándar Móvil PWA basado en Gestión de Viajes.
---

# Skill: premium_ui

Esta habilidad se encarga de estandarizar visual y arquitectónicamente las pantallas de GeoLogística PWA tanto en Escritorio como en Celulares (PWA).

## Cuándo usar esta habilidad
Se activa cuando el usuario solicita aplicar el "diseño premium", "estandarizar diseño", "skill premium", "aplica premium_ui" o "adaptar a móvil pwa" a una página específica.

---

## 🎨 REGLAS ESENCIALES DE DISEÑO Y ARQUITECTURA

### 1. Botones Principales (Primary Action Buttons) - ¡ESTRICTO!
- **Color de Fondo:** **SIEMPRE Verde Esmeralda Profundo (`DesignTokens.primary` / `#08201A`)**.
- ⛔ **PROHIBIDO:** Usar dorado (`#C68E17`) para botones principales (Guardar, Confirmar, Nuevo Viaje, Nueva Carga, etc.). El dorado es solo para acentos, badges o pestañas activas.
- **Color de Texto/Ícono:** Blanco puro (`#FFFFFF`).
- **Geometría:** `BorderRadius.circular(8)` con `elevation: 0`.
- **Tipografía:** `Manrope`, `fontWeight: FontWeight.w700` (o `w800`), `fontSize: 14-15`, `letterSpacing: 1`.
- **Estilo Base:** `DesignTokens.primaryButtonStyle`.

---

### 2. Estándar PWA Móvil (Referencia: `viajes_page.dart`)

En pantallas móviles (`MediaQuery.of(context).size.width < 900`):

1. **Estructura Base & Drawer**:
   - `Scaffold` con fondo neutro `DesignTokens.surface` (`#FBF9F8`).
   - Menú lateral `GeoSidebar` asignado a `drawer: MediaQuery.of(context).size.width < 900 ? const GeoSidebar(currentRoute: '/ruta') : null`.
   - `HoneycombPainter` en segundo plano con `Stack` y `RepaintBoundary`.

2. **Encabezado Móvil (Header)**:
   - **Botones Dobles de Navegación:** Tarjetas blancas de 36x36px con `BorderRadius.circular(10)` y borde sutil:
     1. Botón Atrás (`<`): `context.canPop() ? context.pop() : null`
     2. Botón Home (`🏠`): `context.go('/home')`
   - **Título Principal:** `Text('...', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 22-24, color: DesignTokens.primary))`.
   - **Acciones Rápidas:** Botón circular de refresco de datos (`Icons.refresh_rounded`) y conmutador de vista (Tarjetas vs Tabla si aplica).

3. **Buscador & Filtros (TabBar)**:
   - Buscador full-width posicionado directamente debajo de la cabecera con `Padding(16, 0, 16, 16)`.
   - `TabBar` horizontal deslizable para filtrar por estado/categoría con `indicatorColor: DesignTokens.secondary` (`#C68E17`), `labelColor: DesignTokens.primary` (`#08201A`) y fuentes en mayúsculas `Work Sans w800`.

4. **Tarjetas Bento Móviles (Mobile Bento Cards)**:
   - Reemplazar DataGrid/Tablas pesadas en móviles por tarjetas Bento compactas (padding interno 14px/12px, márgenes reducidos 12px).
   - Código/ID en `JetBrains Mono` con píldora/badge de estado de bajo contraste.
   - Metadatos visuales (fechas, peso, apicultor, localidad) organizados claramente con íconos vectoriales.
   - Enlaces interactivos (Apicultores, Viajes) con subrayado discreto y navegación al perfil/detalle correspondiente.

---

### 3. Estándar Escritorio (Desktop)
- Layout con `Row`: `GeoSidebar` a la izquierda y `Expanded` con el contenido a la derecha.
- Margen asimétrico: `EdgeInsets.fromLTRB(120, 0, 40, 0)` o contenedor responsivo sin `maxWidth` estático.
- Botones de acción principal en la **esquina superior derecha de la cabecera** (`ElevatedButton.icon` en `#08201A`), NUNCA flotantes abajo.

---

## 🛠️ Instrucciones de Ejecución (Para el Agente)

1. **Lectura y Análisis del Archivo:** Lee el código fuente del archivo solicitado (ej. `lib/pages/cargas_page.dart`).
2. **Validación de Seguridad:** Analiza la arquitectura. Asegura no romper lógica de negocio o manejadores de estado.
3. **Aplicación Directa:** Usa `replace_file_content` para inyectar el estándar en el archivo.
4. **Verificación Estática:** Ejecuta `flutter analyze` sobre el archivo editado.
5. **Git Commit & Push:** Ejecuta `git add .`, `git commit -m "style: aplicar premium_ui a [nombre_pagina]"` y `git push origin master`.
6. **Despliegue Vercel:** Compila y despliega a Vercel Producción.
