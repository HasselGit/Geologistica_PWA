import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Contenido de Profiles ---');
    final response = await client.from('profiles').select();
    for (var p in response) {
      print('ID: ${p['id']}');
      print('  Nombre: ${p['nombre']}');
      print('  Puesto: ${p['puesto']}');
      print('  Email: ${p['email']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
