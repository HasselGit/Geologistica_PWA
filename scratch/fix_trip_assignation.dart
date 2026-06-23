import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  try {
    print('--- Asignando Viaje a Mauricio (Chofer) ---');
    // Mauricio's ID: d96485ce-0003-48e9-be14-b5de638063b4
    // Trip ID from previous check: 25d8f51c-29e8-4ca2-92e1-61a98f961113
    
    final response = await client.from('viajes')
        .update({'chofer_id': 'd96485ce-0003-48e9-be14-b5de638063b4', 'estado': 'En Curso'})
        .eq('id', '25d8f51c-29e8-4ca2-92e1-61a98f961113')
        .select();
    
    if (response.isNotEmpty) {
      print('Viaje actualizado exitosamente: ${response.first}');
    } else {
      print('No se pudo actualizar el viaje.');
    }

  } catch (e) {
    print('Error: $e');
  }
}
