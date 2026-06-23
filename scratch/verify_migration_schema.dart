import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Estructura Post-Migración ---');
    
    final checks = {
      'viajes': ['fecha_planificada', 'fecha_inicio', 'fecha_terminado'],
      'rutas': ['id', 'viaje_id', 'estado', 'fecha_planificada', 'created_by'],
      'paradas': ['ruta_id', 'llegada_at', 'salida_at'],
    };
    
    for (var entry in checks.entries) {
      try {
        final response = await client.from(entry.key).select().limit(1);
        if (response.isNotEmpty) {
          print('\nTable: ${entry.key}');
          print('Columns: ${response.first.keys.toList()}');
          
          for (var col in entry.value) {
            if (response.first.containsKey(col)) {
              print('  [OK] Column $col exists.');
            } else {
              print('  [MISSING] Column $col NOT FOUND.');
            }
          }
        } else {
          print('\nTable: ${entry.key} is empty, cannot verify columns via select.');
          // Try to fetch specific columns to verify existence even if empty
          try {
            await client.from(entry.key).select(entry.value.join(',')).limit(1);
            print('  [OK] Columns verified via explicit select.');
          } catch (e) {
            print('  [ERROR] Verification failed: $e');
          }
        }
      } catch (e) {
        print('\nTable: ${entry.key} - Error: $e');
      }
    }

  } catch (e) {
    print('Error: $e');
  }
}
