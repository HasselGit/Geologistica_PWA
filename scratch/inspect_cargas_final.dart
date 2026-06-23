import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('=== INSPECTING CARGAS AND CARGA_ITEMS ===');
  try {
    final loads = await client.from('cargas').select('*, carga_items(*)');
    print('Found ${loads.length} loads:');
    for (var load in loads) {
      print('Load Code: ${load['carga_codigo']}');
      print('Load ID: ${load['id']}');
      print('Estado: ${load['estado']}');
      print('Viaje ID: ${load['viaje_id']}');
      print('Carga Items: ${load['carga_items']}');
      print('-----------------------------------------');
    }
  } catch (e) {
    print('Error: $e');
  }
}
