# 🎯 Índice de Archivos Críticos

Estos archivos contienen la lógica más importante y deben ser los primeros en ser analizados por una nueva IA o desarrollador.

## 🔑 Lógica Central
1.  [`lib/backend/supabase_service.dart`](../lib/backend/supabase_service.dart): Toda la lógica de persistencia, sincronización, roles de acceso y catálogo unificado.
2.  [`lib/backend/design_tokens.dart`](../lib/backend/design_tokens.dart): Definición visual de la paleta premium de colores, tipografías y sombras.
3.  [`lib/main.dart`](../lib/main.dart): Configuración de enrutamiento y arranque de servicios.

## 📱 Páginas y Operaciones en Campo (Logística)
1.  [`lib/pages/homepage.dart`](../lib/pages/homepage.dart): Dashboard principal con accesos rápidos y panel de gestión de Cargas.
2.  [`lib/pages/choferhome.dart`](../lib/pages/choferhome.dart): Operación del transportista y visualización de viajes en curso.
3.  [`lib/pages/viaje_detalle.dart`](../lib/pages/viaje_detalle.dart): Control granular del viaje y listado secuencial de paradas asignadas.
4.  [`lib/pages/paradadetalle.dart`](../lib/pages/paradadetalle.dart): Centro operativo de la parada (Recolección/Entrega), visualización de tambores preexistentes y gatillo de limpieza local de controladores de texto.
5.  [`lib/pages/agregar_pesaje.dart`](../lib/pages/agregar_pesaje.dart): Registro y cálculo neto en tiempo real de tambores (Bruto, Tara, Neto) y rastreo físico de eliminaciones en base de datos.
6.  [`lib/pages/remito_registro.dart`](../lib/pages/remito_registro.dart): Selección interactiva de **Apicultor Titular (Terceros)**, firma manuscrita, generación y renderizado nativo de PDF, sincronización y limpieza activa transaccional.
7.  [`lib/pages/login.dart`](../lib/pages/login.dart): Autenticación robusta y redirección segura según puestos y roles de usuario.

## 🛠 Configuración de Entorno
1.  [`pubspec.yaml`](../pubspec.yaml): Dependencias globales del sistema apícola.
2.  [`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml): Habilitación de callbacks de gestos de retroceso, desactivación de Impeller y declaración de visibilidad de intents de cámara para compatibilidad gráfica e ImagePicker.
3.  [`lib/backend/honeycomb_painter.dart`](../lib/backend/honeycomb_painter.dart): Motor de renderizado estático de fondos premium del panal de abejas.
4.  [`lib/pages/welcomepage.dart`](../lib/pages/welcomepage.dart): Pantalla de presentación híbrida y bienvenida con transiciones suaves, animación de respiración del logo y barra de progreso Honey Gold.

## 📄 Plantillas y Presentación Ejecutiva
1.  [`lib/backend/pdf_invoice_generator.dart`](../lib/backend/pdf_invoice_generator.dart): Generador de facturas y remitos premium en formato PDF enlazado directamente a los colores corporativos oficiales y libre de terminologías de báscula.
2.  [`lib/pages/remito_page.dart`](../lib/pages/remito_page.dart): Visualizador y compartidor digital de remitos con lookup inteligente de teléfono y esquema dual de envío WhatsApp nativo/web.

