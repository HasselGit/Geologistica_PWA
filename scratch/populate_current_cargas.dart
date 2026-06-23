import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('=== POPULATING MISSING ITEMS FOR CARGA-7845001 ===');
  try {
    const cargaId = '1e4ae06c-b37b-4749-860a-5dbe08c6eac0';
    
    // Check if items already exist
    final existing = await client.from('carga_items').select('*').eq('carga_id', cargaId);
    print('Current items count: ${existing.length}');

    if (existing.isEmpty) {
      print('Inserting item: TRR, 25, KG...');
      await client.from('carga_items').insert({
        'carga_id': cargaId,
        'producto_codigo': 'TRR',
        'cantidad': 25,
        'unidad': 'KG',
      });
      print('Item inserted successfully!');
    } else {
      print('Items already populated.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
