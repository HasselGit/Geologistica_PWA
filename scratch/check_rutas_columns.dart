import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Investigando Columnas de "rutas" ---');
  try {
    // Intentar ver columnas mediante select explícito de las que creemos que existen
    final knownCols = ['id', 'viaje_id', 'ruta_codigo', 'estado', 'fecha_planificada', 'fecha_inicio', 'fecha_terminado', 'created_at'];
    for (var col in knownCols) {
      try {
        await client.from('rutas').select(col).limit(1);
        print('  [OK] Columna "$col" existe.');
      } catch (e) {
        print('  [MISSING/ERROR] Columna "$col" falló: $e');
      }
    }
  } catch (e) {
    print('Error general: $e');
  }
}
