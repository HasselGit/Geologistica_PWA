# Sesión Actual - 1 de Junio, 2026

## 🛡️ Hito de Seguridad: Consolidación de Reglas de Negocio, Auditoría de Cargas y Control Total de Paradas

En esta sesión implementamos con éxito el paquete de seguridad operativo, auditoría y control de depósito/ruta más exhaustivo de **GeoLogística**, resolviendo brechas de lógica y blindando la integridad operativa para evitar retrocesos causados por cualquier agente de IA o desarrollador en el futuro.

> [!IMPORTANT]
> **SALVAGUARDA CONTRA CAMBIOS FUTUROS**:
> Para garantizar que ninguna de estas reglas de negocio críticas pueda ser alterada, modificada o eliminada por ningún agente de IA en el futuro, se ha actualizado el **Master Blueprint** del proyecto: [ARQUITECTURA_GEOLOGISTICA.md](file:///c:/Users/Parque-Apicola/Desktop/Geologistica/ARQUITECTURA_GEOLOGISTICA.md).
> **Cualquier agente que retome el proyecto DEBE respetar a rajatabla la Sección 20 de dicho documento**, la cual define las restricciones inmutables de estados, roles, depósitos y controles operativos.

---

### 🛑 1. Control de Paradas y Cierre Manual por el Chofer (Eliminación de Auto-Cierre)
- **Brecha Resuelta**: El sistema anteriormente auto-finalizaba las paradas al registrar un remito individual, impidiendo la emisión de múltiples remitos si el chofer tenía que entregar carga de distintos orígenes o a diferentes personas en la misma parada.
- **Implementación**:
  - En `supabase_service.dart`, eliminamos por completo el auto-cierre asíncrono al guardar remitos.
  - Añadimos en `paradadetalle.dart` (el visor de paradas del chofer) el botón de acción explícita **"FINALIZAR PARADA"**.
  - Este botón es de uso exclusivo del chofer y es el único mecanismo por el cual la parada pasa a estado `'Terminada'` en la base de datos de Supabase.
  - Al cerrar la parada, todas las cantidades y productos relacionados en los remitos se consolidan de forma permanente a todos los niveles. Una vez cerrada, la parada se vuelve estrictamente de **Solo Lectura** (excepto para el rol Super-Administrador `hassel00@gmail.com`).

### 📦 2. Prevención de Cargas Vacías y Auditoría de Identidad del Creador
- **Control de Cargas Vacías**: Modificamos la validación transaccional al momento de crear una carga. El sistema valida y bloquea de manera absoluta la creación de cualquier carga si esta no tiene al menos un producto con una cantidad asignada mayor a cero.
- **Auditoría e Identidad (`creado_por`)**: En la tabla `cargas` de Supabase se graba el perfil o rol del usuario logueado que realizó la carga (ej. `CEO`, `COMPRAS`, `GERENCIA`, `DEPOSITO`). Esta información de auditoría se recupera dinámicamente y se muestra con claridad en la ficha de detalle de la carga.

### 🚫 3. Restricción de Roles en la Creación de Cargas (Choferes Bloqueados)
- **Regla de Negocio**: Los choferes **no** están autorizados a crear cargas bajo ningún concepto.
- **Implementación**: Blindamos la interfaz del usuario. Si el rol detectado en la sesión local corresponde al de Chofer, el botón de crear nueva carga en `depositohome.dart` y los formularios de edición se deshabilitan por completo. Únicamente los roles directivos y de soporte administrativo (`CEO`, `Compras`, `Gerencia`, `Depósito`) pueden registrar cargas.

### 🏭 4. Diferenciación Crítica de Depósitos (Huinca vs Parque Industrial - PI)
- **Depósito Huinca (Cargas en Viaje Activo)**: Los choferes pueden cambiar de estado las cargas planificadas en el depósito Huinca, dado que ellos mismos realizarán esta tarea física en un viaje que ya se encuentra "En Curso".
- **Depósito Parque Industrial (PI)**: Está estrictamente prohibido asignar cargas de PI a un viaje que ya está en curso. El camión no puede salir a ruta con cargas pendientes en Parque Industrial. El sistema analiza esto reactivamente en `viaje_detalle.dart` y **bloquea el botón "INICIAR VIAJE"** (mostrando una advertencia descriptiva) si detecta que el viaje contiene cargas PI en estado `Pendiente`.

### 💰 5. Robustez en el Módulo de Gastos (`gastos_page.dart`)
- **Filtro de Viajes por Chofer**: Los conductores únicamente visualizan y pueden imputar gastos sobre sus propios viajes asignados, limpiando la vista y evitando errores cruzados de imputación.
- **Pre-selección Predictiva**: Al abrir el diálogo para registrar un nuevo gasto, el sistema auto-detecta y pre-selecciona el viaje que el chofer tiene `'En Curso'` actualmente.

### 🧹 6. Simplificación de la Pantalla Principal (Eliminación de Redundancias para Choferes)
- **Problema de Redundancia**: Los choferes tenían acceso a múltiples tarjetas genéricas de navegación en la pantalla principal (`homepage.dart`) y en el menú drawer lateral (como "Depósito Huinca", "Productos", "Control de Ruta", "Gastos" y "Control Pesajes") que saturaban la interfaz, ya que el chofer ya opera de forma 100% contextual desde su panel dedicado **"Mis Viajes"**.
- **Solución Implementada**:
  - Inhabilitamos la visibilidad de los módulos de **Depósito Huinca**, **Productos**, **Control de Ruta**, **Gastos** y **Control Pesajes** en la cuadrícula de la pantalla principal exclusivamente cuando el rol del usuario logueado es **Chofer**.
  - Ocultamos los mismos ítems del menú drawer lateral (`_drawerItem`) para el rol Chofer, manteniendo la interfaz sumamente limpia y orientada únicamente a su flujo de trabajo central en **"Mis Viajes"**.

### 📝 7. Inclusión de Depósito en Remitos y Redirección de Choferes
- **Navegación Unificada**: Cambiamos la acción del botón **CARGAS** en el panel del chofer (`choferhome.dart`) para que en lugar de abrir la pantalla de sólo lectura `cargas_page.dart` (que no mostraba el botón Honey Gold **REMITO** ni el diseño correcto), redirija a la pantalla oficial de depósito `/depositoHome` (`depositohome.dart`).
- **Saneamiento de Tarjetas Ficticias**: Modificamos el método `_getActiveItems()` para eliminar por completo la generación de las confusas tarjetas ficticias `viaje_sin_carga` ("SIN CARGA") de la pestaña **PENDIENTES** para todos los roles. Ahora, las tres pestañas muestran únicamente cargas físicas reales del sistema.
- **Selector de Depósito en Carga**: Añadimos un selector de depósito (`deposito_origen`) obligatorio en el formulario para crear nuevas cargas (`_showAddCargaDialog`). Si el usuario es un **Chofer**, el campo dropdown se inactiva y pre-selecciona `'Depósito Huinca'`, permitiéndole crear y asociar cargas en su viaje en curso. Los roles Depósito, CEO, Compras y Gerente conservan el selector desbloqueado para elegir libremente.
- **Origen en PDFs de Remitos**: Actualizamos las plantillas de generación de remito digital cliente (`remito_page.dart`) y remitos de báscula (`remito_registro.dart`). El generador de PDF (`pdf_invoice_generator.dart`) ahora recibe el parámetro opcional `depositoOrigen` de forma asíncrona a partir del viaje y lo despliega formalmente en el área de metadatos bajo el campo **"Depósito de Carga"**.


### 🛑 8. Corrección de Desastres de Diseño, Integridad de Base de Datos y Robustez en Gastos
- **Prevención de Desbordamiento Horizontal (Visual Desastre)**: En `depositohome.dart`, corregimos el desbordamiento horizontal en las cabeceras de las tarjetas de cargas envolviendo el texto descriptivo del lado derecho en un widget `Flexible` con `TextOverflow.ellipsis` y limitando a `maxLines: 1`. Esto asegura que en pantallas estrechas el texto del chofer y el vehículo se corten elegantemente sin generar el desastre de las líneas amarillas y negras de desbordamiento.
- **Visualización de Depósito de Origen**: Se añadió debajo de la información del chofer un indicador de depósito con el icono `Icons.warehouse_rounded`, que muestra el depósito de origen limpio de la carga.
- **Saneamiento y Deserialización Limpia de Cargas**: Modificamos el mapping de `rawList` para sanitizar las propiedades de las cargas. Limpiamos `carga_codigo` y separamos correctamente `deposito_origen` de forma asíncrona, evitando que datos raw de Supabase se muestren de forma incorrecta.
- **Solución al Conflicto de Tipos en Supabase (invalid input syntax for type integer: "150.0")**: La columna `carga_items.cantidad` tiene restricción estricta de tipo `integer` en Postgres. Al guardar cantidades con decimales (doubles) como `150.0` o `125.0`, la transacción fallaba y se revertía por error de sintaxis SQL.
  - En `depositohome.dart`, aplicamos `.round()` a `cant` y `customQty` antes de insertarlos en el arreglo `itemsToInsert`.
  - En `supabase_service.dart`, modificamos `updateCargaItems` para forzar a enteros todas las cantidades pasadas en la actualización mediante `.toInt()`.
- **Filtro de Email por SharedPreferences (Bypass Auth)**: Dado que la aplicación utiliza un bypass del flujo tradicional de login y `Supabase.auth.currentUser` es `null`, la consulta de gastos y cargas filtraba incorrectamente por un email nulo. Corregimos esto resolviendo el `userEmail` dinámicamente desde `SharedPreferences` tanto en `depositohome.dart` como en `gastos_page.dart`.
- **Validaciones Estrictas en el Formulario de Gastos**: Implementamos validaciones requeridas de forma robusta al guardar un gasto en `gastos_page.dart`. El sistema bloquea de manera absoluta la confirmación de un gasto si:
  - El campo de **importe** está vacío o es cero.
  - El **número de comprobante** está en blanco.
  - No hay un **viaje seleccionado / asociado**.
  - Si el tipo de gasto es **Combustible**, valida estrictamente que el campo de **litros** no esté vacío y contenga un valor numérico mayor a cero.


---

## 🛡️ Hito de Seguridad: Reglas de Proyecto y Consistencia de Cargas en Depósito (2 de Junio, 2026)

En esta sesión implementamos con éxito salvaguardas universales contra retrocesos de asistentes de IA y resolvimos de raíz los problemas visuales, de navegación y consistencia lógica en el visor de depósitos (`depositohome.dart`):

### 🛑 9. Inyección de Salvaguardas del Sistema (Anti-Regresiones de IA)
- **Instrucción Crítica en `README.md`**: Agregamos un banner ineludible en el encabezado de `README.md` que obliga a cualquier agente futuro a consultar el Master Blueprint y la bitácora de sesión antes de realizar cualquier cambio en el código.
- **Creación de `.cursorrules` y `.clinerules`**: Creamos estos archivos en la raíz del proyecto para bloquear de forma inmutable las directrices de bypass de autenticación (uso de `SharedPreferences`), la conversión obligatoria a enteros en Supabase para evitar el error `"invalid input syntax for type integer: '150.0'"`, el cierre manual de paradas por choferes y la exclusividad de creación de cargas para roles administrativos.

### 🛑 10. Saneamiento de Tarjetas Vacías y Navegación de Cargas
- **Filtrado de Cargas Vacías/Corruptas**: Corregimos el método `_getActiveItems()` para filtrar y omitir cargas vacías (`carga_items.isEmpty`), resolviendo el problema de las tarjetas fantasma con 0 kg y 0 tambores en la pestaña de Pendientes.
- **Redirección de Navegación (`onTap`)**: Cambiamos la acción de presionar la tarjeta de carga para que redirija de manera correcta al visor de detalle de carga (`/cargaDetalle?id=X`) en lugar del detalle de viaje.
- **Visualización Premium Vertical de Insumos**: Rediseñamos el cuerpo de la tarjeta de carga (`_buildViajeCard`) para desplegar una lista vertical elegante que detalla explícitamente los nombres y códigos de los productos cargados junto a sus cantidades en badges, resolviendo descripciones en base al catálogo y asignando iconos según el tipo de producto.

### 🛑 11. Restricciones y Permisos de Parque Industrial (PI) vs. Depósito Huinca
- **Restricción de PI con Viaje en Proceso**:
  - En `_getActiveItems()`, si el viaje está `'En Curso'`, cualquier carga activa de Parque Industrial se omite automáticamente del listado (ya que debe estar finalizada para que el viaje pueda haber iniciado).
  - En `_showAddCargaDialog`, si el viaje seleccionado está `'En Curso'`, el dropdown de depósito de origen se bloquea y restringe mostrando únicamente la opción `'Depósito Huinca'`, impidiendo la creación de cargas de PI con el viaje en proceso.
- **Habilitación de Acciones Huinca Exclusivas al Chofer Asignado**: Los botones de acción física "INICIAR CARGA" y "FINALIZAR CARGA" de cargas de Huinca en ruta se habilitan **únicamente** si el usuario en sesión es el chofer asignado a dicho viaje. Para otros usuarios o choferes no asignados, los botones se deshabilitan mostrando la indicación `'ASIGNADO A OTRO CHOFER'`, mientras que el botón "EDITAR" se oculta por completo para todos los choferes, reservándose a roles administrativos.

---

## 💾 Estado del Proyecto y Verificación
- **Flutter Analyze**: **0 errores estáticos.** Todo el código cumple con las directrices más estrictas de Flutter/Dart.
- **GitHub**: Cambios listos para commit y push.

## 🖥️ Recordatorio para Futuros Agentes / Desarrolladores:
> [!CAUTION]
> **NO MODIFICAR**: La advertencia de IA en el README, los archivos de reglas .cursorrules/.clinerules, el filtrado de cargas vacías y las restricciones de depósitos PI/Huinca con viajes en curso son reglas inmutables del negocio para asegurar cero regresiones en producción.

---

## ⚖️ Hito de Integridad: Unificación de Remitos, Persistencia de Pesajes y Limpieza en Home (2 de Junio, 2026 - Continuación)

En esta sesión unificamos estéticamente los remitos oficiales de pesaje y cargas, y garantizamos la persistencia y auditoría de los pesajes realizados en terreno:

### 🛑 12. Unificación Estética del Remito de Pesajes
* **Estandarización de Firma Digital**: Modificamos el generador de PDF `generateWeighingRemitoPDF` en `pdf_invoice_generator.dart` para reemplazar la insignia `"CERTIFICADO DE TRÁNSITO GEOMIEL"` (Honey Gold) por el sello verde `"FIRMA DIGITAL VERIFICADA"`, alineándolo con la estética del remito de cargas.
* **Caja de Totales Elegante**: Rediseñamos la visualización de los totales en el PDF para usar la estética minimalista de cargas (fondo gris claro `#F8FAFC`, borde sutil `#E2E8F0`, desglose de peso bruto, tara y neto total, con el neto destacado en verde `secondaryColor`).
* **Soporte de Cabecera**: Se mantuvo intacto el diseño proporcional de la cabecera con el logo de Geomiel y dirección a la izquierda y el logo de GeoLogística a la derecha.
* **Corrección de Typos**: Se corrigió el typo de `"FIRMATE / RESPONSABLE:"` por `"FIRMANTE / RESPONSABLE:"` en la sección de datos.

### 🛑 13. Persistencia de Pesajes y Solución a la Desaparición de Datos
* **Persistencia en base de datos**: Eliminamos el borrado automático de pesajes en caliente que se ejecutaba en `remito_registro.dart` (línea 517) al emitir un remito. Ahora los datos de pesaje de tambores se preservan indefinidamente en Supabase.
* **Visualización en Detalle de Viaje**: Gracias a la persistencia de pesajes, la tarjeta interactiva de pesajes en `viaje_detalle.dart` y la pantalla global de pesajes (`pesajes_page.dart`) ahora se muestran y desglosan correctamente con todos sus detalles.
* **Limpieza de Alertas**: Se reemplazó la palabra "balanza" en la advertencia de mismatch por `'Sugerido: ${_pesajes.length} TCM según pesajes registrados.'` en `remito_registro.dart` (línea 1647).

### 🛑 14. Simplificación del Panel de Inicio (Home)
* **Remoción de Estado de Cargas**: Se eliminó por completo el widget de la franja de estadísticas de `"ESTADO DE CARGAS"` en `homepage.dart` para limpiar la UI y evitar redundancias operativas.

### 🛑 15. Filtrado de Pesajes por Apicultor, Remitos Simplificados y Resolución de ID Dinámico (3 de Junio, 2026)
* **Filtrado en Caliente por Apicultor**: Modificamos `agregar_pesaje.dart` para que la lista de tambores registrados y el total de kilos se filtren en tiempo real por el apicultor seleccionado en el dropdown, guardando y editando solo los registros del apicultor activo en la sesión.
* **Resolución de apicultor_id en Paradas**: Descubrimos que la columna `apicultor_id` no existe en la tabla `paradas`. Modificamos `remito_registro.dart` para resolver el ID del apicultor titular dinámicamente mediante consultas cruzadas a la tabla `solicitudes` usando `solicitud_id`. 
* **Asociación de Pesajes sin ID**: Modificamos los filtros de pesajes en `remito_registro.dart` para asociar los pesajes de base de datos con `apicultor_id == null` al apicultor principal/titular de la parada en curso (`_titularIdOfParada`). Esto resolvió el problema donde la planilla técnica de Denis Capello se cargaba vacía.
* **Tabla de Pesaje Simplificada (Sin Pesar)**: Si un lote no tiene peso (el primer tambor tiene peso bruto `0.0`), la UI en `remito_registro.dart` y el PDF generado en `pdf_invoice_generator.dart` renderizan una tabla sutil de 3 columnas (`N°`, `Código SENASA`, `Detalle: Sin pesar`), ocultando todas las columnas y totalizadores vacíos de kilos.
* **Evitar Colisiones de Clave Única**: Implementamos una consulta de conteo de remitos en la parada para añadir sufijos secuenciales (`-2`, `-3`) en el `numero_remito`, esquivando errores de inserción de Supabase.
* **Cálculo de Finalización del Viaje**: En `supabase_service.dart`, el método `finalizarParada` calcula el peso neto del viaje totalizando los pesajes reales de Supabase y aplicando un fallback de `300.0` kg para tambores sin pesar. Sincroniza la cantidad del producto `TCM` en `parada_items` con la cantidad de tambores pesados.

---

## ⚖️ Hito de Integridad: Espectro Ampliado - Registro de Tambores Sin Pesar, Colecciones Simples y Estado Multi-Remito (5 de Junio de 2026)

En esta sesión expandimos el comportamiento de los remitos continuos y el control operacional de tambores y colecciones simples para erradicar ambigüedades operativas y mejorar la UX del chofer en terreno:

### 🛑 16. Nomenclatura Dinámica ("Registro" vs. "Pesaje") y Recordatorios de SENASA
- **Nomenclatura Dinámica**: Cuando un chofer registra tambores pero no pesa (switch `REGISTRAR PESOS` apagado o `peso_bruto == 0.0`), se prohíbe el término "Pesaje" en la UI y documentos. La pantalla pasa a ser `"Registro de Tambores"`, ocultando las tarjetas de bruto/tara/neto.
- **Detalle de Tambores Registrados**: En la pantalla de remito, el desglose técnico cambia a `"📝 DETALLE DE TAMBORES REGISTRADOS"` (en vez de "⚖️ PLANILLA DE PESAJE TÉCNICA"). En el PDF se imprime `"DESGLOSE DE TAMBORES REGISTRADOS:"`.
- **Botón Contextual en Parada**: En `paradadetalle.dart`, la etiqueta de ingreso se calcula dinámicamente:
  - `"REGISTRAR TAMBORES / PESAJE"` si no hay tambores registrados.
  - `"MODIFICAR TAMBORES RECOLECTADOS"` si se registraron sin pesos.
  - `"MODIFICAR PESAJE DE TAMBORES"` si se registraron con pesos.
- **Banner de Recordatorio de SENASA**: Si el chofer apaga el switch de pesaje, se despliega una tarjeta roja de alerta que le recuerda: `"¡IMPORTANTE! Recordá recolectar el código SENASA de cada tambor. No se registrarán pesos."`.

### 🛑 17. Soporte para Recolecciones "Simples" (No-TCM)
- **Recolecciones Simples**: Los productos que no son TCM (como cera operculo `CO`/recupero `CR`, tambores vacíos `TRR`/`TRC`, azúcar `AZ`, etc.) no tienen pesos ni códigos SENASA asociados. Siguen la vía de edición directa en la confección de remito, donde el chofer puede ajustar cantidades directamente usando botones de incremento/decremento (`+/-`).

### 🛑 18. Indicador de Estado Multi-Remito en Viaje
- **Visualización en Detalle de Viaje**: En `viaje_detalle.dart`, el estado de remito de la parada ahora se evalúa contra `remitos.isNotEmpty` y `remitos.isEmpty` en vez de `p['remito_id'] != null`. Esto asegura que el estado se refleje como `"REMITO: EMITIDO"` correctamente cuando hay uno o más remitos de terceros ya generados para la parada.




# Sesión Actual - 23 de Junio, 2026

## 🎨 Hito de Diseño: Rediseño Responsivo Estricto basado en el Sistema STITCH (Fase 4)

En esta sesión implementamos con éxito el rediseño responsivo adaptativo (Desktop-First / Mobile-Adaptive) de **GeoLogística (PWA)**, estructurando los layouts bajo los lineamientos visuales del sistema **STITCH** y protegiendo el escalado en pantallas grandes:

### 1. Panel Lateral Fijo y Drawer Adaptativo
- Se implementó `LayoutBuilder` en las pantallas clave: `homepage.dart`, `agregar_pesaje.dart`, `pesajesitem.dart` y `remito_registro.dart`.
- Si la pantalla es ancha (>= 1024px), se muestra un **Sidebar fijo** a la izquierda con fondo Deep Forest Green (`#08201A`), destacando los elementos activos en Honey Gold y mostrando el perfil del usuario activo (cargado de `SharedPreferences`).
- En dispositivos móviles o pantallas estrechas (< 1024px), el panel se colapsa en un `Drawer` estándar para la navegación cómoda de los choferes en el campo.

### 2. Límites de Escala (MaxWidth 1200px)
- Para evitar que la UI se estire de forma desproporcionada en monitores de escritorio de alta resolución, el contenido principal se centró horizontalmente y se envolvió en un `ConstrainedBox` con un límite estricto de `maxWidth: 1200px`.
- Se bloquearon los tamaños de las fuentes tipográficas en `design_tokens.dart` (`headlineStyle` a 22px, `bodyStyle` a 14px, `labelStyle` a 12px) y en los estilos de texto específicos para evitar el sobredimensionamiento.

### 3. Focos e Integridad en Formularios
- Configuración de Honey Gold (`#C68E17`) como color de borde para el estado enfocado de los campos del formulario de pesajes (`SENASA`, `Bruto`, `Tara`), brindando una respuesta táctil/visual de alta fidelidad.
- En `remito_registro.dart`, el lienzo de dibujo de la firma digital (`Signature`) se fijó físicamente a una resolución exacta de **`360x130`** píxeles dentro de un widget `Center`, impidiendo que el lienzo se deforme o estire en pantallas grandes.

### 4. Compilación Completa Web
- Validamos el código de la PWA con `flutter analyze lib/` (0 errores estáticos) y completamos con éxito la compilación para web (`flutter build web --release`).
- Se realizó el deploy exitoso de producción en Vercel: https://geologistica-pwa.vercel.app

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

---

## 🍯 Hito Logístico: Soporte Multi-Apicultor, Optimización UI y Visor de Remitos Nativo (8 de Julio, 2026)

En esta sesión perfeccionamos la pantalla de `Operación en Parada` (`paradadetalle.dart`) para soportar operaciones complejas con múltiples apicultores por parada, eliminando redundancias visuales y arreglando el flujo de documentos PDF.

### 👥 1. Soporte Real para Múltiples Apicultores por Parada
- **El Problema**: Cuando una misma parada (mismo SENASA y ubicación) recogía tambores de distintos apicultores (ej. Urrutia y Zupan), la UI colapsaba omitiendo la "Ficha del Apicultor" en móviles y ocultaba remitos heredados.
- **La Solución**: Se refactorizó la generación de tarjetas, garantizando que cada apicultor detectado en la parada tenga su propia ficha y recuadro de remitos, tanto en la vista móvil como en escritorio.

### 📐 2. Diseño Compacto de Ficha de Apicultor
- **El Problema**: La información de la parada (Ubicación, Localidad, Tipo, Estado, Secuencia) se repetía en una larga columna vertical para cada apicultor, generando un scroll excesivo.
- **La Solución**: Se introdujo un widget `Wrap` que redistribuye estos atributos de forma horizontal en un layout tipo grilla, acortando la altura de cada ficha en más de un 50% y maximizando la densidad de información sin reducir el tamaño de letra.

### 📄 3. Visor de PDF Nativo e Impresión Directa
- **El Problema**: El plugin interno (`pdf_preview`) mostraba el remito de forma desproporcionada, causaba errores en algunos navegadores web y dificultaba la impresión rápida de los comprobantes por parte de los choferes.
- **La Solución**: 
  - Se eliminó el uso del popup/plugin integrado para la web.
  - Al presionar el remito, este ahora se abre mediante `launchUrl(..., webOnlyWindowName: '_blank')`, delegando la renderización al **visor nativo** del navegador, que escala perfectamente.
  - Se añadió un botón explícito de **Impresora** a cada tarjeta de remito. Utilizando `Printing.layoutPdf()`, este botón envía el archivo de inmediato a la cola de impresión del sistema operativo, acelerando dramáticamente la logística en campo.

### 👻 4. Corrección de Remitos Legados o Huérfanos
- **El Problema**: Los remitos generados en versiones anteriores de la app no tenían el campo `apicultor_id` grabado en la tabla. Al haber varios apicultores, el sistema no sabía a quién asignárselo y lo invisibilizaba.
- **La Solución**: Se añadió lógica de *fallback*. Si el sistema detecta un remito donde `apicultor_id` está vacío, lo asignará proactivamente al Apicultor Principal (el creador/dueño lógico de la parada), evitando la pérdida visual de comprobantes en paradas compartidas.

---

## 🎨 Hito Estético: Diseño Premium Bento y Responsiveness (18 de Julio, 2026)

En esta sesión implementamos una estandarización visual premium sobre los formularios y modales de detalles, resolviendo problemas críticos de renderizado en pantallas pequeñas.

### 🍱 1. Integración de Diseño Bento en Detalle de Gastos
- **El Problema**: El modal de "Detalle de Gasto" renderizado desde `viaje_detalle.dart` usaba un layout de lista vertical antiguo codificado en duro (hardcoded), que ignoraba completamente el diseño premium y desaprovechaba el espacio en resoluciones anchas. Además, confundía al usuario con una enorme marca de agua que simulaba ser el ticket.
- **La Solución**: Se eliminó la generación en duro del modal en `viaje_detalle.dart` y se conectó con el widget independiente `GastosDetalleDialog`. Ahora se presenta un diseño con cuadrículas (Tarjetas tipo Bento), íconos categorizados y espacios negativos correctos que jerarquizan Importe Total y Tipo de Gasto.

### 📱 2. Responsiveness Adaptativo 
- **El Problema**: Al usar anchos fijos (ej. 380px) para el diseño de escritorio en el nuevo componente Bento, las pantallas pequeñas sufrían desbordamientos (overflows) donde los componentes se "envolvían" caóticamente (Wrap), rompiendo los márgenes y empujando las tarjetas fuera del área visible de la pantalla.
- **La Solución**: Se eliminó el uso de `Wrap` y se reconstruyó la lógica estructural empleando un `LayoutBuilder`. Ahora, si la pantalla tiene más de 600px de ancho, los elementos se subdividen proporcionalmente mediante `Row` y `Expanded`. Si es menor a 600px, el diseño colapsa limpia y ordenadamente a un formato `Column` de ancho completo, sin desbordes.

### 💀 3. Skeleton Loaders Uniformes
- **El Problema**: Algunas páginas, como `carga_detalle.dart`, no mostraban estado de carga estandarizado, generando parpadeos en blanco.
- **La Solución**: Se implementó una pantalla de carga tipo esqueleto estructural básico que respeta la posición real del `GeoSidebar`, entregando un feedback visual inmediato e impecable durante el fetching de la base de datos de Supabase.
# #   S e s i o n   2 3 / 0 7 / 2 0 2 6   -   M e j o r a s   e n   D e t a l l e   A p i c u l t o r  
 -   S e   a c t u a l i z o   a p i c u l t o r _ d e t a l l e . d a r t   p a r a   s o p o r t a r   o n F i l t e r T a p ,   o n T a p   y   o n D o w n l o a d T a p   e n   l a s   c a b e c e r a s   d e   s e c c i o n .  
 -   S e   a n a d i o   l a   l o g i c a   d e   f i l t r a d o   r e a c t i v o   p a r a   O p e r a c i o n e s   R e c i e n t e s .  
 -   S e   i n c o r p o r o   l a   v i s t a   d e   H i s t o r i a l   d e   P e s a j e s   q u e   n a v e g a   h a c i a   l a   p r e v i s u a l i z a c i o n   d e l   r e m i t o   ( p d f _ i n v o i c e _ g e n e r a t o r ) .  
 -   S e   a j u s t o   _ b u i l d E m p t y S t a t e   p a r a   r e c i b i r   o n T a p   y   e n v o l v e r   e n   M a t e r i a l + I n k W e l l .  
 -   S e   c o r r i g i e r o n   l a s   r e f e r e n c i a s   d e   p r o d u c t o ,   p e s o _ b r u t o ,   t a r a   y   k i l o s _ n e t o s   e n   _ b u i l d P e s a j e C a r d .  
 