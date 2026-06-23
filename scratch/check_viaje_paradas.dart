import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  const viajeId = '5b8a70c8-c2fc-4f59-b8a5-64e04d91da38';
  print('--- Inspeccionando Paradas para Viaje V-1605-860 ($viajeId) ---');
  try {
    final paradas = await client.from('paradas').select('*, parada_items(*)').eq('viaje_id', viajeId);
    print('Cantidad de paradas: ${paradas.length}');
    for (var p in paradas) {
      print('Parada: ID=${p['id']}, Tipo=${p['tipo']}, Localidad=${p['localidad']}, Ubicacion=${p['ubicacion']}, Items=${p['parada_items']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
