import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'sb_publishable_H6MPPGj7rIO4Oih0o7f6cg_x7bsgKFo',
  );

  print('--- Probando Creación de Carga (DB Integration Test) ---');
  
  // Usamos el ID de viaje existente en Pendiente: V-1605-860
  // ID: 5b8a70c8-c2fc-4f59-b8a5-64e04d91da38
  const viajeId = '5b8a70c8-c2fc-4f59-b8a5-64e04d91da38';
  const createdBy = 'd0744e5c-3d9c-4e17-be9e-90e55f4a4c61'; // Hassel Espinosa profile ID

  final mockItems = [
    {
      'producto_codigo': 'TCM',
      'cantidad': 10,
      'unidad': 'UN',
    }
  ];

  try {
    print('1. Creando carga en tabla cargas...');
    final cargaResp = await client.from('cargas').insert({
      'carga_codigo': 'TEST-CARGA-${DateTime.now().millisecondsSinceEpoch}',
      'viaje_id': viajeId,
      'estado': 'Pendiente',
      'created_by': createdBy,
    }).select('id').single();
    
    final cargaId = cargaResp['id'] as String;
    print('   [ÉXITO] Carga creada con ID: $cargaId');

    print('2. Creando items en tabla carga_items...');
    await client.from('carga_items').insert({
      'carga_id': cargaId,
      'producto_codigo': mockItems[0]['producto_codigo'],
      'cantidad': mockItems[0]['cantidad'],
      'unidad': mockItems[0]['unidad'],
    });
    print('   [ÉXITO] Item creado con éxito!');

    // Limpieza
    print('3. Limpiando datos de prueba...');
    await client.from('carga_items').delete().eq('carga_id', cargaId);
    await client.from('cargas').delete().eq('id', cargaId);
    print('   [ÉXITO] Datos de prueba eliminados correctamente.');
  } catch (e) {
    print('   [FAIL] Falló la creación de carga: $e');
  }
}
