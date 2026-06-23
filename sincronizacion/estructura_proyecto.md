# 📂 Estructura del Proyecto: GeoLogística

Este documento describe la organización de carpetas y archivos del proyecto para facilitar la sincronización con otros sistemas de IA o desarrolladores.

## 🏗 Arquitectura de Carpetas
- `lib/`: Directorio raíz del código Dart.
  - `backend/`: Lógica de datos, servicios de Supabase y estados globales.
    - `supabase/`: Configuraciones específicas de Supabase.
    - `supabase_service.dart`: **Corazón del sistema**. Maneja todas las consultas y lógica de negocio.
    - `design_tokens.dart`: Sistema de diseño visual premium (colores, fuentes, estilos de botones).
    - `app_states.dart`: Manejo de estados de la aplicación.
  - `components/`: Widgets reutilizables en múltiples páginas.
  - `pages/`: Vistas completas de la aplicación (Screens).
    - `homepage.dart`: Dashboard principal para roles administrativos con accesos rápidos y cargas.
    - `choferhome.dart`: Vista optimizada para conductores y viajes asignados.
    - `viaje_detalle.dart`: Control del viaje y listado de paradas.
    - `paradadetalle.dart`: Centro operativo de la parada (Recolección/Entrega), tambores y cantidades.
    - `agregar_pesaje.dart`: Formulario interactivo de pesaje y cálculo neto en tiempo real.
    - `remito_registro.dart`: Emisión de remito con firma manuscrita, selector de Apicultor Titular y generación de PDF.
    - `login.dart`: Interfaz de acceso y enrutamiento según rol.
    - `welcomepage.dart`: Pantalla de inicio con branding y carga inicial.
  - `main.dart`: Punto de entrada e inicialización de servicios.
  - `index.dart`: Índice de exportaciones globales.

## 💾 Tecnologías Principales
1.  **Frontend**: Flutter (3.22+) - UI Premium con sistema de diseño personalizado.
2.  **Backend**: Supabase (PostgreSQL + Auth + Storage).
3.  **Navegación**: GoRouter (Manejo de rutas declarativas).
4.  **Localización**: Soporte completo para `es_AR` (Argentina).

## 📄 Archivos de Configuración Críticos
1.  `pubspec.yaml`: Dependencias y recursos (imágenes, fuentes).
2.  `android/gradle.properties`: Configuración de memoria y ruta del JDK.
3.  `android/app/build.gradle`: Versiones de compilación (SDK 34+, Java 17).
4.  `sesion_actual.md`: Diario de cambios y estado actual de desarrollo.
