import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Listando todos los perfiles de la DB ---');
  try {
    final profiles = await client.from('profiles').select();
    for (var p in profiles) {
      print('Email: ${p['email']}, Puesto: ${p['puesto']}, Contraseña: ${p['contrasena']}');
    }
  } catch (err) {
    print('Error: $err');
  }
}
