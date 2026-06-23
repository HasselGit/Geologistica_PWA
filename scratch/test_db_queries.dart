import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Probando Consulta: viajes con paradas ---');
  try {
    final viajes = await client.from('viajes').select('*, paradas(*)');
    print('Éxito! Viajes encontrados: ${viajes.length}');
    for (var v in viajes) {
      print(' - Viaje: ${v['viaje_codigo']} (Estado: ${v['estado']})');
      final paradas = v['paradas'] as List? ?? [];
      print('   Paradas (${paradas.length}):');
      for (var p in paradas) {
        print('     * Parada ID: ${p['id']} - ${p['tipo']} en ${p['ubicacion']} (Estado: ${p['estado']})');
      }
    }
  } catch (e) {
    print('Fallo en viajes con paradas: $e');
  }

  print('\n--- Probando Consulta: productos ---');
  try {
    final productos = await client.from('productos').select('id, descripcion, codigo, unidad, activo');
    print('Éxito! Productos encontrados: ${productos.length}');
    for (var p in productos) {
      print(' - Producto: ${p['codigo']} - ${p['descripcion']} (Activo: ${p['activo']})');
    }
  } catch (e) {
    print('Fallo en productos: $e');
  }
}
