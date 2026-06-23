import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Verificando Tabla Solicitudes ---');
    final response = await client.from('solicitudes').select().limit(1);
    if (response.isNotEmpty) {
      print('Columnas solicitudes: ${response.first.keys.toList()}');
      print('Data: ${response.first}');
    } else {
      print('La tabla solicitudes está vacía.');
    }
    
    print('\n--- Verificando Tabla Paradas ---');
    final pResp = await client.from('paradas').select().limit(1);
    if (pResp.isNotEmpty) {
      print('Columnas paradas: ${pResp.first.keys.toList()}');
      print('Data: ${pResp.first}');
    }

  } catch (e) {
    print('Error: $e');
  }
}
