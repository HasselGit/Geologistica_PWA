import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  final email = 'cmuse@geomiel.com';
  print('--- Verificando credenciales para $email ---');
  try {
    final response = await client.from('profiles').select().eq('email', email).maybeSingle();
    if (response == null) {
      print('El usuario no existe en la tabla profiles.');
    } else {
      print('Usuario encontrado:');
      print('ID: ${response['id']}');
      print('Nombre: ${response['nombre']} ${response['apellido']}');
      print('Rol/Puesto: ${response['puesto']}');
      print('Password en DB: ${response['contrasena']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
