import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Distinct Estados in Viajes ---');
    final response = await client.from('viajes').select('estado');
    final estados = response.map((r) => r['estado']).toSet();
    print('Estados: $estados');

  } catch (e) {
    print('Error: $e');
  }
}
