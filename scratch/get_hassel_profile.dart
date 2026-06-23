import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Perfil de hassel00@gmail.com ---');
  try {
    final sample = await client.from('profiles').select().eq('email', 'hassel00@gmail.com');
    print('Perfil: $sample');
  } catch (err) {
    print('Error: $err');
  }
}
