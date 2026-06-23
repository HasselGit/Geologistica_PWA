import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Estructura de muestra: cargas ---');
  try {
    final sample = await client.from('cargas').select().limit(1);
    print('Carga: $sample');
  } catch (err) {
    print('Error: $err');
  }
}
