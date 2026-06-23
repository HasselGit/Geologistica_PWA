import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    final list = await client.from('remitos').select('*').limit(1);
    if (list.isNotEmpty) {
      print('First row in remitos: ${list.first}');
    } else {
      print('Remitos table is empty');
      // Let's inspect the REST description of tables
      // Final fallback: try fetching schema via RPC if any
    }
  } catch (e) {
    print('Error: $e');
  }
}
