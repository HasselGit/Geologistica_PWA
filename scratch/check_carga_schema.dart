import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Inspeccionando Columnas de la Tabla: cargas ---');
  try {
    final columns = await client.rpc('get_table_columns_info', params: {'table_name': 'cargas'});
    print('Columnas cargas: $columns');
  } catch (e) {
    // Si la RPC no existe, hacemos una consulta directa a postgres o usamos un select básico limit 1
    try {
      final sample = await client.from('cargas').select().limit(1);
      print('Éxito consultando cargas. Estructura de muestra: $sample');
    } catch (err) {
      print('Error consultando cargas: $err');
    }
  }

  print('\n--- Inspeccionando Columnas de la Tabla: carga_items ---');
  try {
    final columns = await client.rpc('get_table_columns_info', params: {'table_name': 'carga_items'});
    print('Columnas carga_items: $columns');
  } catch (e) {
    try {
      final sample = await client.from('carga_items').select().limit(1);
      print('Éxito consultando carga_items. Estructura de muestra: $sample');
    } catch (err) {
      print('Error consultando carga_items: $err');
    }
  }
}
