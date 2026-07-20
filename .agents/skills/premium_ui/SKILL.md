---
name: premium_ui
description: >
  Aplica el manifiesto de Diseño Premium a una página de la PWA. Incluye márgenes asimétricos, 
  GeoSidebar, botón de volver unificado y ajustes de tipografía/layout según las reglas establecidas.
---

# Skill: premium_ui

Esta habilidad se encarga de estandarizar visual y arquitectónicamente las pantallas de GeoLogística PWA.

## Cuándo usar esta habilidad
Se activa cuando el usuario solicita aplicar el "diseño premium", "estandarizar diseño", "skill premium" o "aplica premium ui" a una página específica.

## Instrucciones de Ejecución (Para el Agente)

1. **Lectura Obligatoria:** Si aún no lo has hecho en esta sesión, debes leer el archivo de manifiesto ubicado en los artefactos de la conversación actual: `premium_design_standard.md`.
2. **Análisis de la Página:** Lee el código fuente del archivo solicitado (ej. `lib/pages/rutas_page.dart`).
3. **Validación de Complejidad (Failsafe):** 
   - Analiza la estructura actual del archivo. Si el layout es extremadamente atípico o complejo y al inyectar un `Row` con `GeoSidebar` corres un alto riesgo de romper la vista por completo, **DETENTE**.
   - No modifiques el archivo. Notifica al usuario del problema arquitectónico y ofrécele opciones sobre cómo proceder.
4. **Aplicación Directa:** Si la vista es manejable, aplica directamente las reglas del manifiesto editando el código fuente:
   - **Regla 1:** Inyectar `GeoSidebar` en un `Row` principal para Desktop y el contenido en un `Expanded`.
   - **Regla 2:** Padding asimétrico `EdgeInsets.fromLTRB(120, 0, 40, 0)` en el contenido. Remover `maxWidth` y `Center`.
   - **Regla 3:** Control de proporciones con `LayoutBuilder`.
   - **Regla 4:** La cabecera debe incluir SIEMPRE dos botones de navegación (`InkWell` + Contenedor 36x36 blanco + sombra): 
     1. Un botón de "Atrás" (`Icons.arrow_back_ios_new_rounded`) con la lógica `context.canPop() ? context.pop() : null` (si se puede volver, vuelve).
     2. Un botón de "Home" (`Icons.home_rounded`) con la lógica `context.go('/home')` ubicado justo al lado del botón de atrás. Toda página debe garantizar que existe el logo/botón "Home" visible en todo momento para regresar al inicio de manera segura.
   - **Regla 5:** Todos los botones principales de acción (tipo `ElevatedButton`, "NUEVO VIAJE", "NUEVA SOLICITUD") deben tener un `BorderRadius.circular(8)` para mantener la consistencia con el diseño de Login y Sidebar. 
     - **MUY IMPORTANTE (Escritorio):** En la versión de Escritorio (Desktop), los botones principales NUNCA deben ser botones flotantes (`FloatingActionButton`) en la esquina inferior. DEBEN renderizarse como `ElevatedButton` ubicados en la esquina superior derecha de la cabecera (junto a los filtros o buscador) utilizando siempre `DesignTokens.primaryButtonStyle` (el cual debe usar el color verde oscuro y la tipografía Manrope FontWeight.w700 tamaño 15, idéntico al botón INICIAR). En móviles, sí pueden ser botones flotantes.
5. **Sin Excepciones:** No existe lista negra de páginas.
6. **Reporte:** Una vez hecho el cambio con replace_file_content, avísale al usuario que has completado el proceso resumiendo qué cambios específicos lograste aplicar. **No pidas permiso, edita el código directamente**.
7. **Despliegue Automático (Git Push):** Al finalizar los cambios en el código, DEBES ejecutar obligatoriamente los comandos para subir a producción: `git add .`, seguido de `git commit -m "style: aplicar premium_ui a [nombre_de_la_pagina]"` y por último `git push origin HEAD`. Notifica al usuario que los cambios se desplegarán en Vercel en 2 minutos.
