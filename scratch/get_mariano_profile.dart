import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando credenciales para Mariano Paredes ---');
  try {
    final response = await client.from('profiles').select().ilike('nombre', '%mariano%').ilike('apellido', '%paredes%').maybeSingle();
    if (response == null) {
      print('El usuario Mariano Paredes no fue encontrado.');
    } else {
      print('Usuario encontrado:');
      print('Email: ${response['email']}');
      print('Nombre: ${response['nombre']} ${response['apellido']}');
      print('Rol/Puesto: ${response['puesto']}');
      print('Password en DB: ${response['contrasena']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
