import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  final userId = 'd96485ce-0003-48e9-be14-b5de638063b4'; // Mauricio
  
  try {
    print('Testing query for Chofer $userId');
    
    // Test exact query from service
    final data = await client.from('viajes').select('*, paradas(*, parada_items(*))').eq('chofer_id', userId);
    
    print('Encontrados: ${data.length} viajes');
    for (var v in data) {
      print('Viaje: ${v['id']}, Estado: ${v['estado']}');
      final paradas = v['paradas'] as List;
      print('  Paradas: ${paradas.length}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
