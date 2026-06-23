import 'package:supabase/supabase.dart';

void main() async {
  final client = SupabaseClient(
    'https://suwcqdlxnmfcvmlnzizl.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN1d2NxZGx4bm1mY3ZtbG56aXpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE4NjQxODYsImV4cCI6MjA4NzQ0MDE4Nn0.zX-EOzrgDj4anNX_guQ9VJPOBqZzdroAWI1Duu0yt-o',
  );

  const String tripCode = 'V-1105-925';

  try {
    print('========================================');
    print('INICIANDO LIMPIEZA DEL VIAJE $tripCode');
    print('========================================');

    // 1. Encontrar el viaje
    final trips = await client.from('viajes').select('*').eq('viaje_codigo', tripCode);
    if (trips.isEmpty) {
      print('ERROR: No se encontró ningún viaje con el código $tripCode.');
      return;
    }
    
    final viaje = trips.first;
    final String tripId = viaje['id'].toString();
    print('Viaje encontrado ID: $tripId');

    // 2. Obtener las paradas del viaje
    final paradas = await client.from('paradas').select('*').eq('viaje_id', tripId);
    final List<String> paradaIds = paradas.map<String>((p) => p['id'].toString()).toList();
    final List<String> solicitudIds = paradas
        .map<String?>((p) => p['solicitud_id']?.toString())
        .where((id) => id != null)
        .cast<String>()
        .toList();

    print('Paradas vinculadas: $paradaIds');
    print('Solicitudes vinculadas: $solicitudIds');

    // 3. Eliminar remitos por parada_id o por viaje_id
    if (paradaIds.isNotEmpty) {
      print('Eliminando remitos vinculados a paradas...');
      await client.from('remitos').delete().inFilter('parada_id', paradaIds);
      print('Remitos de paradas eliminados.');
    }
    print('Eliminando remitos vinculados directamente al viaje...');
    await client.from('remitos').delete().eq('viaje_id', tripId);
    print('Remitos de viaje directos eliminados.');

    // 4. Restablecer solicitudes a 'Pendiente'
    if (solicitudIds.isNotEmpty) {
      print('Restableciendo solicitudes a "Pendiente"...');
      await client.from('solicitudes').update({'estado': 'Pendiente'}).inFilter('id', solicitudIds);
      print('Solicitudes restablecidas.');
    }

    // 5. Eliminar parada_items vinculados
    if (paradaIds.isNotEmpty) {
      print('Eliminando items de paradas (parada_items)...');
      await client.from('parada_items').delete().inFilter('parada_id', paradaIds);
      print('Items de paradas eliminados.');
    }

    // 6. Eliminar paradas
    if (paradaIds.isNotEmpty) {
      print('Eliminando paradas...');
      await client.from('paradas').delete().inFilter('id', paradaIds);
      print('Paradas eliminadas.');
    }

    // 7. Eliminar carga_items de las cargas del viaje
    final cargas = await client.from('cargas').select('id').eq('viaje_id', tripId);
    final List<String> cargaIds = cargas.map<String>((c) => c['id'].toString()).toList();
    if (cargaIds.isNotEmpty) {
      print('Eliminando items de cargas (carga_items)...');
      await client.from('carga_items').delete().inFilter('carga_id', cargaIds);
      print('Items de cargas eliminados.');
      
      print('Eliminando cargas...');
      await client.from('cargas').delete().inFilter('id', cargaIds);
      print('Cargas eliminadas.');
    }

    // 8. Eliminar rutas (turas) del viaje
    print('Eliminando rutas vinculadas...');
    await client.from('rutas').delete().eq('viaje_id', tripId);
    print('Rutas eliminadas.');

    // 10. Eliminar el viaje
    print('Eliminando el viaje $tripCode de la base de datos...');
    await client.from('viajes').delete().eq('id', tripId);
    
    print('========================================');
    print('¡LIMPIEZA COMPLETADA CON ÉXITO!');
    print('========================================');

  } catch (e) {
    print('ERROR DURANTE LA LIMPIEZA: $e');
  }
}
