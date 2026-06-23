# 🗄 Esquema de Base de Datos (Supabase)

Resumen de las tablas y relaciones principales utilizadas en GeoLogística.

## 📋 Tablas Principales

### 1. `profiles`
- `id`: uuid (PK, vinculada a auth.users)
- `nombre`: text
- `apellido`: text
- `email`: text
- `puesto`: text (CEO, Gerente, Chofer, Encargado de Deposito, Compras)

### 2. `viajes`
- `id`: uuid (PK)
- `viaje_codigo`: text (V-DDMM-XXXX)
- `vehiculo_codigo`: text (FK a vehiculos)
- `chofer_id`: uuid (FK a profiles)
- `estado`: text (Planificado, En Proceso, Terminado)
- `fecha`: timestamp
- `fecha_inicio`: timestamp
- `fecha_terminado`: timestamp
- `descripcion`: text

### 3. `rutas`
- `id`: uuid (PK)
- `viaje_id`: uuid (FK a viajes)
- `ruta_codigo`: text
- `estado`: text
- `fecha_planificada`: timestamp

### 4. `paradas`
- `id`: uuid (PK)
- `viaje_id`: uuid (FK a viajes)
- `ruta_id`: uuid (FK a rutas)
- `solicitud_id`: uuid (FK a solicitudes)
- `orden_secuencia`: int
- `tipo`: text (Recoleccion, Distribucion)
- `ubicacion`: text
- `localidad`: text
- `estado`: text
- `remito_id`: text (FK a remitos)
- `bruto_kg`: numeric
- `tara_kg`: numeric
- `neto_kg`: numeric

### 5. `parada_items`
- `id`: uuid (PK)
- `parada_id`: uuid (FK a paradas)
- `producto_codigo`: text
- `cantidad`: numeric
- `unidad`: text (KG, UN)

### 6. `solicitudes`
- `id`: uuid (PK)
- `apicultor_id`: uuid (FK a apicultores)
- `producto`: text
- `cantidad`: numeric
- `tipo`: text
- `estado`: text (Pendiente, En Curso, Finalizado)
- `localidad`: text

### 7. `productos`
- `id`: uuid (PK)
- `codigo`: text (Unique)
- `descripcion`: text
- `unidad`: text

### 8. `pesajes`
- `id`: uuid (PK)
- `parada_id`: uuid (FK a paradas)
- `viaje_id`: uuid (FK a viajes, opcional)
- `apicultor_id`: uuid (FK a apicultores, opcional)
- `senasa_codigo`: text
- `peso_bruto`: numeric
- `tara`: numeric
- `peso_neto`: numeric (calculado o almacenado)
- `fecha_registro`: timestamp

### 9. `remitos`
- `id`: uuid (PK)
- `parada_id`: uuid (FK a paradas)
- `chofer_id`: uuid (FK a profiles)
- `apicultor_id`: uuid (FK a apicultores, representa al **Apicultor Titular/Tercero**)
- `viaje_id`: uuid (FK a viajes)
- `remito_codigo`: text (Código formateado ej: REM-XXXX)
- `firma_url`: text (URL pública de la firma digital)
- `pdf_url`: text (URL pública del archivo PDF del remito)
- `estado`: text (Emitido, Anulado)
- `fecha`: timestamp
- `persona_nombre`: text (Nombre del Responsable Firmante físico)
- `persona_dni`: text (DNI del Responsable Firmante físico)

## 🔗 Relaciones Clave
- **Viaje -> Paradas**: Un viaje tiene múltiples paradas a través de rutas o directamente.
- **Parada -> Solicitud**: Una parada representa la ejecución de una solicitud de carga/recolección.
- **Perfil -> Viaje**: Los choferes están asignados a viajes mediante `chofer_id`.
- **Parada -> Pesajes**: Una parada de recolección de miel asocia múltiples pesajes de tambores a través de `parada_id`.
- **Remito -> Apicultor**: El remito se asocia directamente a la ficha del apicultor titular (`apicultor_id`) y almacena el firmante físico (`persona_nombre`).
