import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Tipos de ID ---');
  
  try {
    final sol = await client.from('solicitudes').select('id').limit(1);
    if (sol.isNotEmpty) {
      print('ID de solicitudes: ${sol.first['id'].runtimeType} (${sol.first['id']})');
    }
    
    final via = await client.from('viajes').select('id').limit(1);
    if (via.isNotEmpty) {
      print('ID de viajes: ${via.first['id'].runtimeType} (${via.first['id']})');
    }
  } catch (e) {
    print('Error: $e');
  }
}
