import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('Testing separate query for parada_items');
    final data = await client.from('parada_items').select().limit(5);
    print('Encontrados: ${data.length} items');
  } catch (e) {
    print('Error: $e');
  }
}
