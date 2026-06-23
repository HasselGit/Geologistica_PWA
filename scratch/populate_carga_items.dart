import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Insertando items de prueba para CARGA-2363526 ---');
  const cargaId = 'e8eef45e-45df-4a45-81b2-a6e3f5ad453b';
  try {
    // Primero, limpiar cualquier item previo (si existiera)
    await client.from('carga_items').delete().eq('carga_id', cargaId);
    
    // Insertar un tambor TCM lleno (10 unidades, 10 * 300 = 3000 kg)
    await client.from('carga_items').insert({
      'carga_id': cargaId,
      'producto_codigo': 'TCM',
      'cantidad': 10,
      'unidad': 'UN',
    });

    // Insertar un tambor TV vacío (5 unidades, 5 * 20 = 100 kg)
    await client.from('carga_items').insert({
      'carga_id': cargaId,
      'producto_codigo': 'TV',
      'cantidad': 5,
      'unidad': 'UN',
    });

    print('✅ Carga items de prueba insertados con éxito.');
  } catch (e) {
    print('Error: $e');
  }
}
