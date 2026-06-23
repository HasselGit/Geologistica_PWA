import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Tablas ---');
  try {
    // We can run a query on a generic table or use a postgrest request to get information
    final schema = await client.from('cargas').select().limit(1);
    print('cargas exist: yes, schema keys: ${schema.isNotEmpty ? schema[0].keys : "empty"}');
    
    final items = await client.from('carga_items').select().limit(1);
    print('carga_items exist: yes, schema keys: ${items.isNotEmpty ? items[0].keys : "empty"}');
  } catch (e) {
    print('Error: $e');
  }

  try {
    final itemsCarga = await client.from('items_carga').select().limit(1);
    print('items_carga exist: yes, keys: ${itemsCarga.isNotEmpty ? itemsCarga[0].keys : "empty"}');
  } catch (e) {
    print('items_carga does not exist or failed: $e');
  }
}
