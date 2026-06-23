import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Probando Creación de Carga desde CargaDetalle Dialog ---');
  
  const viajeId = 'ebcbcae8-e802-4733-9e0e-639d3861f29c';
  
  // En la app el creador es el user_id guardado en prefs. Si está vacío o no es un UUID válido, fallará la FKey.
  // El perfil de Hassel es 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61'
  const createdBy = 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61';

  final List<Map<String, dynamic>> mockItems = [
    {
      'producto_codigo': 'TCM',
      'cantidad': 10.0, // double, como en la UI
      'unidad': 'UN',
    }
  ];

  try {
    print('Intentando insertar carga...');
    final cargaResp = await client.from('cargas').insert({
      'carga_codigo': 'TEST-FORM-${DateTime.now().millisecondsSinceEpoch}',
      'viaje_id': viajeId,
      'estado': 'Pendiente',
      'created_by': createdBy,
    }).select('id').single();
    
    final cargaId = cargaResp['id'] as String;
    print('Carga insertada con éxito: $cargaId');

    print('Intentando insertar item con cantidad double...');
    await client.from('carga_items').insert({
      'carga_id': cargaId,
      'producto_codigo': mockItems[0]['producto_codigo'],
      'cantidad': mockItems[0]['cantidad'],
      'unidad': mockItems[0]['unidad'],
    });
    print('Item insertado con éxito!');

    // Limpieza
    await client.from('carga_items').delete().eq('carga_id', cargaId);
    await client.from('cargas').delete().eq('id', cargaId);
    print('Limpieza completada.');
  } catch (e) {
    print('Error en creación: $e');
  }
}
