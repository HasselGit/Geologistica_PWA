import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Verificando Viajes en DB ---');
  try {
    final trips = await client.from('viajes').select('id, viaje_codigo, estado');
    print('Total viajes: ${trips.length}');
    for (var t in trips) {
      print(' - ID: "${t['id']}", Codigo: "${t['viaje_codigo']}", Estado original: "${t['estado']}"');
    }
  } catch (e) {
    print('Error: $e');
  }
}
