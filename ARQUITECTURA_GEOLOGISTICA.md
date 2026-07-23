# Master Blueprint: Arquitectura y Lógica de GeoLogística
**Versión:** 1.7 (1 de Junio de 2026)
**Objetivo:** Proveer una guía técnica infalible para la reconstrucción o continuación del proyecto por cualquier IA o desarrollador, garantizando 0 retrocesos.

---

## 1. Pilares Arquitectónicos
- **Framework:** Flutter (Canal Stable).
- **Backend:** Supabase (PostgreSQL + Realtime + Storage Buckets).
- **Diseño:** "Stitch Premium". Colores: `Deep Forest Green` (#1E302C), `Honey Gold` (#C68E17). Tipografía: Inter/Outfit.
- **Navegación:** `GoRouter` para manejo de pilas y rutas declarativas.

## 2. Estrategias Críticas (No Cambiar)
### A. Autenticación "Bypass" (Estabilidad de Hilo UI)
- **Problema:** El SDK de Supabase Auth causa deadlocks en emuladores Android al usar teclados.
- **Solución:** Se utiliza un sistema de login directo consultando la tabla `profiles`.
- **Implementación:** `SupabaseService.login(email, password)` busca coincidencias exactas en la tabla pública y guarda la sesión en `SharedPreferences`.
- **Importante:** Las pantallas NO deben usar `Supabase.auth.currentUser`. Deben usar el `user_id` guardado localmente.

### B. Gestión de Identidad del Chofer
- **Regla de Oro:** Todas las asignaciones de viajes (`viajes.chofer_id`) DEBEN usar el **UUID** (id de la tabla profiles) y NO el correo electrónico.
- **Impacto:** Si se usa el correo, el rol Chofer no verá sus viajes en el Home y no podrá operar.

### C. Lógica de Estados de Operación
Las solicitudes y viajes siguen un circuito de estados estricto:
1. `Pendiente`: Creada por el apicultor/gerente.
2. `Asignada`: Vinculada a un viaje (parada) pero el viaje no ha iniciado.
3. `En Curso`: El viaje ha sido iniciado por el chofer.
4. `Terminada / Finalizada`: Operación completada con remito generado.
5. `Eliminada` (Borrado Lógico): Para evitar violaciones de integridad referencial histórica o fallos de políticas RLS, la eliminación de una solicitud actualiza su estado a `'Eliminada'`. Las vistas del planificador, estadísticas y perfiles las filtran de forma activa.

## 3. Estructura de Datos y Relaciones
- **Viajes -> Paradas**: Un viaje tiene múltiples paradas.
- **Paradas -> Solicitudes**: Cada parada está vinculada a una `solicitud_id`.
- **Solicitudes -> Remitos**: Una solicitud terminada se vincula a un remito a través de la parada.
- **Cargas -> Vehículos**: Las cargas actualizan el stock "en circulación" del vehículo (`carga_actual_kg`).

## 4. Dashboard de Apicultor (Módulo Crítico)
- **Archivo:** `lib/pages/apicultor_detalle.dart`.
- **Lógica de Fetch:** Debe buscar solicitudes usando múltiples candidatos de ID (con/sin prefijo 'A', con/sin ceros a la izquierda) para asegurar visibilidad 100%.
- **Resumen:** Se agrupa por producto y se cuenta por estado (Pendientes, Asignadas, En Curso, Terminadas).

## 5. Prevención de Errores Comunes (Checklist)
- [ ] **Cascada de Eliminación**: Al borrar un viaje, limpiar primero `carga_items`, luego `cargas`, luego `parada_items`, luego `paradas`, y finalmente el viaje. Liberar solicitudes (`estado = 'Pendiente'`).
- [ ] **Saneamiento de Solicitudes Eliminadas**: Toda consulta que adquiera solicitudes de forma global debe filtrar `.neq('estado', 'Eliminada')` para prevenir persistencias indeseadas en planificadores, dashboards o perfiles de apicultores. **CRÍTICO**: `getNecesidadesPendientes()` también debe incluir `.neq('estado', 'Eliminada')` como doble seguridad, ya que el `.eq('estado', 'Pendiente')` y el `.neq('estado', 'Eliminada')` son redundantes pero necesarios para prevenir edge cases. El planificador al cargar solicitudes ya asignadas a un viaje en edición también debe filtrar `Eliminadas` explícitamente.
- [ ] **Desbloqueo de Parada en Proceso**: Una parada con estado DB `'Terminada'` pero sin remitos válidos (`remitos.isEmpty`) no debe considerarse de solo lectura para el chofer; esto permite al chofer completar pesajes pendientes y emitir el remito faltante.
- [ ] **Modal Overflow (BottomSheet con Teclado)**: Cuando un `showModalBottomSheet` contiene campos de texto, la técnica correcta es: (1) envolver el contenido en `Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom))`, (2) luego en `SafeArea(top: false)`, (3) luego el `Container` con `constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75)`. NUNCA aplicar el padding del teclado directamente al `Container` sin `maxHeight`.
- [ ] **Sintaxis Dart**: Mantener `dart analyze` con 0 errores. Evitar llaves de cierre accidentales que corten clases.
- [ ] **Refresh**: Siempre llamar a `_fetchDetailedData()` o equivalentes después de un `insert/update` para reflejar cambios en la UI.
- [ ] **Null Safety**: Usar `.maybeSingle()` y verificaciones de nulidad en campos como `localidad` y `nombre` (posibles swaps en DB).
- [ ] **Conversión Estricta a Entero para Cantidad de Carga**: La base de datos tiene una restricción de tipo entero para la columna `cantidad` en `carga_items`. Al guardar o editar ítems de carga, se DEBEN redondear o convertir los números a entero (`.round()` o `.toInt()`) para evitar errores fatales de sintaxis en Postgres (`invalid input syntax for type integer: "150.0"`).
- [ ] **Saneamiento de Consultas de Cargas Directas**: Al realizar consultas directas que evaden los helpers enriquecidos de `SupabaseService` (como en el visor de depósitos), es obligatorio mapear manualmente los campos decodificando valores limpios para `carga_codigo` y separando metadatos como `deposito_origen` de forma manual y robusta.
- [ ] **Bypass del Contexto de Autenticación Local**: Debido a que la app usa un bypass local de login mediante perfiles directos en `SharedPreferences`, `Supabase.auth.currentUser` retornará `null`. Cualquier filtro por correo o rol debe leer directamente los valores de `SharedPreferences` (`userEmail`, `userRole`, `userId`) en lugar de depender del SDK de Supabase Auth.
- [ ] **Evitar Desbordamiento en Cabeceras de Tarjetas**: Toda tarjeta con información de vehículo, chofer o metadatos de carga en la cabecera debe envolver las secciones flexibles en `Flexible` o `Expanded` combinados con `TextOverflow.ellipsis` y `maxLines: 1` para no causar desbordamientos horizontales.

## 6. Configuración de Entorno
- **Impeller:** Desactivado en Android para estabilidad gráfica.
- **Java:** JDK 17+ requerido.
- **Variables Supabase:** URL y Key Anon deben estar configuradas en `supabase_service.dart`.

## 7. Logística de Campo Avanzada (Multi-Remito)
### A. Sistema de Remitos Múltiples y Soporte de Terceros (Terceros)
- **Escenario**: Un apicultor responsable de la parada (por ejemplo, Hassel) puede entregar carga propia o de un tercero (por ejemplo, Leandro).
- **Implementación**:
  - En la parte superior de `RemitoRegistroPage`, se permite seleccionar un **Apicultor Titular del Remito** conectado con un buscador en tiempo real sobre todos los apicultores de la base de datos.
  - Esto desvincula al firmante físico del propietario de los tambores: el titular puede ser **Leandro** (Tercero) y el firmante físico puede ser el chofer o un empleado ("Un Tercero" con su nombre/DNI).
  - Al guardar el remito, la sincronización asocia el remito e impacta los volúmenes directamente en la ficha del **Apicultor Titular** seleccionado, manteniendo la integridad contable.

### B. Pesaje y Reconciliación "En Caliente"
- **Habilitación:** El módulo de pesaje se activa si existe un ítem con código `TCM` en la parada, sin importar la planificación original.
- **Reconciliación:** El sistema prioriza el conteo físico (registros en la tabla `pesajes`) sobre la cantidad planificada en `parada_items`. Al cargar la parada, se sincroniza la cantidad del ítem `TCM` con el conteo de pesajes.
- **Unidades:** Los ítems `TCM` deben usar siempre la unidad `uni` para el conteo individual de tambores.

### C. Firmas Digitales y Generación de PDF (Almacenamiento)
- **Captura**: Se capturan las firmas mediante un lienzo de dibujo y se exportan como PNG (`Uint8List`).
- **Almacenamiento**: No se guardan como cadenas base64 en la base de datos para no saturar las transacciones. En su lugar, se suben al Storage Bucket público de Supabase `remitos` mediante el helper robusto `_uploadFileWithAutoBucket`.
- **Registro**: Se guardan las URLs públicas `firma_url` y `pdf_url` (generadas mediante `Printing` y subidas al Storage) en la fila del remito en la base de datos.

### D. Preservación de Cantidades y Remito Continuo
- **Conservación de Datos**: Al confirmarse la firma y emisión del remito, **no** se restablecen a `0` las cantidades de `parada_items` ni se eliminan los `pesajes` físicos en Supabase. Esto asegura que la pantalla de *Detalle de Viaje* y los resúmenes ejecutivos preserven y muestren los valores reales completados en terreno.
- **Caché de UI**: En el retorno a `ParadaDetalleWidget`, los controladores locales se sincronizan y refrescan de forma segura para permitir ediciones o revisiones del estado de entrega.

### E. Nomenclatura Dinámica ("Registro" vs. "Pesaje") y Recordatorios de SENASA
- **Evitar Confusión**: Si el lote de tambores con miel (TCM) se registra sin pesos (es decir, el switch `REGISTRAR PESOS` se apaga o todos los tambores tienen peso bruto `0.0`), se prohíbe el uso de la palabra "Pesaje" en la UI, en los títulos del remito y en el PDF para evitar confusión al chofer.
- **Títulos Dinámicos**:
  - En la pantalla de registro de tambores (`agregar_pesaje.dart`), el título cambia a `"Registro de Tambores"`, ocultando las tarjetas de pesos totales.
  - En `remito_registro.dart`, la cabecera de la tabla de desglose cambia a `"📝 DETALLE DE TAMBORES REGISTRADOS"`.
  - En el PDF generado (`pdf_invoice_generator.dart`), el encabezado cambia a `"DESGLOSE DE TAMBORES REGISTRADOS:"`.
  - En `paradadetalle.dart`, la tarjeta cambia a `"REGISTRO DE TAMBORES (TCM)"`.
- **Botones Contextuales**: En `paradadetalle.dart`, la etiqueta del botón de ingreso cambia dinámicamente según el estado:
  - `"REGISTRAR TAMBORES / PESAJE"` si no hay registros cargados.
  - `"MODIFICAR TAMBORES RECOLECTADOS"` si se registraron sin pesos.
  - `"MODIFICAR PESAJE DE TAMBORES"` si se registraron con pesos.
- **Recordatorio de SENASA**: En `agregar_pesaje.dart`, si no se registran pesos, se muestra un banner llamativo en color rojo suave indicando: `¡IMPORTANTE! Recordá recolectar el código SENASA de cada tambor. No se registrarán pesos.`, asegurando que no se pase por alto esta obligación del conductor.

### F. Recolecciones Simples de No-TCM (Insumos, Cera y Otros)
- **Camino Simplificado**: Todos los productos que no sean TCM (como cera en sus distintos tipos CO/CR, tambores vacíos TRR/TRC, azúcar, etc.) se gestionan de manera "simple", prescindiendo de códigos SENASA o registro de pesos.
- **Flujo en Remitos**: El chofer los edita y confirma de forma directa ingresando su cantidad con botones de incremento/decremento (`+/-`) directamente en la pantalla de confección del remito (`remito_registro.dart`).

### G. Indicador de Remito Emitido Multi-Parada
- **Consistencia en Resumen de Viaje**: En la pantalla `viaje_detalle.dart`, el estado del remito de la parada no debe evaluarse contra el campo único y obsoleto `p['remito_id'] != null`. Para dar soporte al modelo de múltiples remitos por parada, la UI evalúa `remitos.isNotEmpty` para indicar si el remito ha sido emitido, y `remitos.isEmpty` para indicar si está pendiente.

## 8. Dashboard Premium & Eliminaciones en Cascada (CEO/Gerencia)
- **Panel Ejecutivo Premium**: En `homepage.dart`, se ocultan condicionalmente los accesos operacionales (`Gestión de Cargas`, `Control Pesajes`, `Gastos`, `Productos`) para roles directivos (`CEO`, `Gerente`, `Gerencia`), presentándoles una interfaz ejecutiva pura de KPIs.
- **Navegación Interactiva**: En `gerentehome.dart`, las tarjetas de Distribuciones y Recolecciones están enlazadas mediante animaciones de respuesta táctil (`InkWell` con chevrons) para redirigir fluidamente a `/recolecciones` y `/distribuciones`.
- **Bypass de Codificación de Caracteres**: Las estadísticas del CEO calculan Distribuciones y Recolecciones en tiempo real mediante comparaciones de subcadena parciales (`tipo.contains('recol')` y `tipo.contains('distrib')`), previniendo que discrepancias de codificación (`Recolección` vs `Recoleccin` en Supabase) congelen los contadores en `0`.
- **Cascada Inteligente de Solicitudes**: Al eliminar una solicitud desde el panel, el sistema realiza una limpieza profunda y transaccional sobre `parada_items`, `pesajes` y `remitos`. Si el viaje está en estado `Pendiente`, la solicitud es liberada al planificador volviendo de estado `Asignada` a `Pendiente`.

## 9. Equivalencia de Productos de Terreno (TCM / 1)
- **Conciliación de Códigos**: Los conductores registran los pesajes de tambores utilizando el código numérico `'1'`, mientras que el sistema administrativo procesa `'TCM'`.
- **Lógica de Mapeo**: Se implementó una lógica de equivalencia bidireccional en las pantallas y validaciones clave (`remito_registro.dart`, `paradadetalle.dart` y `viaje_detalle.dart`). Ambas claves se consideran idénticas al sumar existencias, consolidar pesos y renderizar la interfaz.

## 10. Permisos de Super-Administrador (hassel00@gmail.com)
- **Identificación**: El administrador se identifica por su email de Supabase Auth: `hassel00@gmail.com`. Se obtiene en runtime mediante `Supabase.instance.client.auth.currentUser?.email`.
- **Getter estándar**: En cada página que necesite permisos extendidos usar: `bool get _isAdmin => Supabase.instance.client.auth.currentUser?.email == 'hassel00@gmail.com';`
- **Capacidades exclusivas del Admin**:
  - Editar y eliminar viajes en **cualquier estado** (incluyendo `Terminado`), a diferencia de otros roles que solo pueden en `Pendiente`/`En Proceso`.
  - Navegar a paradas de viajes `Terminados` (otros usuarios ven las tarjetas como no-tapeables).
  - Eliminar remitos individuales de una parada. Al eliminar, el sistema restablece `parada.estado = 'En Proceso'` y `parada.remito_id = null`, dejando la parada editable para regenerar el remito. Método: `SupabaseService().deleteRemito(remitoId, paradaId)`.
  - En `ParadaDetalleWidget`, `isReadOnly = false` siempre para el admin, independientemente del estado de la parada o el viaje.

## 11. Sincronización con Google Sheets
- **Estado actual**: La sincronización con Google Sheets es **manual**, no automática. Se realiza ejecutando el script `scratch/sync_sheets_to_supabase.dart` desde la terminal cuando se cargan nuevos apicultores en el Sheet.
- **Sheet ID**: `1vcg7nmkTfp_AyTTkTOGuGu7k-B2eAAUA_V8P24wa1Es` (hoja `gid=1388406787`).
- **Mecanismo**: El script descarga el Sheet como CSV y hace `upsert` en la tabla `apicultores` de Supabase.
- **Pendiente**: Integrar un botón de sincronización manual en la UI del admin, o bien disparar la sincronización en segundo plano al iniciar sesión como `hassel00@gmail.com`.

## 12. Salvaguarda de Cargas Vacías y Doble Capa RLS (Supabase)
- **Problema de JWT Stale**: El uso de emuladores y pruebas repetidas puede persistir tokens de Supabase Auth nativos obsoletos en `flutter_secure_storage`. Esto fuerza las consultas relacionales del backend bajo el rol `authenticated`, activando filtros RLS que silencian las filas de `carga_items` y muestran "0 items / 0 kg" de forma errónea (ej. `CARGA-7845001`).
- **Limpieza Preventiva en UI**: En pantallas críticas de depósito (`depositohome.dart`), se ejecuta `await Supabase.instance.client.auth.signOut()` de manera preventiva en la inicialización (`_fetchData()`) para limpiar el hilo local de tokens persistidos obsoletos y asegurar llamadas con rol público.
- **Fallback Directo en Consultas**: Los métodos de `SupabaseService` (`getViajeDetalle`, `getTerminatedCargas`, `getCargas`, `getCargaDetalle`) incorporan una doble capa de seguridad: si la consulta relacional con joins devuelve una lista vacía de `carga_items`, se realiza una consulta directa específica a `carga_items` filtrada por `carga_id` para recuperar y re-inyectar los datos reales.

## 13. Geolocalización e Inteligencia de Direcciones en Google Maps
- **Direcciones Físicas en Waypoints**: Para evitar búsquedas fallidas y crashes en Google Maps causados por enviar nombres de apicultores como puntos de parada (ej: "No results for General Pico, La Pampa"), se reestructuró la codificación de waypoints.
- **Formato Estándar**: Las URLs de mapas se generan estrictamente bajo el formato limpio: `"$localidad, $provincia, Argentina"`.
- **Resolución Dinámica de Provincia**: Se implementó una lógica de fallback de provincias. Para cada parada, el sistema busca el nombre del apicultor en `ApicultoresData.fallbackApicultores`. Si existe coincidencia, se extrae su provincia física real; de lo contrario, se asume `'La Pampa'` por defecto.
- **Lanzamiento de Mapas Nativo**: La URL con waypoints codificados en URI se dispara utilizando `launchUrl` en modo `LaunchMode.externalApplication`, forzando la apertura de la aplicación nativa del dispositivo.

## 14. Navegación a Detalle de Viaje desde Necesidades (`/necesidades`)
- **Acceso de Auditoría y Roles**: Para permitir que roles no operacionales (CEO, Depósito, Compras) inspeccionen los recorridos y pesajes de viaje de forma fluida, se habilitó la navegación desde el listado de necesidades.
- **Mapeo de Relaciones**: Durante `_fetchData()` en `necesidades_page.dart`, se consulta la tabla `paradas` para mapear de forma reactiva `solicitud_id -> viaje_id` en el mapa de lookup `_solicitudToViaje`.
- **Interactividad Premium**: Las tarjetas de necesidades en estado `'Asignada'` o `'En Curso'` muestran un chevron colorido (`DesignTokens.primary`) e implementan un `onTap` que redirige a `/viajedetalle?viajeId=X`.
- **Control de Solo Lectura**: La vista `/viajedetalle` evalúa dinámicamente si el rol del usuario no es operativo para ocultar todos los botones de acción física, previniendo crashes y manipulaciones indebidas.

## 15. Prevención de Crashes de Tamaño Infinito en Flex Grids
- **Regla de Restricción de Ancho en Row/Column**: Los errores de desbordamiento gráfico (`RenderFlex` overflow o box constraints error) ocurren al anidar filas o columnas flexibles sin delimitar sus tamaños.
- **Solución en Tarjetas de Viaje (`viajes_page.dart`)**:
  1. Configurar siempre `mainAxisSize: MainAxisSize.min` en filas de botones de acción o elementos anidados del lado derecho.
  2. Envolver columnas o textos descriptivos del lado izquierdo en widgets `Expanded` y aplicar control de overflow mediante `overflow: TextOverflow.ellipsis` para evitar desbordamientos en pantallas estrechas.

## 16. Splash Screen Premium e Híbrida Imperceptible
- **Problema de Salto Visual**: En muchas apps, la pantalla de Splash y la pantalla de Bienvenido tienen discrepancias de coordenadas de logo y fondos de color, provocando saltos bruscos y molestos para el usuario.
- **Solución de Diseño Unificado**: En `welcomepage.dart`, implementamos ambas etapas en un único widget de estado. El fondo es gestionado por un `AnimatedContainer` que se inicia en blanco puro (`Colors.white`) para mimetizarse perfectamente con el fondo original del logo, y transiciona suavemente en 800ms hacia `theme.primaryBackground` cuando el splash termina.
- **Efecto de Respiración Continua e Interrupción**: Se utiliza un `AnimationController` que oscila la escala del logo de `1.0` a `1.06` en curva de desaceleración. Para evitar que el listener entre en un bucle infinito en su estado `dismissed` al detenerse, se agregó una bandera de verificación (`if (!_isSplashActive) return;`), deteniendo la animación limpiamente en su tamaño original (`1.0`) y dejándolo estable.
- **Transición de Desvanecimiento por Bloques**: La barra Honey Gold (`#C68E17`) e indicadoras del Splash se ocultan con `AnimatedOpacity`, y el resto de la interfaz (Títulos, Eslogan y Botón INICIAR) se despliegan en el mismo espacio con retardo de fade-in de 800ms, manteniendo el logo estático en su lugar geométrico original.
- **Inmersión del Status Bar**: Para evitar el antiestético bloque horizontal gris oscuro que por defecto pinta Android en el área superior del status bar, se configuró globalmente en `main.dart` el uso de `SystemChrome.setSystemUIOverlayStyle` con `statusBarColor: Colors.transparent` e íconos en `Brightness.dark`. Esto extiende el lienzo de dibujo y el patrón honeycomb hasta el extremo físico superior del dispositivo.

## 17. Declaración de Visibilidad del Sistema de Intents (Android 11+)
- **Problema de Bloqueo de Hardware**: Las apps modernas Android (SDK 30+) bloquean la resolución e invocación de intents externos (como la cámara o visor de fotos) a menos que se declaren explícitamente en el manifest.
- **Solución en Manifest**: Se agregó la acción del intent `android.media.action.IMAGE_CAPTURE` dentro de la sección `<queries>` de `AndroidManifest.xml` para garantizar la compatibilidad universal del plugin de selección de fotos en el formulario de gastos.

## 18. Auto-Sanación de Rutas y Doble WhatsApp Fallback
- **Auto-Sanación Reactiva**: Al consultar `getViajeDetalle` en `supabase_service.dart`, el backend compara si existen paradas en estado `'Pendiente'` que cuenten con remitos en base de datos. Si las detecta, actualiza el estado de las paradas a `'Terminado'` y recalcula el inventario del camión sobre la marcha para asegurar la visualización y habilitación del botón verde **"FINALIZAR VIAJE"**.
- **Lookup y Actualización de Apicultores**: Si el apicultor no cuenta con un número celular registrado, el sistema busca coincidencias en `ApicultoresData.fallbackApicultores`. Si el usuario ingresa o corrige su teléfono en la firma digital, este se actualiza inmediatamente en Supabase (tabla `apicultores`) para futuras referencias.
- **WhatsApp Dual-Scheme**: El sistema intenta lanzar primero el intent nativo `whatsapp://send?phone=...`. Si falla (ej. emulador), atrapa la excepción y lanza la versión web `web.whatsapp.com` en el navegador del dispositivo de forma transparente.

## 19. Optimización de Cargas y Control Proyectado de Capacidad (Cargas/Tránsito)
- **Control de Stock en Tránsito en Ruta**: Mapea en caliente la cantidad de insumos actualmente en tránsito en el camión. Se calcula sumando la carga inicial asignada y las recolecciones finalizadas en ruta, restando las entregas realizadas. Si el chofer intenta registrar una entrega que exceda el stock disponible del camión, el sistema lo bloquea en `agregaritem.dart` con una SnackBar descriptiva.
- **Validación Proyectada de Capacidad del Vehículo (Peso Camión)**: Evalúa dinámicamente el peso proyectado del camión sumando y restando los pesos dinámicos de los productos del catálogo de base de datos (`peso_unit_kg` en la tabla `productos`). Esta validación bloquea de manera predictiva cualquier carga inicial en depósito (`depositohome.dart`) o adición de ítems en ruta (`agregaritem.dart`) si el peso proyectado supera la capacidad máxima declarada del vehículo (`capacidad_kg`).
- **Pre-población de Cargas en Depósito basada en Planificación**: En el diálogo de asignación de carga de depósito (`_showAddCargaDialog`), al seleccionar un viaje, el sistema realiza una consulta en segundo plano de las paradas de tipo "Distribución", consolida la demanda planificada y pre-pobla el formulario automáticamente como chips visuales interactivos y un interruptor de autocompletado habilitado por defecto.
- **Acceso Ejecutivo Sincronizado**: Los roles de Compras, CEO y Gerente (`_isManagement`) disponen de visualización y navegación cruzada al panel de cargas de depósito. Se habilitaron las estadísticas dinámicas en el panel de inicio, la tarjeta de módulo en el grid principal y el acceso directo del drawer lateral hacia `/depositoHome`.

## 20. Reglas de Negocio y Lógica Crítica de Cargas y Paradas (1 de Junio de 2026)
### A. Control de Paradas y Cierre Manual por el Chofer (Eliminación de Auto-Cierre)
- **Cierre por Chofer**: Las paradas de tipo "Distribución" ya no se cierran de forma automática al guardar un remito en Supabase. El chofer es el único actor facultado para decidir cuándo dar por terminada la parada, mediante el botón "FINALIZAR PARADA".
- **Remito Múltiple**: Se permite expresamente la creación de múltiples remitos antes de consolidar el cierre de la parada. 
- **Consolidación de Datos**: Al presionar "FINALIZAR PARADA", el sistema actualiza el estado de la parada a `'Terminada'` en todos los niveles (Supabase, local y visual) y consolida el remito correspondiente. Una vez cerrada la parada, el registro se vuelve de solo lectura (con la única excepción del Super-Administrador).

### B. Gestión de Auditoría y Creación de Cargas
- **Atribución de Creador (`creado_por`)**: Es un requerimiento crítico conocer qué usuario específico cargó cada carga. Al crear una carga se guarda el perfil (ej. CEO, COMPRAS, GERENCIA, DEPOSITO) del usuario creador y se muestra visiblemente en el detalle de la misma.
- **Validación de Carga Vacía**: El sistema prohíbe de forma absoluta la creación de una carga que no tenga asignado al menos un producto y una cantidad mayor a cero.

### C. Restricción de Roles en la Creación de Cargas
- **Choferes Bloqueados**: Bajo ningún concepto los choferes pueden crear o registrar nuevas cargas en depósito. El botón de creación y la navegación al formulario están bloqueados para el rol de Chofer, quedando disponibles únicamente para los roles de Compras, Gerencia, Depósito y CEO.

### D. Reglas de Depósitos: Huinca vs Parque Industrial (PI)
- **Depósito Huinca**: Los choferes pueden cambiar de estado las cargas planificadas en el depósito Huinca, ya que ellos mismos realizarán esta operatoria en terreno. En el depósito Huinca, las cargas se asocian de forma nativa a un viaje que ya se encuentra "En Curso".
- **Depósito Parque Industrial (PI)**: En el depósito PI, está estrictamente prohibido asignar cargas a un viaje que ya está en curso. Todas las cargas de PI deben estar en estado `'Terminada'` para que el camión pueda dar inicio al viaje. El sistema valida esto y bloquea el botón "INICIAR VIAJE" (mostrando advertencia) si hay alguna carga PI pendiente.

### E. Optimización del Módulo de Gastos (`gastos_page.dart`)
- **Filtro de Viajes por Chofer**: Los choferes que ingresen al módulo de gastos únicamente podrán ver y seleccionar sus propios viajes asignados. Los roles administrativos conservan la vista global de todos los viajes del sistema.
- **Pre-selección de Viaje en Curso**: Al abrir el diálogo de registro de gastos, el sistema identifica y pre-selecciona automáticamente el viaje que actualmente se encuentra `'En Curso'` para ahorrar tiempo y fricción al conductor.
- **Conversión de Separadores Decimales**: Se implementó una normalización que convierte automáticamente cualquier coma decimal `,` ingresada en los campos de importe y litros a punto `.` antes del parseo, previniendo crashes por formatos locales de teclado.

### F. Eliminación de Redundancias de Navegación para Choferes
- **Panel Dedicado 'Mis Viajes'**: Los choferes ya cuentan con su panel operativo exclusivo ('Mis Viajes') desde donde gestionan cargas en tránsito, paradas, remitos y gastos de forma guiada y contextual.
- **Limpieza de la Pantalla Principal (Home)**: Para simplificar el flujo y eliminar redundancias, se inhabilitó la visualización en `homepage.dart` (tanto en la cuadrícula de módulos como en el menú lateral drawer) de las siguientes opciones para el rol de Chofer:
  - *Depósito Huinca*
  - *Productos*
  - *Control de Ruta*
  - *Gastos*
  - *Control Pesajes*

### G. Inclusión de Depósito en Remitos y Redirección de Choferes (1 de Junio de 2026)
- **Navegación Unificada**: Al presionar 'CARGAS' en el panel del chofer (`choferhome.dart`), el sistema lo redirige directamente a `/depositoHome` (`depositohome.dart`) en lugar de `cargas_page.dart` para asegurar que el chofer acceda al visor de depósito completo y disponga del botón Honey Gold **REMITO** para abrir el PDF.
- **Saneamiento de Cargas Vacías (`viaje_sin_carga`)**: Se eliminaron por completo las tarjetas ficticias de 'SIN CARGA' en la pestaña PENDIENTES. Solo cargas físicas y reales guardadas en Supabase se muestran en el listado de cada pestaña.
- **Selector de Depósito en Cargas**: El diálogo de creación de carga (`_showAddCargaDialog`) ahora incluye un menú selector obligatorio para elegir el depósito de origen (`deposito_origen`) que se persiste en Supabase:
  - Si el usuario es un **Chofer**, el dropdown se muestra inhabilitado y pre-seleccionado en `'Depósito Huinca'`. El chofer conserva el permiso de agregar cargas a un viaje activo únicamente bajo este depósito.
  - Si el usuario es **Depósito, CEO, Compras o Gerente**, el selector está totalmente desbloqueado y pueden elegir entre `'Parque Industrial'` y `'Depósito Huinca'`.
- **Origen en PDF de Remitos**: Las plantillas profesionales de remitos (tanto remitos de cliente/distribución en `remito_page.dart` como remitos de pesaje/báscula en `remito_registro.dart`) recuperan el `deposito_origen` de forma asíncrona de las cargas asociadas al viaje y lo renderizan visiblemente en la sección de metadatos bajo el campo **'Depósito de Carga'**.

## 21. Unificación de Remitos, Persistencia de Pesajes y Simplificación en Home (2 de Junio de 2026)
### A. Unificación Estética del Remito de Pesajes
- **Pie de Remito Estandarizado**: El remito de pesajes y conformidad (`generateWeighingRemitoPDF` en `pdf_invoice_generator.dart`) debe utilizar la insignia verde `"FIRMA DIGITAL VERIFICADA"` con borde en color `secondaryColor` (#1A6B43) y leyenda `"Fecha de firma"`, unificando su diseño con el de cargas para estandarizar la formalidad del firmado digital.
- **Caja de Totales Coherente**: La caja de totales de pesajes debe utilizar el diseño minimalista de cargas: color de fondo `backgroundColor` (#F8FAFC), borde sutil `borderColor` (#E2E8F0) de ancho 1.0, y mostrar el peso neto destacado en Success Green (`secondaryColor`).
- **Preservación de Cabecera**: Se mantiene la proporción y elementos de cabecera que incluyen el logo de Geomiel con dirección/teléfono a la izquierda y el logo de GeoLogística a la derecha.

### B. Persistencia de Datos e Historial de Pesajes
- **Eliminación de Limpieza de Pesajes**: Se prohíbe el borrado automático de los pesajes en Supabase al momento de firmar y emitir el remito. Los pesajes asociados a la parada deben conservarse en la base de datos para que la tarjeta interactiva de pesajes en `viaje_detalle.dart` y el listado de `pesajes_page.dart` puedan cargar y desglosar el historial completo de tambores.
- **Eliminación de la palabra "Balanza/Báscula" en la UI**: Las alertas de discrepancia en la UI deben usar la frase `"según pesajes registrados"` en lugar de `"según pesaje de balanza"` para acatar la regla de no mencionar balanzas o básculas físicas.

### C. Limpieza de Interfaz en Home
- **Ocultamiento de Estado de Cargas**: Se elimina por completo la sección de estadísticas `"ESTADO DE CARGAS"` en `homepage.dart` para simplificar la vista y evitar redundancias operativas con los paneles dedicados de depósito y choferes.

## 22. Filtrado de Pesajes por Apicultor, Remitos Simplificados y Resolución de ID Dinámico (3 de Junio de 2026)
### A. Filtrado Dinámico de Pesajes por Apicultor Activo
- **Filtrado en Tiempo Real**: En la pantalla de pesaje (`agregar_pesaje.dart`), la tabla inferior de tambores registrados y la tarjeta de sumatoria de pesos bruto, tara y neto computan valores únicamente para el apicultor seleccionado en el dropdown (`_selectedApicultorId`).
- **Control y Persistencia Parcial**: El botón de guardado se actualiza dinámicamente con el recuento del apicultor seleccionado (ej. `GUARDAR PESAJE (X TCM)`) y solo se muestra si existen tambores para dicho apicultor. La persistencia en Supabase (inserciones y eliminaciones) solo afecta a la sesión del apicultor activo en pantalla.

### B. Resolución de apicultor_id y Asociación Dinámica en Paradas
- **Ausencia de apicultor_id en Paradas**: La tabla `paradas` no cuenta con la columna `apicultor_id`. El ID del apicultor titular debe resolverse dinámicamente en el initState de la pantalla de remito (`remito_registro.dart`) consultando la tabla `solicitudes` a través del campo `solicitud_id`.
- **Asociación de Pesajes sin ID**: Si los pesajes en la base de datos se registraron con `apicultor_id = null`, el filtro en el remito debe asociarlos automáticamente al ID resuelto del apicultor principal/titular de la parada (`_titularIdOfParada`). Esto evita planillas de pesajes vacías para el apicultor principal de la parada.
- **Evitar Colisión de Claves en Remitos**: Al insertar remitos, se realiza una consulta de conteo para agregar un sufijo secuencial (ej. `-2`, `-3`) en el campo `numero_remito` para evitar fallos de RLS o conflictos de clave única en Supabase.
- **Inserción de Campos Remitos**: Dado que `apicultor_id` no existe en la tabla `remitos`, el CUIT/DNI del apicultor debe mapearse al campo `cliente_cuit`, y el neto de kilos a `total_kg`.

### C. Tabla de Pesajes Simplificada para Lotes Sin Pesar
- **UI Adaptativa en Pantalla**: En `remito_registro.dart`, si el primer tambor tiene `peso_bruto == 0.0`, el lote se declara como "sin pesar". La tabla técnica cambia dinámicamente a un formato simplificado de 3 columnas (`N°`, `Código SENASA`, `Detalle: Sin pesar`), ocultando las columnas y totalizadores vacíos de peso.
- **Adaptación Premium en PDF**: En `pdf_invoice_generator.dart` (`generateWeighingRemitoPDF`), la tabla de pesajes se dibuja similarmente con 3 columnas (`N° Tambor`, `Código SENASA de Origen`, `Detalle`) con anchos adaptados, y se reemplaza el cuadro consolidador de pesos por la etiqueta sutil `Cantidad Total: X Tambores (TCM)`.

### D. Reconciliación de Kilos en la Finalización del Viaje
- **Cálculo Real**: En `supabase_service.dart`, el método `finalizarParada` calcula el total de kilos netos acumulando los pesajes reales de Supabase. Si un tambor no tiene peso registrado (peso bruto 0), aplica un peso estándar estimado de **`300.0 kg`** de forma predictiva. Sincroniza la cantidad del producto `TCM` en `parada_items` con la cantidad real de tambores.

## 23. Rediseño Responsivo Estricto - Sistema STITCH (23 de Junio de 2026)
### A. Layouts Adaptativos con LayoutBuilder
- **Breakpoints**: Se fija el breakpoint de escritorio en `1024px`. Toda pantalla adaptativa (`homepage.dart`, `agregar_pesaje.dart`, `pesajesitem.dart`, `remito_registro.dart`) debe usar `LayoutBuilder` para discriminar el comportamiento:
  - En pantallas anchas (>= 1024px), se aplica un panel lateral (`Sidebar`) fijo a la izquierda con fondo `DesignTokens.primary` (#08201A), logotipo corporativo y perfil de usuario cargado desde `SharedPreferences`. El contenido principal se centra horizontalmente con un `ConstrainedBox` limitado a un `maxWidth` estricto de `1200px`.
  - En pantallas móviles (< 1024px), el Sidebar se oculta y se colapsa dentro de un `Drawer` estándar para los choferes, y el `AppBar` se muestra con un botón de retroceso o menú.
- **Doble Columna en Escritorio**:
  - En `agregar_pesaje.dart`, el formulario de carga se ubica a la izquierda y la tabla de tambores y totales a la derecha.
  - En `pesajesitem.dart`, el formulario de pesaje se ubica a la izquierda y la tarjeta de capacidad/acciones a la derecha.
  - En `remito_registro.dart`, los campos del remito y tablas se ubican a la izquierda y las firmas y footer legal a la derecha.

### B. Lienzo de Firma No Responsivo
- **Prevención de Deformación**: Para evitar que la firma del receptor se estire o deforma al cambiar el tamaño de la ventana en computadoras, el lienzo `Signature` en `remito_registro.dart` debe mantener dimensiones físicas fijas y estrictas de **`360x130`** píxeles, centrado mediante un widget `Center` e inalterable en su contenedor.

### C. Foco de Teclado con Honey Gold
- **UX de Entrada de Datos**: Los campos de texto del formulario de pesajes deben usar un color de borde enfocado (`focusedBorder`) igual a `DesignTokens.secondary` (Honey Gold `#C68E17`) con grosor de `1.5` para dar visibilidad clara de la selección del teclado en computadoras.

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


  ## 26. Consolidaci�n del Dise�o Premium y Bento Box (18 de Julio de 2026)
  ### A. Estructuras Modales Responsivas
  - **Componentizaci�n**: Se proh�be el uso de layouts verticales ("en duro") para modales complejos como el Detalle de Gasto. Todo modal debe abstraerse a su propio widget independiente (gastos_detalle.dart).
  - **Responsiveness**: Los modales complejos deben usar LayoutBuilder para colapsar de horizontal a vertical en m�viles sin usar Wrap con anchos fijos para evitar overflows.
  ### B. Feedback de Carga Estructural (Skeletons)
  - **Skeleton Loaders**: Toda pantalla que requiera consultas a red debe renderizar un esqueleto estructural respetando el GeoSidebar.
# #   2 3 / 0 7 / 2 0 2 6 :   U I / U X   A p i c u l t o r e s  
 -   S e   c o n s o l i d o   e l   p a t r o n   d e   t a r j e t a s   v a c i a s   c l i c k e a b l e s   ( I n k W e l l   +   M a t e r i a l )   p a r a   r e d i r e c c i o n   p r o a c t i v a   e n   a p i c u l t o r _ d e t a l l e . d a r t .  
 