import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Registros de Remitos ---');
  try {
    final list = await client.from('remitos').select('*').limit(3);
    for (var r in list) {
      print('Remito record: $r');
    }
  } catch (e) {
    print('Error: $e');
  }
}
