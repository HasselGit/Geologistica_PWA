import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Buscando Perfil de Mariano Paredes / CEO / Gerente / Compras ---');
  try {
    final profiles = await client.from('profiles').select();
    print('Total perfiles: ${profiles.length}');
    for (var p in profiles) {
      final String nombre = p['nombre']?.toString() ?? '';
      final String apellido = p['apellido']?.toString() ?? '';
      final String email = p['email']?.toString() ?? '';
      final String puesto = p['puesto']?.toString() ?? '';
      
      if (nombre.toLowerCase().contains('mariano') || 
          apellido.toLowerCase().contains('paredes') || 
          puesto.toLowerCase().contains('ceo') || 
          puesto.toLowerCase().contains('gerente') ||
          puesto.toLowerCase().contains('compras')) {
        print('ID: ${p['id']}, Email: $email, Nombre: $nombre, Apellido: $apellido, Puesto: $puesto');
      }
    }
  } catch (err) {
    print('Error buscando perfiles: $err');
  }
}
