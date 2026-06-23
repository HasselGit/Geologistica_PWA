import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('--- INICIANDO DEBUG DE VIAJES Y PARADAS ---');
  
  await Supabase.initialize(
    url: 'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  final client = Supabase.instance.client;

  try {
    // 1. Buscar el viaje
    print('Buscando viaje con código V-2105-906...');
    final viajeList = await client.from('viajes').select('*').eq('viaje_codigo', 'V-2105-906');
    if (viajeList.isEmpty) {
      print('❌ No se encontró el viaje V-2105-906');
      return;
    }

    final viaje = viajeList.first;
    final viajeId = viaje['id'];
    print('✅ Viaje encontrado: ID = $viajeId, Código = ${viaje['viaje_codigo']}, Estado = ${viaje['estado']}');

    // 2. Buscar rutas asociadas
    print('\nBuscando rutas asociadas al viaje_id: $viajeId...');
    final rutas = await client.from('rutas').select('*').eq('viaje_id', viajeId);
    print('✅ Rutas encontradas (${rutas.length}):');
    for (var r in rutas) {
      print('   - ID = ${r['id']}, Código = ${r['ruta_codigo']}, Estado = ${r['estado']}');
    }

    // 3. Buscar paradas asociadas al viaje_id
    print('\nBuscando paradas asociadas al viaje_id: $viajeId...');
    final paradas = await client.from('paradas').select('*').eq('viaje_id', viajeId);
    print('✅ Paradas encontradas (${paradas.length}):');
    for (var p in paradas) {
      print('   - ID = ${p['id']}, RutaID = ${p['ruta_id']}, SolicitudID = ${p['solicitud_id']}, Orden = ${p['orden_secuencia']}, Ubicación = ${p['ubicacion']}, Localidad = ${p['localidad']}, Estado = ${p['estado']}');
    }

    // 4. Intentar la consulta exacta que hace getViajeDetalle en SupabaseService
    print('\nEjecutando consulta relacional de rutas y paradas...');
    try {
      final queryRes = await client.from('rutas')
          .select('*, paradas(*, parada_items(*), remitos(*))')
          .eq('viaje_id', viajeId).order('created_at');
      print('✅ Consulta relacional exitosa! Rutas y paradas obtenidas:');
      for (var r in queryRes) {
        final pList = r['paradas'] as List? ?? [];
        print('   - Ruta ID = ${r['id']}, Código = ${r['ruta_codigo']}, Paradas asociadas count = ${pList.length}');
        for (var p in pList) {
          print('     * Parada ID = ${p['id']}, Orden = ${p['orden_secuencia']}, Ubicación = ${p['ubicacion']}');
        }
      }
    } catch (e) {
      print('❌ ERROR en consulta relacional: $e');
    }

  } catch (e) {
    print('❌ ERROR GENERAL: $e');
  }
}
