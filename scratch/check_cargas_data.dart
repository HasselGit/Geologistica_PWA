import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Cargas en DB ---');
  try {
    final list = await client.from('cargas').select('*, carga_items(*)');
    print('Cantidad de cargas: ${list.length}');
    for (var c in list) {
      print('Carga: ID=${c['id']}, Codigo=${c['carga_codigo']}, ViajeID=${c['viaje_id']}, Estado=${c['estado']}, Items=${c['carga_items']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
