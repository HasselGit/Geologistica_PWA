import 'package:supabase/supabase.dart';

void main() async {
  print('--- TESTING WITH BACKUP KEY ---');
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('Checking profiles...');
    final data = await client.from('profiles').select().limit(5);
    print('Profiles: $data');
  } catch (e) {
    print('Error with backup key: $e');
  }
}
