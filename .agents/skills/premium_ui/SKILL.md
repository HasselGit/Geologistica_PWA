---
name: premium_ui
description: >
  Aplica el manifiesto de DiseÃ±o Premium a una pÃ¡gina de la PWA. Incluye mÃ¡rgenes asimÃ©tricos, 
  GeoSidebar, botÃ³n de volver unificado y ajustes de tipografÃ­a/layout segÃºn las reglas establecidas.
---

# Skill: premium_ui

Esta habilidad se encarga de estandarizar visual y arquitectÃ³nicamente las pantallas de GeoLogÃ­stica PWA.

## CuÃ¡ndo usar esta habilidad
Se activa cuando el usuario solicita aplicar el "diseÃ±o premium", "estandarizar diseÃ±o", "skill premium" o "aplica premium ui" a una pÃ¡gina especÃ­fica.

## Instrucciones de EjecuciÃ³n (Para el Agente)

1. **Lectura Obligatoria:** Si aÃºn no lo has hecho en esta sesiÃ³n, debes leer el archivo de manifiesto ubicado en los artefactos de la conversaciÃ³n actual: `premium_design_standard.md`.
2. **AnÃ¡lisis de la PÃ¡gina:** Lee el cÃ³digo fuente del archivo solicitado (ej. `lib/pages/rutas_page.dart`).
3. **ValidaciÃ³n de Complejidad (Failsafe):** 
   - Analiza la estructura actual del archivo. Si el layout es extremadamente atÃ­pico o complejo y al inyectar un `Row` con `GeoSidebar` corres un alto riesgo de romper la vista por completo, **DETENTE**.
   - No modifiques el archivo. Notifica al usuario del problema arquitectÃ³nico y ofrÃ©cele opciones sobre cÃ³mo proceder.
4. **AplicaciÃ³n Directa:** Si la vista es manejable, aplica directamente las reglas del manifiesto editando el cÃ³digo fuente:
   - **Regla 1:** Inyectar `GeoSidebar` en un `Row` principal para Desktop y el contenido en un `Expanded`.
   - **Regla 2:** Padding asimÃ©trico `EdgeInsets.fromLTRB(120, 0, 40, 0)` en el contenido. Remover `maxWidth` y `Center`.
   - **Regla 3:** Control de proporciones con `LayoutBuilder`.
   - **Regla 4:** La cabecera debe incluir SIEMPRE dos botones de navegaciÃ³n (`InkWell` + Contenedor 36x36 blanco + sombra): 
     1. Un botÃ³n de "AtrÃ¡s" (`Icons.arrow_back_ios_new_rounded`) con la lÃ³gica `context.canPop() ? context.pop() : null` (si se puede volver, vuelve).
     2. Un botÃ³n de "Home" (`Icons.home_rounded`) con la lÃ³gica `context.go('/home')` ubicado justo al lado del botÃ³n de atrÃ¡s. Toda pÃ¡gina debe garantizar que existe el logo/botÃ³n "Home" visible en todo momento para regresar al inicio de manera segura.
   - **Regla 5:** Todos los botones principales de acciÃ³n (tipo `ElevatedButton`, "NUEVO VIAJE", "NUEVA SOLICITUD") deben tener un `BorderRadius.circular(8)` para mantener la consistencia con el diseÃ±o de Login y Sidebar. 
     - **MUY IMPORTANTE (Escritorio):** En la versiÃ³n de Escritorio (Desktop), los botones principales NUNCA deben ser botones flotantes (`FloatingActionButton`) en la esquina inferior. DEBEN renderizarse como `ElevatedButton` ubicados en la esquina superior derecha de la cabecera (junto a los filtros o buscador) utilizando siempre `DesignTokens.primaryButtonStyle` (el cual debe usar el color verde oscuro y la tipografÃ­a Manrope FontWeight.w700 tamaÃ±o 15, idÃ©ntico al botÃ³n INICIAR). En mÃ³viles, sÃ­ pueden ser botones flotantes.
   - **Regla 8:** Fondo de Panales (Honeycomb). SIEMPRE debe estar presente el fondo de panales de abejas (`HoneycombPainter`). El `Scaffold` debe tener como `body` un `Stack` cuyo primer hijo sea `Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: const HoneycombPainter())))`. El resto del contenido debe ir encima en la pila. No olvides importar `../backend/design_tokens.dart` si no estÃ¡ importado.
5. **Sin Excepciones:** No existe lista negra de pÃ¡ginas.
6. **Reporte:** Una vez hecho el cambio con replace_file_content, avÃ­sale al usuario que has completado el proceso resumiendo quÃ© cambios especÃ­ficos lograste aplicar. **No pidas permiso, edita el cÃ³digo directamente**.
7. **Despliegue AutomÃ¡tico (Git Push):** Al finalizar los cambios en el cÃ³digo, DEBES ejecutar obligatoriamente los comandos para subir a producciÃ³n: `git add .`, seguido de `git commit -m "style: aplicar premium_ui a [nombre_de_la_pagina]"` y por Ãºltimo `git push origin HEAD`. Notifica al usuario que los cambios se desplegarÃ¡n en Vercel en 2 minutos.
