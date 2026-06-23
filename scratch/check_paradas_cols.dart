import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Filas de carga_items ---');
  try {
    final rows = await client.from('carga_items').select().limit(5);
    print(rows);
  } catch (e) {
    print('Failed: $e');
  }

  print('\n--- Filas de productos ---');
  try {
    final rows = await client.from('productos').select().limit(5);
    print(rows);
  } catch (e) {
    print('Failed: $e');
  }
}
