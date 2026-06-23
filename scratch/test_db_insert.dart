import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Probando Inserción de Remito en DB (RLS Test) ---');
  final mockRemito = {
    'parada_id': '11453bea-4392-4872-9728-a35f67f71e62', // Walter Spinozzi parada ID
    'viaje_id': 'e717eae9-3335-4a29-8dc2-4048e8fdb4de',
    'tipo': 'Recoleccion',
    'pdf_url': 'https://example.com/test_remito.pdf',
    'firma_url': 'https://example.com/test_firma.png',
  };

  try {
    final response = await client.from('remitos').insert(mockRemito).select();
    print('  [ÉXITO] Remito insertado exitosamente en DB!');
    print('  Respuesta: $response');
    
    // Eliminar registro de prueba
    if (response.isNotEmpty) {
      final insertedId = response[0]['id'];
      await client.from('remitos').delete().eq('id', insertedId);
      print('  [ÉXITO] Registro de prueba eliminado de la base de datos.');
    }
  } catch (e) {
    print('  [FAIL] La inserción falló por política RLS: $e');
  }
}
