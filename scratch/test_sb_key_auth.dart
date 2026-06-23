import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('Testing with SB_PUBLISHABLE key...');
    final response = await client.auth.signInWithPassword(email: 'mperez@geomiel.com', password: 'mperez');
    print('SUCCESS! User: ${response.user?.id}');
  } catch (e) {
    print('FAILED: $e');
  }
}
