import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Listando Viajes de la Base de Datos ---');
  try {
    final trips = await client.from('viajes').select();
    print('Total viajes: ${trips.length}');
    for (var t in trips) {
      print('ID: ${t['id']}, Código: ${t['viaje_codigo']}, Estado: ${t['estado']}');
    }
  } catch (err) {
    print('Error consultando viajes: $err');
  }
}
