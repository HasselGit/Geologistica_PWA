import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Tabla Viajes ---');
    final response = await client.from('viajes').select().limit(5);
    if (response.isNotEmpty) {
      print('Columnas viajes: ${response.first.keys.toList()}');
      for (var row in response) {
        print('Viaje ID: ${row['id']}, Estado: ${row['estado']}, Chofer ID: ${row['chofer_id']}, Fecha: ${row['fecha']}');
      }
    } else {
      print('La tabla viajes está vacía.');
    }

    print('\n--- Verificando Perfiles ---');
    final profiles = await client.from('profiles').select('id, nombre, puesto').limit(5);
    for (var p in profiles) {
      print('Profile: ${p['nombre']}, ID: ${p['id']}, Puesto: ${p['puesto']}');
    }

  } catch (e) {
    print('Error: $e');
  }
}
