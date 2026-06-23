import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Carga específica ---');
  try {
    final list = await client.from('cargas').select('*').eq('carga_codigo', 'CARGA-2363526');
    for (var c in list) {
      print('Carga: $c');
    }
  } catch (e) {
    print('Error: $e');
  }
}
