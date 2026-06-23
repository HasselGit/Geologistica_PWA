import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Carga Items en DB ---');
  try {
    final list = await client.from('carga_items').select('*');
    print('Cantidad de items de carga en DB: ${list.length}');
    for (var it in list) {
      print('Item: ID=${it['id']}, CargaID=${it['carga_id']}, Prod=${it['producto_codigo']}, Cant=${it['cantidad']}, Unidad=${it['unidad']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
