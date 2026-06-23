import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Listando Tablas y Columnas ---');
    
    final tables = ['viajes', 'rutas', 'paradas', 'solicitudes'];
    
    for (var table in tables) {
      try {
        final response = await client.from(table).select().limit(1);
        if (response.isNotEmpty) {
          print('\nTable: $table');
          print('Columns: ${response.first.keys.toList()}');
        } else {
          print('\nTable: $table exists but is empty or no columns found via select.');
        }
      } catch (e) {
        print('\nTable: $table - Error or not found: $e');
      }
    }

  } catch (e) {
    print('Error: $e');
  }
}
