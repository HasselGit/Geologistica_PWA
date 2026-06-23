import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    final list = await client.from('remitos').select('*').limit(1);
    if (list.isNotEmpty) {
      final keys = list[0].keys.toList();
      print('KEYS_START');
      for (final k in keys) {
        print('KEY: $k');
      }
      print('KEYS_END');
    } else {
      print('No remitos records found in DB.');
    }
  } catch (e) {
    print('Error: $e');
  }
}
