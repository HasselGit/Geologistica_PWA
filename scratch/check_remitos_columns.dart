import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Columnas de Remitos ---');
  try {
    final list = await client.from('remitos').select('*').limit(1);
    if (list.isNotEmpty) {
      print('remitos keys: ${list[0].keys}');
    } else {
      print('remitos is empty! Let\'s insert a test query or print something else.');
    }
  } catch (e) {
    print('Error checking remitos columns: $e');
  }
}
