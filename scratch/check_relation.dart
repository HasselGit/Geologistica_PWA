import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    final list = await client.from('solicitudes')
        .select('id, apicultor_id, apicultores(nombre)')
        .limit(1);
    print('Solicitudes-Apicultores relation succeeded! Row: $list');
  } catch (e) {
    print('Solicitudes-Apicultores relation failed: $e');
  }
}
