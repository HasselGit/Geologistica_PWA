import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Buscando Perfil por ID ---');
    final response = await client.from('profiles').select().eq('id', '7d18b2be-f2b0-4708-a80a-2236f7a77332').limit(1);
    if (response.isNotEmpty) {
      print('Profile found: ${response.first}');
    } else {
      print('No profile found with ID 7d18b2be-f2b0-4708-a80a-2236f7a77332');
    }

  } catch (e) {
    print('Error: $e');
  }
}
