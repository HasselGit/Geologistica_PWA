---
name: premium_ui_pwa
description: >
  Aplica el Estándar Móvil PWA unificado (basado en viajes_page.dart y el sistema de diseño Stitch)
  a cualquier página del proyecto GeoLogística. Incluye layout responsivo <900px, cabecera con botones
  dobles (< y 🏠), buscador/TabBar horizontal, tarjetas Bento compactas con fuentes Manrope/Work Sans
  y el drawer GeoSidebar.
---

# Skill: premium_ui_pwa

Esta habilidad se encarga de estandarizar visual y arquitectónicamente cualquier pantalla de la PWA Móvil GeoLogística (`MediaQuery.of(context).size.width < 900`), usando como molde maestro la pantalla de **Gestión de Viajes (`viajes_page.dart`)** y el sistema de diseño de **Stitch** (`diseño_stitch/apiary_logistics_framework/DESIGN.md`).

---

## 🎨 REGLAS ESENCIALES DE LA PWA MÓVIL (MANDATORIAS)

### 1. Paleta de Colores y Tokens Corporativos
- **Fondo General PWA (`Lienzo`):** `DesignTokens.surface` / `#FBF9F8` (Crema / Off-White).
- **Textura de Fondo:** `HoneycombPainter()` dentro de un `Stack` con `RepaintBoundary`.
- **Color Principal de Marca:** Verde Esmeralda Profundo `DesignTokens.primary` (`#08201A`).
- **Color Secundario / Acentos Activos:** Dorado Miel `DesignTokens.secondary` (`#C68E17` / `#FDBE49`).
- **Bordes de Tarjetas Bento:** `Border.all(color: DesignTokens.primary.withOpacity(0.06))` o `#E2E8F0` sobre fondo blanco `#FFFFFF`.

---

### 2. Estructura de Pantalla (`Scaffold` Responsivo)

```dart
final bool isDesktop = MediaQuery.of(context).size.width >= 900;

return Scaffold(
  backgroundColor: const Color(0xFFFBF9F8),
  drawer: !isDesktop ? Drawer(child: GeoSidebar(userRole: _userRole, userEmail: _userEmail, displayName: _displayName)) : null,
  appBar: isDesktop ? null : _buildMobileAppBar(),
  body: Stack(
    children: [
      const Positioned.fill(
        child: RepaintBoundary(child: CustomPaint(painter: HoneycombPainter())),
      ),
      Row(
        children: [
          if (isDesktop) GeoSidebar(...),
          Expanded(
            child: Container(
              padding: isDesktop ? const EdgeInsets.fromLTRB(120, 0, 40, 0) : EdgeInsets.zero,
              child: _buildMainContent(context, isDesktop),
            ),
          ),
        ],
      ),
    ],
  ),
  bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
);
```

---

### 3. Encabezado Móvil (Header) - Botones Dobles `<` y `🏠`

En la parte superior de pantallas móviles:
- **Botón Menú / Hamburguesa (`≡`):** Abre `Scaffold.of(context).openDrawer()`.
- **Botón Atrás (`<`):** `InkWell` de 36x36px blanco redondeado (radius 10) que llama a `context.pop()`.
- **Botón Home (`🏠`):** `InkWell` de 36x36px blanco redondeado (radius 10) que llama a `context.go('/home')`.
- **Título de Pantalla:** `Text('NOMBRE DE SECCIÓN', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w800, fontSize: 20-24, color: DesignTokens.primary))`.
- **Subtítulo Caps:** `Text('SUBTÍTULO OPERATIVO', style: TextStyle(fontFamily: 'Work Sans', fontWeight: FontWeight.w800, fontSize: 10, letterSpacing: 1, color: DesignTokens.primary.withOpacity(0.5)))`.

---

### 4. Buscador y TabBar Horizontal (Filtros por Estado)

- **Buscador Full-Width:** `TextField` con fondo blanco `#FFFFFF`, bordes sutiles `BorderRadius.circular(12)` y prefijo `Icons.search_rounded`.
- **Pestañas (TabBar):** `TabBar` horizontal deslizable en `Work Sans w800` mayúsculas, con `indicatorColor: DesignTokens.secondary` (`#C68E17`) y `labelColor: DesignTokens.primary` (`#08201A`).

---

### 5. Tarjetas Bento Móviles (Mobile Cards)

Reemplazar cualquier tabla o DataGrid en móviles por tarjetas Bento compactas:
- **Contenedor:** Fondo blanco `#FFFFFF`, `BorderRadius.circular(16)`, borde fino `Border.all(color: DesignTokens.primary.withOpacity(0.06))`.
- **Código/ID de Registro:** En fuente monospaciada `JetBrains Mono` con `FontWeight.w700`.
- **Píldora de Estado (Status Badge):** Contenedor redondeado (`BorderRadius.circular(12)`) con color suave acorde al estado (Verde para completado, Dorado/Amarillo para en curso, Azul para pendiente).
- **Metadatos Visuales:** Datos (fechas, peso, apicultor, ubicación) organizados con íconos vectoriales de 16-18px.

---

### 6. Botón de Acción Principal (CTA)

- **Color de Fondo:** **SIEMPRE Verde Esmeralda Profundo (`DesignTokens.primary` / `#08201A`)**.
- ⛔ **PROHIBIDO:** Usar dorado para botones principales (Guardar, Confirmar, Nuevo Viaje, Nueva Carga). El dorado es exclusivo para acentos y pestañas activas.
- **Texto/Ícono:** Blanco puro (`#FFFFFF`), `Manrope w800`, `fontSize: 14`, `letterSpacing: 1`.

---

## 🛠️ Instrucciones de Aplicación

1. **Lectura**: Analizar la pantalla destino (ej. `lib/pages/pesajes_page.dart` o `necesidades_page.dart`).
2. **Validación de Seguridad**: Verificar que la versión Web de Escritorio (`width >= 900px`) se mantenga 100% inalterada.
3. **Reemplazo de Layout Móvil**: Inyectar la estructura responsiva y las tarjetas Bento compactas cuando `!isDesktop`.
4. **Prueba y Compilación**: Compilar para Web/Android y desplegar a Vercel Producción.
