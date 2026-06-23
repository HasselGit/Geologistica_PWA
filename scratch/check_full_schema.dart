import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Esquema Completo (Viajes, Rutas, Paradas) ---');
  
  final checks = {
    'viajes': ['id', 'viaje_codigo', 'fecha_planificada', 'fecha_inicio', 'fecha_terminado', 'estado'],
    'rutas': ['id', 'viaje_id', 'ruta_codigo', 'estado', 'fecha_planificada', 'fecha_inicio', 'fecha_terminado'],
    'paradas': ['id', 'viaje_id', 'ruta_id', 'ubicacion', 'tipo', 'estado', 'orden_secuencia', 'localidad', 'solicitud_id'],
    'parada_items': ['id', 'parada_id', 'producto_codigo', 'cantidad', 'unidad'],
    'solicitudes': ['id', 'solicitud_codigo', 'apicultor_id', 'producto', 'cantidad', 'estado'],
  };

  for (var table in checks.entries) {
    print('\nTabla: ${table.key}');
    for (var col in table.value) {
      try {
        await client.from(table.key).select(col).limit(1);
        print('  [OK] "$col"');
      } catch (e) {
        print('  [FAIL] "$col": $e');
      }
    }
  }
}
