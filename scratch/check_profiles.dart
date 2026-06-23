import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Profiles en DB ---');
  try {
    final profiles = await client.from('profiles').select('id, nombre, apellido, puesto, email');
    print('Total profiles: ${profiles.length}');
    for (var p in profiles) {
      print(' - ID: "${p['id']}", Email: "${p['email']}", Nombre: "${p['nombre']} ${p['apellido']}", Puesto: "${p['puesto']}"');
    }
  } catch (e) {
    print('Error: $e');
  }
}
