import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  final tables = ['remitos', 'paradas', 'pesajes'];
  for (var t in tables) {
    print('\n--- Dump $t ---');
    try {
      final res = await client.from(t).select('*').limit(1).maybeSingle();
      if (res != null) {
        print(res.keys.toList());
      } else {
        print('No data in $t');
      }
    } catch (e) {
      print('Error dumping $t: $e');
    }
  }
}
